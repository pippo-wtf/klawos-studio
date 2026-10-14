"""Photo-based visual reconstruction. Units/proportions are estimates, not measured CAD."""
import bpy,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metallic=0,roughness=.3,transmission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    if 'Transmission Weight' in p.inputs:p.inputs['Transmission Weight'].default_value=transmission
    return m
silver=material('Silver case',(.57,.60,.57),.75,.27);black=material('Black inner plate',(.025,.033,.028),.05,.5);glass=material('Transparent keycaps',(.8,.9,.85),0,.17,.82);gold=material('Gold knob',(.73,.45,.10),.85,.23);switch=material('Visible switch',(.31,.45,.36),0,.4)
def cube(name,location,scale,mat,bevel=.06,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=bevel;mod.segments=4
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');o.data.materials.append(mat)
    if parent:o.parent=parent
    return o
cube('Case',(0,0,.21),(4.42,4.42,.36),silver,.16);cube('Inner plate',(0,0,.43),(4.12,4.12,.10),black,.12)
control_map={}
for r in range(4):
    for c in range(4):
        ident=f'key:{r}:{c}';group=bpy.data.objects.new(ident,None);bpy.context.collection.objects.link(group);group['inputID']=ident;control_map[ident]={'node':ident,'kind':'knobPress' if (r,c)==(0,3) else 'key'}
        x,y=c-1.5,1.5-r
        if (r,c)==(0,3):
            bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.42,depth=.76,location=(x,y,.86));o=bpy.context.object;o.name='Gold knurled barrel';o.parent=group;o.data.materials.append(gold);mod=o.modifiers.new('Rounded rims','BEVEL');mod.width=.025;mod.segments=3
            bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=20,radius=1,location=(x,y,1.23));top=bpy.context.object;top.name='Rounded gold top';top.scale=(.41,.41,.07);top.parent=group;top.data.materials.append(gold)
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
