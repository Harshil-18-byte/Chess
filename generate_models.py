import subprocess
import sys

def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

try:
    import trimesh
except ImportError:
    install('trimesh')
    install('networkx')
    import trimesh

import os

pieces = {
    'pawn': trimesh.creation.cylinder(radius=0.4, height=1.0),
    'rook': trimesh.creation.box(extents=(0.8, 1.2, 0.8)),
    'knight': trimesh.creation.cone(radius=0.5, height=1.5),
    'bishop': trimesh.creation.cylinder(radius=0.4, height=1.6),
    'queen': trimesh.creation.uv_sphere(radius=0.6),
    'king': trimesh.creation.capsule(radius=0.5, height=2.0)
}

out_dir = "assets/models/pieces/classic"
os.makedirs(out_dir, exist_ok=True)

for name, mesh in pieces.items():
    # Make them stand upright if needed, simple basic shapes
    mesh.export(os.path.join(out_dir, f"{name}.glb"))

print("Created 3D models")
