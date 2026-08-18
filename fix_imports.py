import os

tres_content = """[gd_resource type="StandardMaterial3D" format=3 uid="uid://dpsnx7mblt8w5"]

[resource]
resource_name = "Material_TripoSR"
vertex_color_use_as_albedo = true
"""

with open("Material_TripoSR.tres", "w") as f:
    f.write(tres_content)

for glb_import in os.listdir("."):
    if glb_import.endswith(".glb.import"):
        with open(glb_import, "r") as f:
            lines = f.readlines()
        
        with open(glb_import, "w") as f:
            for line in lines:
                if line.startswith("_subresources={}"):
                    f.write('_subresources={\n"materials": {\n"Material_TripoSR": {\n"path": "res://Material_TripoSR.tres"\n}\n}\n}\n')
                else:
                    f.write(line)

print("Imports fixed!")
