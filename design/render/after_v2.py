"""Renders the device as it can really be built from the purchase list.

    blender -b -P design/render/after_v2.py -- OUTPUT.png [SIZE] [SAMPLES]

Dimensions in mm. Case: Flirc Raspberry Pi 5 Case, 94 x 66 x 28 (retailer spec), with
port positions scaled from its product photos. Panel: Waveshare 4inch DSI LCD, 104.37 x
65.44 outline and 87 x 52.44 display (maker's drawing); its 5 mm thickness is an
estimate. The screen is design/render/screen.png, captured from the built OS image.

Axes: x along the case's length with the USB end at +x, y across with the front long
side at -y, z up from the table.
"""
import math
import os
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
OUTPUT = os.path.abspath(argv[0])
SIZE = int(argv[1]) if len(argv) > 1 else 1024
SAMPLES = int(argv[2]) if len(argv) > 2 else 256
HERE = os.path.dirname(os.path.abspath(__file__))

CASE_L, CASE_W, CASE_H = 94.0, 66.0, 28.0
PANEL_L, PANEL_W, PANEL_T = 104.37, 65.44, 5.0
SCREEN_L, SCREEN_W = 87.0, 52.44
CHIN = 10.87  # The panel's wider bezel, kept at the port end like a phone's chin.
TAPE_T = 1.0  # Double-sided tape between the case and the panel.
PANEL_Z = CASE_H + TAPE_T
PANEL_X1 = CASE_L / 2  # Flush at the USB end, so the overhang is at the far end.
PANEL_X0 = PANEL_X1 - PANEL_L

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.scale_length = 0.001


def material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=0.0, coat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = coat
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


ALUMINIUM = material("aluminium", (0.78, 0.78, 0.79), metallic=1.0, roughness=0.32)
TAPE = material("tape", (0.82, 0.82, 0.83), metallic=1.0, roughness=0.42)
SOFT_BLACK = material("soft_black", (0.012, 0.012, 0.014), roughness=0.55)
GLASS_BLACK = material("glass_black", (0.004, 0.004, 0.005), roughness=0.06, coat=1.0)
CAVITY = material("cavity", (0.006, 0.006, 0.007), roughness=0.6)
SHELL = material("shell", (0.62, 0.62, 0.64), metallic=1.0, roughness=0.3)
BLUE = material("usb3_blue", (0.02, 0.2, 0.75), roughness=0.4)
GOLD = material("gold", (0.9, 0.65, 0.25), metallic=1.0, roughness=0.3)
LED_GREEN = material("led_green", (0.1, 0.8, 0.2), emission=(0.1, 1, 0.2), strength=3)
LED_YELLOW = material("led_yellow", (0.8, 0.8, 0.1), emission=(1, 0.85, 0.1), strength=3)
ENGRAVE = material("engrave", (0.45, 0.45, 0.47), metallic=1.0, roughness=0.5)


def rounded_prism(name, x0, x1, y0, y1, z0, z1, r, mat, edge_bevel=0.0, segments=10):
    """A box whose vertical edges have radius r, optionally softening top and bottom."""
    bm = bmesh.new()
    outline = []
    corners = ((x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180), (x1 - r, y0 + r, 270))
    for cx, cy, start in corners:
        for i in range(segments + 1):
            a = math.radians(start + 90 * i / segments)
            outline.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    bottom = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z1)) for x, y in outline]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if edge_bevel:
        mod = obj.modifiers.new("edges", "BEVEL")
        mod.width = edge_bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(50)
    return obj


def box(name, x0, x1, y0, y1, z0, z1, mat):
    return rounded_prism(name, x0, x1, y0, y1, z0, z1, 0.05, mat, segments=1)


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(body, cutter):
    mod = body.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_modifiers(body)
    bpy.data.objects.remove(cutter)


x0, x1 = -CASE_L / 2, CASE_L / 2
y0, y1 = -CASE_W / 2, CASE_W / 2

body = rounded_prism("case", x0, x1, y0, y1, 1.2, CASE_H - 0.8, 3.2, ALUMINIUM, edge_bevel=0.25)
apply_modifiers(body)
rounded_prism("case_foot", x0 + 1, x1 - 1, y0 + 1, y1 - 1, 0.0, 1.2, 2.5, SOFT_BLACK)
rounded_prism("case_lid", x0 + 0.5, x1 - 0.5, y0 + 0.5, y1 - 0.5, CASE_H - 0.8, CASE_H, 2.8, SOFT_BLACK)

# Short end: Ethernet and the lower USB row. y runs -33..33, z from the table.
DEPTH = 7
RJ45 = (-28.9, -13.2, 4.0, 19.0)
USB_LOWER = ((-8.9, 5.7, BLUE), (10.5, 25.1, CAVITY))
UPPER_Z = (17.3, 23.7)
LOWER_Z = (8.8, 15.0)


def end_hole(a, b, z0, z1, r=0.9):
    cutter = rounded_prism("hole", x1 - DEPTH, x1 + 3, a, b, z0, z1, 0.01, ALUMINIUM)
    cut(body, cutter)


end_hole(RJ45[0], RJ45[1], RJ45[2], RJ45[3])
box("rj45_back", x1 - DEPTH + 0.1, x1 - 2.2, RJ45[0] + 0.5, RJ45[1] - 0.5, RJ45[2] + 0.5, RJ45[3] - 0.5, CAVITY)
box("rj45_led_y", x1 - 2.3, x1 - 1.8, RJ45[0] + 1.2, RJ45[0] + 4.2, RJ45[2] + 1.2, RJ45[2] + 3.2, LED_YELLOW)
box("rj45_led_g", x1 - 2.3, x1 - 1.8, RJ45[1] - 4.2, RJ45[1] - 1.2, RJ45[2] + 1.2, RJ45[2] + 3.2, LED_GREEN)
for a, b, tongue in USB_LOWER:
    end_hole(a, b, *LOWER_Z)
    box("usb_back", x1 - DEPTH + 0.1, x1 - 5, a + 0.2, b - 0.2, LOWER_Z[0] + 0.2, LOWER_Z[1] - 0.2, CAVITY)
    box("usb_tongue", x1 - 6, x1 - 1.6, a + 1.2, b - 1.2, LOWER_Z[0] + 3.0, LOWER_Z[0] + 4.3, tongue)

# The upper USB row exists on the board but is hidden behind aluminium tape.
box("tape", x1 - 0.05, x1 + 0.09, -10.2, 26.4, UPPER_Z[0] - 1.0, UPPER_Z[1] + 1.0, TAPE)

# Long side: USB-C and two micro-HDMI.
PORT_Z = 8.0


def side_port(center, width, height, mat_tongue):
    a, b = center - width / 2, center + width / 2
    z0, z1 = PORT_Z - height / 2, PORT_Z + height / 2
    cutter = rounded_prism("side_hole", a, b, y0 - 3, y0 + DEPTH, z0, z1, min(width, height) * 0.45, ALUMINIUM)
    cut(body, cutter)
    box("side_back", a + 0.2, b - 0.2, y0 + 3.0, y0 + DEPTH - 0.1, z0 + 0.2, z1 - 0.2, CAVITY)
    box("side_tongue", a + 1.1, b - 1.1, y0 + 2.0, y0 + 3.2, PORT_Z - 0.35, PORT_Z + 0.35, mat_tongue)


side_port(-32.85, 9.9, 3.7, CAVITY)
side_port(-16.6, 7.8, 3.7, GOLD)
side_port(-3.2, 7.8, 3.7, GOLD)

curve = bpy.data.curves.new("flirc", "FONT")
curve.body = "FLIRC"
curve.size = 7.0
curve.extrude = 0.06
curve.materials.append(ENGRAVE)
logo = bpy.data.objects.new("flirc", curve)
bpy.context.collection.objects.link(logo)
logo.rotation_euler = (math.radians(90), 0, 0)
logo.location = (17.0, y0 + 0.02, 5.5)

# Boolean cuts leave n-gons that smooth shading smears, so only real curves stay smooth.
body.data.set_sharp_from_angle(angle=math.radians(35))

# Panel: glass on a thin black body, with tape showing as the seam under it.
rounded_prism("tape_layer", x0 + 1, x1 - 1, y0 + 1, y1 - 1, CASE_H, PANEL_Z, 2.5, CAVITY)
rounded_prism("panel", PANEL_X0, PANEL_X1, -PANEL_W / 2, PANEL_W / 2, PANEL_Z, PANEL_Z + PANEL_T, 3.0,
              GLASS_BLACK, edge_bevel=0.35)

screen_mat = material("screen", (0, 0, 0), roughness=0.12, coat=0.3)
nodes = screen_mat.node_tree.nodes
texture = nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(os.path.join(HERE, "screen.png"))
texture.interpolation = "Smart"
bsdf = nodes["Principled BSDF"]
screen_mat.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = 1.35

# Held upright the ports are at the bottom, so the top of the UI is towards -x.
sx1 = PANEL_X1 - CHIN
sx0 = sx1 - SCREEN_L
sy = SCREEN_W / 2
sz = PANEL_Z + PANEL_T + 0.01
mesh = bpy.data.meshes.new("screen")
mesh.from_pydata([(sx1, -sy, sz), (sx1, sy, sz), (sx0, sy, sz), (sx0, -sy, sz)], [], [(0, 1, 2, 3)])
uv = mesh.uv_layers.new()
for loop, coord in zip(mesh.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
    uv.data[loop.index].uv = coord
screen = bpy.data.objects.new("screen", mesh)
bpy.context.collection.objects.link(screen)
mesh.materials.append(screen_mat)

# Studio: glossy white table, with a dim surround so the metal has something darker
# than white to reflect. The camera sees the table lit by the area lights.
floor = material("floor", (0.95, 0.95, 0.95), roughness=0.2)
mesh = bpy.data.meshes.new("floor")
mesh.from_pydata([(-3000, -3000, 0), (3000, -3000, 0), (3000, 3000, 0), (-3000, 3000, 0)], [], [(0, 1, 2, 3)])
table = bpy.data.objects.new("floor", mesh)
bpy.context.collection.objects.link(table)
mesh.materials.append(floor)

world = bpy.data.worlds.new("world")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42
scene.world = world


def area_light(name, location, target, size, power):
    data = bpy.data.lights.new(name, "AREA")
    data.size = size
    data.energy = power
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    point_at(obj, target)


def point_at(obj, target):
    direction = (obj.location[0] - target[0], obj.location[1] - target[1], obj.location[2] - target[2])
    from mathutils import Vector

    obj.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()


area_light("key", (-250, -320, 620), (0, 0, 20), 700, 3.4e6)
area_light("fill", (520, -60, 240), (0, 0, 20), 260, 5.0e5)
area_light("strip", (-40, -620, 150), (0, 0, 15), 240, 5.5e5)

# A black card out of frame, in the direction the glass mirrors towards the camera.
# Without it the panel reflects the surround and its blacks turn grey.
card = material("card", (0, 0, 0), roughness=1.0)
mesh = bpy.data.meshes.new("card")
mesh.from_pydata([(-700, -350, 0), (700, -350, 0), (700, 350, 0), (-700, 350, 0)], [], [(0, 1, 2, 3)])
flag = bpy.data.objects.new("card", mesh)
bpy.context.collection.objects.link(flag)
mesh.materials.append(card)
flag.location = (-620, 980, 900)
point_at(flag, (0, 0, 20))

camera_data = bpy.data.cameras.new("camera")
camera_data.lens = 118
camera_data.clip_end = 20000
camera = bpy.data.objects.new("camera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (225, -360, 200)
point_at(camera, (-1, 0, 15))
scene.camera = camera

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 8
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.filepath = OUTPUT
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
bpy.ops.render.render(write_still=True)
