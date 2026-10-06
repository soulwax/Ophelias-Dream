"""Build modular hair and three skinned outfits for the character creator.

blender --background --factory-startup --python-exit-code 1 --python tools/create_creator_assets.py
"""
from pathlib import Path
from math import sin, cos, pi
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

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


def export(name,save_source=False):
    if save_source:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sources'/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        export_animations=False,export_skins=True,export_def_bones=False,
        export_leaf_bone=False,export_all_influences=True)


def material(name,color,roughness=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Roughness'].default_value=roughness
    return m


def bind(obj,arm,body):
    obj.parent=arm
    mod=obj.modifiers.new('Elf skin','ARMATURE');mod.object=arm
    tree=KDTree(len(body.data.vertices))
    for v in body.data.vertices:tree.insert(v.co,v.index)
    tree.balance()
    names={g.index:g.name for g in body.vertex_groups}
    groups={}
    for v in obj.data.vertices:
        _,index,_=tree.find(obj.matrix_world@v.co)
        weights=[(names[g.group],g.weight) for g in body.data.vertices[index].groups if g.weight>0.001]
        total=sum(w for _,w in weights)
        for name,weight in weights:
            group=groups.setdefault(name,obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name))
            group.add([v.index],weight/total,'REPLACE')


def mesh_object(name,vertices,faces,mat,arm,body):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=True
    bind(obj,arm,body)
    # Cylindrical/strip UVs keep these source meshes ready for texture work.
    uv=mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        for i in p.loop_indices:
            v=mesh.vertices[mesh.loops[i].vertex_index].co
            uv.data[i].uv=((v.x+.7)/1.4,v.z/2.2)
    return obj


def shell(name,rings,mat,arm,body,segments=48,start=0,end=2*pi,folds=0):
    vertices=[];faces=[]
    closed=abs(end-start-2*pi)<.01
    columns=segments if closed else segments+1
    for z,rx,ry in rings:
        for j in range(columns):
            a=start+(end-start)*j/segments
            ripple=1+folds*cos(a*10+z*5)
            x=rx*cos(a)*ripple
            y=ry*sin(a)*ripple-.015
            if name=='Fitted torso' and sin(a)<0:
                breast=.059*np.exp(-((abs(x)-.072)/.052)**2-((z-1.51)/.082)**2)
                y-=breast*max(0,-sin(a))
            vertices.append((x,y,z))
    for i in range(len(rings)-1):
        for j in range(segments):
            k=(j+1)%columns
            faces.append((i*columns+j,i*columns+k,(i+1)*columns+k,(i+1)*columns+j))
    return mesh_object(name,vertices,faces,mat,arm,body)


def sleeve(name,side,radii,mat,arm,body):
    shoulder=arm.data.bones['DEF-upper_arm.'+side].head_local
    elbow=arm.data.bones['DEF-forearm.'+side].head_local
    wrist=arm.data.bones['DEF-hand.'+side].head_local
    points=[]
    for i,r in enumerate(radii):
        t=i/(len(radii)-1)
        center=shoulder.lerp(elbow,t*2) if t<=.5 else elbow.lerp(wrist,(t-.5)*2)
        direction=(elbow-shoulder).normalized() if t<=.5 else (wrist-elbow).normalized()
        axis=Vector((0,1,0));u=direction.cross(axis).normalized();v=direction.cross(u).normalized()
        for j in range(24):
            a=j*2*pi/24
            radius=r*(1+.025*sin(a*5+t*11))
            points.append(tuple(center+radius*(cos(a)*u+sin(a)*v)))
    faces=[(i*24+j,i*24+(j+1)%24,(i+1)*24+(j+1)%24,(i+1)*24+j)
           for i in range(len(radii)-1) for j in range(24)]
    return mesh_object(name+side,points,faces,mat,arm,body)


def orb(name,location,scale,mat,arm,body):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    for p in obj.data.polygons:p.use_smooth=True
    bind(obj,arm,body)
    return obj


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


def outfit(style):
    body,arm=fresh(ROOT/'assets/characters/styloo_elf/elf.glb')
    hair=hair_components(body)
    if style=='elf':
        filter_faces(body,lambda p:not all(i in hair for i in p.vertices))
        export('outfit_elf');return
    # Keep the full skin and original boots. Replace chest/skirts/bracers,
    # shoulder strap and quiver rather than stacking outfits over them.
    reference=body.copy();reference.data=body.data.copy()
    # Keep complete boot components, never cropped pieces of a long skirt.
    adjacency=[set() for _ in body.data.vertices]
    for e in body.data.edges:
        a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
    unseen=set(range(len(adjacency)));boots=set()
    while unseen:
        stack=[unseen.pop()];component=[]
        while stack:
            index=stack.pop();component.append(index)
            for near in adjacency[index]:
                if near in unseen:unseen.remove(near);stack.append(near)
        if max(body.data.vertices[i].co.z for i in component)<.63:boots.update(component)
    def keep(p):
        if all(i in hair for i in p.vertices):return False
        if p.material_index==1:return all(i in boots for i in p.vertices)
        center=sum((body.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        return not (1.265<center.z<1.735 and abs(center.x)<.20)
    filter_faces(body,keep)
    cloth=material('CreatorCloth',(.30,.30,.30))
    trim=material('CreatorTrim',(.38,.38,.38),.62)
    leather=material('CreatorLeather',(.038,.029,.024),.68)
    cream=material('CreatorLinen',(.68,.59,.43),.92)
    fur=material('CreatorFur',(.76,.71,.60),1.0)
    lining=material('CreatorLining',(.05,.058,.065),.9)
    # These suits follow actual skin geometry, retaining original weights
    # and contours rather than placing a loose cylindrical garment over it.
    main_slot=len(body.data.materials);body.data.materials.append(cloth)
    accent_slot=len(body.data.materials);body.data.materials.append(lining)
    leather_slot=len(body.data.materials);body.data.materials.append(leather)
    for p in body.data.polygons:
        center=sum((body.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        if p.material_index==0 and center.z<1.755:
            p.material_index=main_slot
    # Transfer against the intact reference, including its fitted garments.
    # Covered skin stays out of the export, while the source remains intact.
    body=reference
    # The vendor body has an abdomen gap under its original bodice. Bridge
    # just that region, with close fitting rings meeting its skin contours.
    abdomen=[(1.245,.204,.136),(1.285,.175,.124),(1.315,.164,.117),(1.345,.148,.112),
             (1.375,.143,.112),(1.405,.150,.115),(1.435,.158,.118),(1.465,.167,.121),
             (1.495,.171,.120),(1.525,.174,.117),(1.555,.174,.112),(1.585,.170,.101),
             (1.615,.166,.092),(1.65,.162,.080),(1.682,.113,.070),(1.708,.072,.068),(1.745,.065,.068)]
    bridge=shell('Fitted torso',abdomen,cloth,arm,body,segments=64)
    shell('Close collar',[(1.738,.069,.068),(1.773,.062,.065)],cloth,arm,body)
    for side in ('L','R'):
        sleeve('Fitted sleeve ',side,[.060,.061,.055,.049,.043,.037,.033],cloth,arm,body)
        sign=1 if side=='L' else -1
        orb('Seamless shoulder '+side,(sign*.145,0,1.64),(.073,.071,.076),cloth,arm,body)
    if style=='wayfarer':
        # Flat centre fastenings and dark flank panels: technical winter suit.
        for z,y in [(1.37,-.139),(1.43,-.17),(1.51,-.188),(1.60,-.165)]:
            orb('Suit fastening',(0,y,z),(.005,.003,.012),trim,arm,body)
    elif style=='hearth':
        shell('Nocturne collar trim',[(1.767,.064,.067),(1.777,.064,.067)],trim,arm,body)
        shell('Waist piping',[(1.348,.155,.119),(1.359,.152,.120)],trim,arm,body)
        orb('Collar clasp',(0,-.087,1.755),(.008,.003,.014),trim,arm,body)
    elif style=='ranger':
        shell('Low profile belt',[(1.312,.174,.127),(1.335,.163,.125)],leather,arm,body)
        orb('Belt buckle',(0,-.147,1.324),(.017,.004,.014),trim,arm,body)
    # A transfer reference must never be exported as a second body.
    reference_mesh=reference.data
    bpy.data.objects.remove(reference)
    bpy.data.meshes.remove(reference_mesh)
    export('outfit_'+style,True)


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'sources').mkdir(exist_ok=True)
    if '--outfits-only' not in sys.argv:
        masks()
        for style,path in [('long',ROOT/'assets/characters/styloo_elf/elf.glb'),
                           ('bob',ROOT/'assets/characters/hairstyles/cropped_bob.glb'),
                           ('bun',ROOT/'assets/characters/hairstyles/high_bun.glb'),
                           ('braids',ROOT/'assets/characters/hairstyles/twin_braids.glb')]:hair_module(style,path)
    for style in ('elf','wayfarer','hearth','ranger'):outfit(style)
