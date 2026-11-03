"""Photo-based visual reconstruction. Units/proportions are estimates, not measured CAD."""
import bpy,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metallic=0,roughness=.3,transmission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    if 'Transmission Weight' in p.inputs:p.inputs['Transmission Weight'].default_value=transmission
    return m
silver=material('Silver case',(.57,.60,.57),.75,.27);black=material('Black inner plate',(.025,.033,.028),.05,.5);glass=material('Transparent keycaps',(.8,.9,.85),0,.17,.82);gold=material('Gold knob',(.73,.45,.10),.85,.28);switch=material('Visible switch',(.31,.45,.36),0,.4)
def cube(name,location,scale,mat,bevel=.06,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=bevel;mod.segments=4
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');o.data.materials.append(mat)
    if parent:o.parent=parent
    return o
knurl_recess=material('Knurl recesses',(.22,.12,.025),.8,.32)
def rounded_knob(location,parent):
    # One continuous surface: a .14-high crown on a .42-radius grip, matching board-viewer.js.
    profile=[(.40,.48),(.42,.50),(.42,1.16)]
    profile.extend((.42*math.cos(i/24*math.pi/2),1.16+.14*math.sin(i/24*math.pi/2)) for i in range(1,24))
    segments=64
    vertices=[(radius*math.cos(i/segments*math.tau),radius*math.sin(i/segments*math.tau),height) for radius,height in profile for i in range(segments)]
    bottom=len(vertices);vertices.append((0,0,.48))
    top=len(vertices);vertices.append((0,0,1.30))
    faces=[]
    for ring in range(len(profile)-1):
        for i in range(segments):
            a=ring*segments+i;b=ring*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    last=(len(profile)-1)*segments
    for i in range(segments):
        following=(i+1)%segments
        faces.extend([(bottom,following,i),(last+i,last+following,top)])
    mesh=bpy.data.meshes.new('Continuous rounded knob');mesh.from_pydata(vertices,[],faces);mesh.update()
    for face in mesh.polygons:
        face.use_smooth=True
        face.material_index=1 if max(vertices[i][2] for i in face.vertices)<=1.16 else 0
    knob=bpy.data.objects.new('Gold rounded knob',mesh);bpy.context.collection.objects.link(knob)
    knob.location=(*location,0);knob.parent=parent;mesh.materials.append(gold);mesh.materials.append(knurl_recess)
cube('Case',(0,0,.21),(4.42,4.42,.36),silver,.16);cube('Inner plate',(0,0,.43),(4.12,4.12,.10),black,.12)
control_map={}
for r in range(4):
    for c in range(4):
        ident=f'key:{r}:{c}';group=bpy.data.objects.new(ident,None);bpy.context.collection.objects.link(group);group['inputID']=ident;control_map[ident]={'node':ident,'kind':'knobPress' if (r,c)==(0,3) else 'key'}
        x,y=c-1.5,1.5-r
        if (r,c)==(0,3):
            rounded_knob((x,y),group)
            for i in range(64):
                for direction in (-1,1):
                    curve=bpy.data.curves.new('Knurl','CURVE');curve.dimensions='3D';curve.bevel_depth=.008;curve.bevel_resolution=0
                    spline=curve.splines.new('POLY');spline.points.add(8)
                    for j,p in enumerate(spline.points):
                        a=i/64*math.tau+direction*j/8*.24;p.co=(x+math.cos(a)*.425,y+math.sin(a)*.425,.57+j/8*.58,1)
                    ridge=bpy.data.objects.new('Diamond knurl',curve);bpy.context.collection.objects.link(ridge);ridge.parent=group;curve.materials.append(gold)
        else:
            cube('Switch base',(x,y,.535),(.71,.71,.13),switch,.06,group)
            cube('Switch stem',(x,y,.70),(.25,.25,.27),switch,.03,group)
            # Four transparent walls and a thin rounded top preserve an actual cavity.
            for dx,dy,sx,sy in [(-.405,0,.055,.84),(.405,0,.055,.84),(0,-.405,.84,.055),(0,.405,.84,.055)]:cube('Clear cap wall',(x+dx,y+dy,.83),(sx,sy,.37),glass,.025,group)
            cube('Clear cap top',(x,y,1.02),(.86,.86,.055),glass,.10,group)
for direction in ('ccw','cw'):control_map[f'encoder:0:{direction}']={'node':'key:0:3','kind':'encoder','separateControl':True}
ROOT.joinpath('ui/models/control-map.json').write_text(json.dumps(control_map,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/board/klawos.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'ui/models/klawos.glb'),export_format='GLB',export_extras=True,export_apply=True)
