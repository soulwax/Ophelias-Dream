"""Generate three appearance palettes with Blender; preserve geometry and rig.

blender --background --factory-startup --python-exit-code 1 --python tools/create_character_variants.py
"""
from pathlib import Path
import json
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/variants'
PALETTES = {
    'snowlight': {'hair': (0.78, 0.85, 0.91), 'cloth': (0.13, 0.30, 0.53),
                  'eye': (0.12, 0.46, 0.79), 'trim': (0.66, 0.76, 0.85)},
    'ember': {'hair': (0.38, 0.13, 0.055), 'cloth': (0.38, 0.045, 0.105),
              'eye': (0.62, 0.32, 0.06)},
    'midnight': {'hair': (0.055, 0.065, 0.085), 'cloth': (0.035, 0.25, 0.26),
                 'eye': (0.43, 0.23, 0.65)},
}


def rasterize(mask, triangle):
    # UVs are intentionally tiled. Translate whole triangles, never wrap
    # vertices independently (that would stretch a seam across the image).
    height, width = mask.shape
    uv = np.asarray(triangle, dtype=np.float64)
    uv -= np.floor(uv.mean(axis=0))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            points = (uv + (dx, dy)) * (width, height)
            lo = np.maximum(np.floor(points.min(axis=0)).astype(int), 0)
            hi = np.minimum(np.ceil(points.max(axis=0)).astype(int), (width-1, height-1))
            if np.any(hi < lo):
                continue
            a, b, c = points
            edge_b, edge_c = b-a, c-a
            area = edge_b[0]*edge_c[1] - edge_b[1]*edge_c[0]
            if abs(area) < 1e-9:
                continue
            yy, xx = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
            x, y = xx + .5, yy + .5
            u = ((b[0]-x)*(c[1]-y)-(b[1]-y)*(c[0]-x)) / area
            v = ((c[0]-x)*(a[1]-y)-(c[1]-y)*(a[0]-x)) / area
            w = 1-u-v
            mask[lo[1]:hi[1]+1, lo[0]:hi[0]+1] |= (u >= -1e-5) & (v >= -1e-5) & (w >= -1e-5)


def dilate(mask, iterations):
    for _ in range(iterations):
        padded = np.pad(mask, 1)
        mask = np.logical_or.reduce([padded[y:y+mask.shape[0], x:x+mask.shape[1]]
                                     for y in range(3) for x in range(3)])
    return mask


def recolor(pixels, mask, target, reference):
    # Preserve painted shading/detail instead of filling the selected region.
    luminance = pixels[..., :3] @ np.array((.2126, .7152, .0722))
    shade = np.clip(luminance / reference, 0, 1.6)
    rgb = np.clip(shade[..., None] * np.asarray(target), 0, 1)
    pixels[..., :3][mask] = rgb[mask]


def save_image(name, pixels):
    height, width, _ = pixels.shape
    image = bpy.data.images.new(name, width=width, height=height, alpha=True)
    image.colorspace_settings.name = 'sRGB'
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw = str(OUT / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    bpy.data.images.remove(image)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/styloo_elf/elf.glb'))
    obj = bpy.data.objects['elfBody']
    mesh = obj.data
    uv = mesh.uv_layers.active
    names = {g.index: g.name for g in obj.vertex_groups}
    adjacency = [set() for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    unseen = set(range(len(adjacency)))
    hair_vertices = set()
    while unseen:
        stack = [unseen.pop()]
        component = []
        while stack:
            index = stack.pop()
            component.append(index)
            for near in adjacency[index]:
                if near in unseen:
                    unseen.remove(near)
                    stack.append(near)
        seeds = sum(any('hair' in names[g.group] and g.weight > .2
                        for g in mesh.vertices[i].groups) for i in component)
        # Connected hair pieces include their head-weighted roots. Exclude
        # nearby skin/ear components with only incidental hair influence.
        if seeds / len(component) > .1:
            hair_vertices.update(component)
    eye_vertices = {v.index for v in mesh.vertices
                    if any(names[g.group].startswith('DEF-eye') and g.weight > .2 for g in v.groups)}
    first = bpy.data.images.load(str(ROOT / 'assets/characters/styloo_elf/elf_elfFirst_color.png'), check_existing=False)
    second = bpy.data.images.load(str(ROOT / 'assets/characters/styloo_elf/elf_elfSecond_color.png'), check_existing=False)
    width, height = first.size
    first_pixels = np.array(first.pixels[:], dtype=np.float32).reshape(height, width, 4)
    second_pixels = np.array(second.pixels[:], dtype=np.float32).reshape(height, width, 4)
    hair_mask = np.zeros((height, width), dtype=bool)
    eye_mask = np.zeros_like(hair_mask)
    mesh.calc_loop_triangles()
    for triangle in mesh.loop_triangles:
        if triangle.material_index != 0:
            continue
        coords = [uv.data[i].uv[:] for i in triangle.loops]
        if all(i in hair_vertices for i in triangle.vertices):
            rasterize(hair_mask, coords)
        if all(i in eye_vertices for i in triangle.vertices):
            rasterize(eye_mask, coords)
    hair_mask = dilate(hair_mask, 6)
    eye_mask = dilate(eye_mask, 2)
    r, g, b = first_pixels[..., :3].transpose(2, 0, 1)
    # Topology-derived eye mask plus green chroma preserves sclera, pupil,
    # eyelashes and baked white highlights.
    iris_mask = eye_mask & (g > r*1.15) & (g > b*1.08) & (g-r > .035)
    r, g, b = second_pixels[..., :3].transpose(2, 0, 1)
    cloth_mask = (g > r*1.06) & (g > b*1.1) & (g-r > .015)
    trim_mask = (r > g*1.025) & (g > b*1.35) & (r > .48)
    assert hair_mask.sum() > 10000 and iris_mask.sum() > 100
    for slug, palette in PALETTES.items():
        face = first_pixels.copy()
        outfit = second_pixels.copy()
        recolor(face, hair_mask, palette['hair'], .58)
        recolor(face, iris_mask, palette['eye'], .33)
        recolor(outfit, cloth_mask, palette['cloth'], .24)
        if 'trim' in palette:
            recolor(outfit, trim_mask, palette['trim'], .72)
        assert np.array_equal(face[..., 3], first_pixels[..., 3])
        assert np.array_equal(face[~(hair_mask | iris_mask)], first_pixels[~(hair_mask | iris_mask)])
        save_image(slug + '_appearance', face)
        save_image(slug + '_outfit', outfit)
    report = {'hair_pixels': int(hair_mask.sum()), 'iris_pixels': int(iris_mask.sum()),
              'cloth_pixels': int(cloth_mask.sum()), 'palettes': PALETTES,
              'geometry_modified': False, 'rig_modified': False}
    (OUT / 'palettes.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('Created three palettes:', json.dumps(report))


if __name__ == '__main__':
    main()
