"""Build modular hair, region masks and the original costume for the creator.

blender --background --factory-startup --python-exit-code 1 --python tools/create_creator_assets.py
"""
from pathlib import Path
import sys
import bpy
import bmesh
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/creator'
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode=True
from create_hair_variants import hair_components
from create_character_variants import rasterize, dilate


def fresh(path):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    body=bpy.data.objects['elfBody']
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    return body,arm


def filter_faces(body, keep):
    mesh=body.data
    bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
    remove=[bm.faces[p.index] for p in mesh.polygons if not keep(p)]
    bmesh.ops.delete(bm,geom=remove,context='FACES')
    bm.to_mesh(mesh);bm.free();mesh.update()


def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        export_animations=False,export_skins=True,export_def_bones=False,
        export_leaf_bone=False,export_all_influences=True)


def masks():
    body,_=fresh(ROOT/'assets/characters/styloo_elf/elf.glb')
    mesh=body.data;uv=mesh.uv_layers.active;hair=hair_components(body)
    names={g.index:g.name for g in body.vertex_groups}
    eyes={v.index for v in mesh.vertices if any(names[g.group].startswith('DEF-eye') and g.weight>.2 for g in v.groups)}
    mask_h=np.zeros((2048,2048),bool);mask_e=np.zeros_like(mask_h)
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        if tri.material_index!=0:continue
        coords=[uv.data[i].uv[:] for i in tri.loops]
        if all(i in hair for i in tri.vertices):rasterize(mask_h,coords)
        if all(i in eyes for i in tri.vertices):rasterize(mask_e,coords)
    image=bpy.data.images.load(str(ROOT/'assets/characters/styloo_elf/elf_elfFirst_color.png'))
    pixels=np.asarray(image.pixels[:],dtype=np.float32).reshape(2048,2048,4)
    r,g,b=pixels[...,:3].transpose(2,0,1)
    mask_e=dilate(mask_e,2)&(g>r*1.15)&(g>b*1.08)&(g-r>.035)
    rgba=np.zeros_like(pixels);rgba[...,0]=dilate(mask_h,6);rgba[...,1]=mask_e;rgba[...,3]=1
    target=bpy.data.images.new('Creator region masks',width=2048,height=2048,alpha=True)
    target.colorspace_settings.name='Non-Color';target.pixels.foreach_set(rgba.ravel())
    target.filepath_raw=str(OUT/'appearance_mask.png');target.file_format='PNG';target.save()


def hair_module(style,path):
    body,arm=fresh(path);selected=hair_components(body)
    filter_faces(body,lambda p:all(i in selected for i in p.vertices))
    export('hair_'+style)


def original_outfit():
    body,arm=fresh(ROOT/'assets/characters/styloo_elf/elf.glb')
    hair=hair_components(body)
    filter_faces(body,lambda p:not all(i in hair for i in p.vertices))
    export('outfit_elf')


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    if '--original-outfit-only' not in sys.argv:
        masks()
        for style,path in [('long',ROOT/'assets/characters/styloo_elf/elf.glb'),
                           ('bob',ROOT/'assets/characters/hairstyles/cropped_bob.glb'),
                           ('bun',ROOT/'assets/characters/hairstyles/high_bun.glb'),
                           ('braids',ROOT/'assets/characters/hairstyles/twin_braids.glb')]:hair_module(style,path)
    original_outfit()
