import os
import re

class TscnParser:
    def __init__(self, filepath, project_root):
        self.filepath = filepath
        self.project_root = project_root
        self.ext_resources = {}
        self.nodes = [] # List of {name, parent_name, path, type, instance_id, script, unique_name}
        self.inheritance = None
        self.node_path_properties = [] # (node_path, property_name, target_path)

    def parse(self):
        if not os.path.exists(self.filepath):
            return

        with open(self.filepath, 'r') as f:
            content = f.read()

        for match in re.finditer(r'\[ext_resource (.*?)\]', content):
            attrs = self._parse_attrs(match.group(1))
            if 'id' in attrs:
                self.ext_resources[attrs['id']] = attrs

        node_blocks = re.split(r'(\[node .*?\])', content)
        last_nodes_by_name = {}

        for i in range(1, len(node_blocks), 2):
            header = node_blocks[i]
            body = node_blocks[i+1] if i+1 < len(node_blocks) else ""

            header_attrs = self._parse_attrs(header)
            name = header_attrs.get('name')
            parent_name = header_attrs.get('parent')

            instance_id = None
            instance_match = re.search(r'instance=ExtResource\("([^"]+)"\)', header)
            if instance_match:
                instance_id = instance_match.group(1)

            if parent_name is None:
                path = "."
            elif parent_name == ".":
                path = name
            else:
                if parent_name in last_nodes_by_name:
                    parent_path = last_nodes_by_name[parent_name]
                    path = f"{parent_path}/{name}" if parent_path != "." else name
                else:
                    path = f"{parent_name}/{name}"

            last_nodes_by_name[name] = path

            unique_name = "unique_name_in_owner = true" in header or "unique_name_in_owner = true" in body

            node_info = {
                'name': name,
                'type': header_attrs.get('type'),
                'parent': parent_name,
                'path': path,
                'instance_id': instance_id,
                'script': None,
                'unique_name': unique_name
            }

            if parent_name is None and instance_id:
                self.inheritance = self.ext_resources.get(instance_id, {}).get('path')

            script_match = re.search(r'script = ExtResource\("([^"]+)"\)', body)
            if script_match:
                node_info['script'] = self.ext_resources.get(script_match.group(1), {}).get('path')

            self.nodes.append(node_info)

            for prop_match in re.finditer(r'(\w+) = NodePath\("([^"]+)"\)', body):
                prop_name, target_path = prop_match.groups()
                self.node_path_properties.append((path, prop_name, target_path))

    def _parse_attrs(self, attr_string):
        attrs = {}
        for match in re.finditer(r'(\w+)="([^"]*)"', attr_string):
            attrs[match.group(1)] = match.group(2)
        return attrs

class Auditor:
    def __init__(self, project_root):
        self.project_root = project_root
        self.scenes = {}
        self.scripts = {}
        self.scene_trees = {}
        self.scene_unique_names = {}

    def scan_project(self):
        for root, dirs, files in os.walk(self.project_root):
            if '.godot' in root or 'Addons' in root or '.git' in root:
                continue
            for file in files:
                filepath = os.path.join(root, file)
                res_path = 'res://' + os.path.relpath(filepath, self.project_root)
                if file.endswith('.tscn'):
                    parser = TscnParser(filepath, self.project_root)
                    parser.parse()
                    self.scenes[res_path] = parser
                elif file.endswith('.gd'):
                    with open(filepath, 'r') as f:
                        self.scripts[res_path] = f.read()

    def build_trees(self):
        for res_path in self.scenes:
            tree, uniques = self._build_tree(res_path)
            self.scene_trees[res_path] = tree
            self.scene_unique_names[res_path] = uniques

    def _build_tree(self, res_path, visited=None):
        if visited is None: visited = set()
        if res_path in visited: return {}, set()
        visited.add(res_path)

        parser = self.scenes.get(res_path)
        if not parser: return {}, set()

        tree = {}
        uniques = set()
        if parser.inheritance:
            parent_tree, parent_uniques = self._build_tree(parser.inheritance, visited)
            tree.update(parent_tree)
            uniques.update(parent_uniques)

        for node in parser.nodes:
            path = node['path']
            tree[path] = {
                'name': node['name'],
                'type': node['type'],
                'script': node['script'],
                'instance': parser.ext_resources.get(node['instance_id'], {}).get('path') if node['instance_id'] else None
            }
            if node['unique_name']:
                uniques.add(node['name'])

            if tree[path]['instance']:
                sub_tree, sub_uniques = self._build_tree(tree[path]['instance'], visited.copy())
                for sub_path, sub_info in sub_tree.items():
                    if sub_path == ".": continue
                    full_sub_path = f"{path}/{sub_path}" if path != "." else sub_path
                    tree[full_sub_path] = sub_info
                uniques.update(sub_uniques)
        return tree, uniques

    def _normalize_path(self, path):
        if path == ".": return "."
        parts = path.split('/')
        norm_parts = []
        for p in parts:
            if p == '..':
                if norm_parts: norm_parts.pop()
            elif p == '.' or p == '': continue
            else: norm_parts.append(p)
        return "/".join(norm_parts) if norm_parts else "."

    def _get_relative_path(self, from_node, to_node):
        if from_node == to_node: return "."
        from_parts = from_node.split('/') if from_node != "." else []
        to_parts = to_node.split('/') if to_node != "." else []

        common_len = 0
        for f, t in zip(from_parts, to_parts):
            if f == t: common_len += 1
            else: break

        up_steps = len(from_parts) - common_len
        rel_parts = [".."] * up_steps + to_parts[common_len:]
        return "/".join(rel_parts) if rel_parts else "."

    def audit(self):
        results = []
        dynamic_refs = []
        for res_path, script_content in self.scripts.items():
            scenes_using_script = []
            for scene_path, tree in self.scene_trees.items():
                for node_path, info in tree.items():
                    if info['script'] == res_path:
                        scenes_using_script.append((scene_path, node_path))
            if not scenes_using_script: continue

            refs = []
            lines = script_content.splitlines()
            for i, line in enumerate(lines):
                # 1. Match @onready var ... = $Path or get_node("Path")
                # Handle quoted paths for $ too
                onready_match = re.search(r'@onready\s+var\s+(\w+).*?=\s*(?:\$|get_node\(")([^"$)]+)', line)
                if onready_match:
                    var_name, path = onready_match.groups()
                    # Clean path from ending quotes or method calls
                    path = re.split(r'["\.]', path)[0]
                    refs.append({'var': var_name, 'path': path, 'line': i + 1, 'origin': 'onready'})
                    continue

                # 2. Match get_node("...")
                gn_match = re.finditer(r'(\w+)?\.?get_node(?:_or_null)?\("([^"]+)"\)', line)
                for m in gn_match:
                    prefix, path = m.groups()
                    if prefix and prefix != 'self':
                         dynamic_refs.append({'script': res_path, 'line': i + 1, 'code': line.strip()})
                    else:
                         refs.append({'var': None, 'path': path, 'line': i + 1, 'origin': 'get_node'})

                # 3. Match $Path (including quoted $"...")
                # Avoid matching inside @onready which we already handled
                if not re.search(r'@onready\s+var\s+\w+.*?=\s*\$', line):
                    dollar_match = re.finditer(r'(?:^|[\s\(\=\[\,])(\w+)?\.?\$([a-zA-Z0-9_/%\.\"]+)', line)
                    for m in dollar_match:
                        prefix, path = m.groups()
                        if prefix and prefix != 'self':
                             pass
                        else:
                            # If path starts and ends with quotes, strip them
                            if path.startswith('"') and path.endswith('"'):
                                path = path[1:-1]
                            elif path.startswith('"'):
                                path = path[1:].split('"')[0]
                            # Clean from method calls
                            # BUT careful not to split ..
                            # We only want to split . if it's NOT part of ..

                            # Simple way: find first . that is not part of ..
                            clean_path = ""
                            skip = 0
                            for idx in range(len(path)):
                                if skip > 0:
                                    skip -= 1
                                    continue
                                if path[idx] == '.':
                                    if idx + 1 < len(path) and path[idx+1] == '.':
                                        clean_path += ".."
                                        skip = 1
                                    else:
                                        # It's a method call or property access
                                        break
                                else:
                                    clean_path += path[idx]

                            refs.append({'var': None, 'path': clean_path, 'line': i + 1, 'origin': 'dollar'})

            for scene_path, node_context in scenes_using_script:
                tree = self.scene_trees[scene_path]
                uniques = self.scene_unique_names[scene_path]
                for ref in refs:
                    path = ref['path']
                    if not path or path.startswith("/root/"): continue

                    found = False
                    if path.startswith("%"):
                        clean_name = path[1:]
                        if clean_name in uniques: found = True
                    else:
                        if path == ".":
                            norm_path = node_context
                        else:
                            full_path = path if node_context == "." else f"{node_context}/{path}"
                            norm_path = self._normalize_path(full_path)

                        if norm_path in tree or path in tree:
                            found = True

                    if not found:
                        # Broken! Try to find correction
                        target_name = path.split('/')[-1]
                        if target_name.startswith('%'): target_name = target_name[1:]

                        proposals = []
                        for node_path, info in tree.items():
                            if info['name'] == target_name:
                                rel_path = self._get_relative_path(node_context, node_path)
                                proposals.append(rel_path)

                        # Also check uniques
                        if target_name in uniques:
                            proposals.append("%" + target_name)

                        results.append({
                            'type': 'broken_script_ref',
                            'script': res_path,
                            'scene': scene_path,
                            'node_context': node_context,
                            'var': ref['var'],
                            'path': path,
                            'line': ref['line'],
                            'proposals': list(set(proposals))
                        })

        for res_path, parser in self.scenes.items():
            tree = self.scene_trees.get(res_path, {})
            for node_path, prop_name, target_path in parser.node_path_properties:
                full_target = f"{node_path}/{target_path}" if not target_path.startswith("/") else target_path
                norm_target = self._normalize_path(full_target)
                if norm_target not in tree and target_path not in tree:
                     # Broken TSCN NodePath
                     target_name = target_path.split('/')[-1]
                     proposals = []
                     for np, info in tree.items():
                         if info['name'] == target_name:
                             rel_path = self._get_relative_path(node_path, np)
                             proposals.append(rel_path)

                     results.append({
                         'type': 'broken_tscn_nodepath',
                         'scene': res_path,
                         'node_path': node_path,
                         'property': prop_name,
                         'target': target_path,
                         'proposals': list(set(proposals))
                     })
        return results, dynamic_refs

if __name__ == "__main__":
    auditor = Auditor('.')
    auditor.scan_project()
    auditor.build_trees()
    results, dynamic = auditor.audit()

    print("=== AUDIT REPORT ===")
    if not results:
        print("\n[PASSED] No broken static references found.")
    else:
        print(f"\n[FAILED] Found {len(results)} broken references:")
        seen = set()
        for r in results:
            if r['type'] == 'broken_script_ref':
                key = (r['script'], r['line'], r['path'])
                if key in seen: continue
                seen.add(key)
                print(f"  SCRIPT: {r['script']}:{r['line']} in {r['scene']} (node {r['node_context']})")
                print(f"    Reference: '{r['path']}' not found.")
                if r['proposals']:
                    print(f"    Suggested: {', '.join(r['proposals'])}")
            else:
                print(f"  TSCN:   {r['scene']} (node {r['node_path']}): property '{r['property']}'")
                print(f"    Reference: '{r['target']}' not found.")
                if r['proposals']:
                    print(f"    Suggested: {', '.join(r['proposals'])}")

    if dynamic:
        print(f"\n[INFO] Found {len(dynamic)} dynamic/variable node references for manual review:")
        for d in dynamic:
            print(f"  {d['script']}:{d['line']} -> {d['code']}")
    print("\n====================")
