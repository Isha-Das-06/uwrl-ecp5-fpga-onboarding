#!/usr/bin/env python3
"""Print cells of a given type from build/top.json with their ports mapped to net names.

usage: scripts/find_cell.py TRELLIS_FF [max]
"""
import json
import sys

cell_type = sys.argv[1] if len(sys.argv) > 1 else "TRELLIS_FF"
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3

with open("build/top.json") as f:
    mod = json.load(f)["modules"]["top"]

# bit number -> net name (first name wins, skip yosys-internal $ names if possible)
names = {}
for name, net in sorted(mod["netnames"].items(), key=lambda kv: kv[0].startswith("$")):
    for i, bit in enumerate(net["bits"]):
        if isinstance(bit, int) and bit not in names:
            names[bit] = name if len(net["bits"]) == 1 else f"{name}[{i}]"

def show(bits):
    return ", ".join(names.get(b, str(b)) if isinstance(b, int) else f"const {b}" for b in bits)

found = 0
for cname, cell in mod["cells"].items():
    if cell["type"] != cell_type:
        continue
    print(f"{cell_type}  {cname}")
    for k, v in sorted(cell.get("parameters", {}).items()):
        print(f"    param {k} = {v}")
    for port, bits in cell["connections"].items():
        print(f"    {cell['port_directions'].get(port, '?'):6} {port:5} -> {show(bits)}")
    found += 1
    if found >= limit:
        break

if not found:
    print(f"no {cell_type} cells found")
