"""Build skinned hairstyle studies in Blender without changing the elf rig.

blender --background --factory-startup --python-exit-code 1 --python tools/create_hair_variants.py
"""
from pathlib import Path
from math import sin, cos, pi
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/hairstyles'


def hair_components(mesh):
    names = {g.index: g.name for g in mesh.vertex_groups}
    adjacency = [set() for _ in mesh.data.vertices]
    for edge in mesh.data.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    unseen = set(range(len(adjacency)))
    selected = set()
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
                        for g in mesh.data.vertices[i].groups) for i in component)
        if seeds / len(component) > .1:
            selected.update(component)
    return selected


def hair_material(name, color):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .65
    return material


def tube(name, centers, radius, material, armature, sides=16):
    vertices, faces = [], []
    for i, center in enumerate(centers):
        tangent = Vector(centers[min(i+1, len(centers)-1)]) - Vector(centers[max(0, i-1)])
        tangent.normalize()
        axis = Vector((1, 0, 0)) if abs(tangent.x) < .8 else Vector((0, 1, 0))
        normal = tangent.cross(axis).normalized()
        binormal = tangent.cross(normal).normalized()
        width = radius * (1 - .28*i/(len(centers)-1))
        for j in range(sides):
            angle = j*2*pi/sides
            groove = 1.0 + .065*cos(angle*5)
            point = Vector(center) + width*groove*(cos(angle)*normal + sin(angle)*binormal)
            vertices.append(tuple(point))
        if i:
            for j in range(sides):
                a=(i-1)*sides+j; b=(i-1)*sides+(j+1)%sides
                faces.append((a,b,i*sides+(j+1)%sides,i*sides+j))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(centers)-1)*sides+j for j in range(sides)))
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj=bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth=True
    group=obj.vertex_groups.new(name='DEF-spine.006')
    group.add(list(range(len(vertices))), 1.0, 'REPLACE')
    modifier=obj.modifiers.new('Existing elf skeleton', 'ARMATURE')
    modifier.object=armature
    obj.parent=armature
    return obj


def build(style):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/styloo_elf/elf.glb'))
    body=bpy.data.objects['elfBody']
    armature=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    rest=[tuple(tuple(row) for row in bone.matrix_local) for bone in armature.data.bones]
    hair=hair_components(body)
    for index in hair:
        point=body.data.vertices[index].co
        if point.z < 1.93:
            if style == 'cropped_bob':
                point.z = 1.93 - (1.93-point.z)*.42
                point.x *= 1.05
            else:
                amount = min(1.0, (1.93-point.z)/.23)
                eased = amount*amount*(3-2*amount)
                target_x = 0.0 if style == 'high_bun' else (.095 if point.x > 0 else -.095)
                point.x = point.x*(1-eased)+target_x*eased
                point.y = point.y*(1-eased)+(.105 if style == 'high_bun' else .055)*eased
                point.z = 1.93-.025*amount
    # New pieces are rigidly skinned to the head; no physics is implied.
    base=(.13,.024,.008) if style=='high_bun' else (.004,.006,.010)
    dark=hair_material('StyleHairDark',base)
    light=hair_material('StyleHairHighlight',tuple(c*1.2 for c in base))
    if style=='high_bun':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1.0, location=(0,.082,2.025))
        core=bpy.context.object
        core.name='BunCore'
        core.scale=(.044,.042,.050)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        core.data.materials.append(dark)
        for polygon in core.data.polygons:
            polygon.use_smooth=True
        group=core.vertex_groups.new(name='DEF-spine.006')
        group.add(list(range(len(core.data.vertices))),1.0,'REPLACE')
        modifier=core.modifiers.new('Existing elf skeleton','ARMATURE')
        modifier.object=armature
        core.parent=armature
        # A woven coil with three interlaced strands above the crown.
        for strand in range(3):
            centers=[]
            for i in range(401):
                t=i/400; angle=t*2*pi*7
                weave=angle*3+strand*2*pi/3
                radius=.052*sin(pi*(.08+.84*t))+.005*cos(weave)
                centers.append((radius*cos(angle), .082+radius*sin(angle), 1.970+.11*t+.005*sin(weave)))
            tube('BunStrand%d'%strand,centers,.0075,light if strand==1 else dark,armature)
    elif style=='twin_braids':
        for side in (-1,1):
            for strand in range(3):
                centers=[]
                for i in range(100):
                    t=i/99; angle=t*2*pi*4.5+strand*2*pi/3
                    radius=.013*(1-.65*t)
                    centers.append((side*(.102+.038*t)+radius*cos(angle), .048+.015*t+radius*sin(angle), 1.913-.30*t))
                tube('Braid%dStrand%d'%(side,strand),centers,.0075,light if strand==1 else dark,armature)
            # A small gold binding around each braid tip.
            gold=hair_material('BraidTie',(.55,.32,.075))
            center=Vector((side*.139,.063,1.620))
            ring=[tuple(center+Vector((.011*cos(i*2*pi/40),.011*sin(i*2*pi/40),0))) for i in range(41)]
            tube('BraidTie%d'%side,ring,.0025,gold,armature)
    assert rest == [tuple(tuple(row) for row in bone.matrix_local) for bone in armature.data.bones]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sources'/(style+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(style+'.glb')), export_format='GLB',
        export_animations=False, export_skins=True, export_def_bones=False,
        export_leaf_bone=False, export_all_influences=True)
    print('Created',style,'with',len(hair),'reshaped hair vertices and unchanged bone rests')


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'sources').mkdir(exist_ok=True)
    for style in ('cropped_bob','high_bun','twin_braids'):
        build(style)
