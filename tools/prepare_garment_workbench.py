"""Prepare an inspected Blender source for tailoring, without runtime exports.

blender --background --factory-startup --python-exit-code 1 --python tools/prepare_garment_workbench.py
"""
from collections import defaultdict
from pathlib import Path
import json
import sys
import bpy
import bmesh

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/authoring'
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'tools'))
from create_hair_variants import hair_components


def retain_faces(mesh,indices):
    bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in indices],context='FACES')
    bm.to_mesh(mesh);bm.free();mesh.update()


def boundary_report(mesh):
    # glTF duplicates vertices at UV/normal seams. Match positions for the
    # audit so ordinary seams aren't mislabeled as missing body geometry.
    positions={v.index:tuple(round(c,5) for c in v.co) for v in mesh.vertices}
    edges=defaultdict(int)
    for p in mesh.polygons:
        ids=list(p.vertices)
        for i,a in enumerate(ids):
            pa,pb=positions[a],positions[ids[(i+1)%len(ids)]]
            if pa!=pb:edges[tuple(sorted((pa,pb)))]+=1
    adjacency=defaultdict(set)
    for (a,b),count in edges.items():
        if count==1 and min(a[2],b[2])<1.76:
            adjacency[a].add(b);adjacency[b].add(a)
    unseen=set(adjacency);chains=[]
    while unseen:
        stack=[unseen.pop()];points=[]
        while stack:
            p=stack.pop();points.append(p)
            for q in adjacency[p]:
                if q in unseen:unseen.remove(q);stack.append(q)
        if len(points)>3:
            chains.append({'vertices':len(points),'bounds':[
                [min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)],
                'closed':all(len(adjacency[p])==2 for p in points)})
    return sorted(chains,key=lambda c:c['bounds'][2][0])


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/styloo_elf/elf.glb'))
    source=bpy.data.objects['elfBody']
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    original_bone_names=[b.name for b in rig.data.bones]
    source_collection=bpy.data.collections.new('01 SOURCE - untouched vendor reference')
    bpy.context.scene.collection.children.link(source_collection)
    for obj in list(bpy.context.scene.objects):
        for collection in list(obj.users_collection):collection.objects.unlink(obj)
        source_collection.objects.link(obj)
    source_collection.hide_render=True
    source_collection.hide_viewport=True
    source_collection['purpose']='Original geometry and weights; comparison only. Never export this reference collection.'
    source.name='VendorBody_REFERENCE';rig.name='VendorRig_REFERENCE'
    work=bpy.data.collections.new('02 WORK - inspect and tailor')
    bpy.context.scene.collection.children.link(work)
    working_rig=rig.copy();working_rig.data=rig.data.copy();working_rig.name='elfgame_root'
    work.objects.link(working_rig)
    selected=hair_components(source)
    selections={
        'Skin_SOURCE_INCOMPLETE':{p.index for p in source.data.polygons if p.material_index==0 and not all(v in selected for v in p.vertices)},
        'Costume_ORIGINAL':{p.index for p in source.data.polygons if p.material_index==1},
        'Hair_ORIGINAL':{p.index for p in source.data.polygons if all(v in selected for v in p.vertices)},
    }
    report={'source':'assets/characters/styloo_elf/elf.glb','bone_count':len(original_bone_names),'parts':{},
            'status':'Authoring foundation only; missing body surfaces have not been rebuilt.'}
    for name,faces in selections.items():
        obj=source.copy();obj.data=source.data.copy();obj.name=name
        obj.parent=working_rig;work.objects.link(obj)
        for modifier in obj.modifiers:
            if modifier.type=='ARMATURE':modifier.object=working_rig
        retain_faces(obj.data,faces)
        obj['purpose']='Inspect source topology, UVs and existing weights before rebuilding.'
        report['parts'][name]={'polygons':len(obj.data.polygons),'vertices':len(obj.data.vertices)}
        if name.startswith('Skin'):
            report['skin_boundary_candidates_below_neck']=boundary_report(obj.data)
            obj['complete_body']=False
    assert original_bone_names==[b.name for b in working_rig.data.bones]
    for a,b in zip(rig.data.bones,working_rig.data.bones):
        assert all(abs(a.matrix_local[i][j]-b.matrix_local[i][j])<1e-7 for i in range(4) for j in range(4))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in work.objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=bpy.data.objects['Costume_ORIGINAL']
    # A useful initial authoring view; file stays in the original rest pose.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_location=(0,0,1.2)
                area.spaces.active.region_3d.view_distance=2.6
    (OUT/'body_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'garment_workbench.blend'))
    print('Prepared workbench:',json.dumps(report))


if __name__=='__main__':main()
