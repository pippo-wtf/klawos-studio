import * as THREE from './vendor/three/three.module.js';
import {GLTFLoader} from './vendor/three/GLTFLoader.js';
import {OrbitControls} from './vendor/three/OrbitControls.js';
export function mountBoard(container,onSelect){
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(33,1,.1,100);camera.position.set(5.2,8.4,8.5);
 const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.35;container.prepend(renderer.domElement);
 const controls=new OrbitControls(camera,renderer.domElement);controls.target.set(0,.2,0);controls.enablePan=false;controls.minDistance=7;controls.maxDistance=17;controls.maxPolarAngle=Math.PI*.43;controls.enableDamping=false;controls.update();
 scene.add(new THREE.HemisphereLight(0xffffff,0x8d9284,3));const sun=new THREE.DirectionalLight(0xfff8eb,5);sun.position.set(-3,8,-6);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-4;sun.shadow.camera.right=4;sun.shadow.camera.top=4;sun.shadow.camera.bottom=-4;sun.shadow.normalBias=.02;scene.add(sun);const fill=new THREE.DirectionalLight(0xd9e7f0,3);fill.position.set(4,3,-4);scene.add(fill);
 // Softbox reflections reveal the shallow convex crown without making the knob taller.
 const reflectionScene=new THREE.Scene();reflectionScene.background=new THREE.Color(0x242424);
 for(const [width,height,x,y,z,strength] of [[4,6,-4,5,3,3],[1.5,4,4,2,1,2],[3,1,0,4,-4,1.5]]){
   const panel=new THREE.Mesh(new THREE.PlaneGeometry(width,height),new THREE.MeshBasicMaterial({color:new THREE.Color(1,1,1).multiplyScalar(strength),side:THREE.DoubleSide}));
   panel.position.set(x,y,z);panel.lookAt(0,0,0);reflectionScene.add(panel);
 }
 const pmrem=new THREE.PMREMGenerator(renderer),knobReflections=pmrem.fromScene(reflectionScene,.04);
 pmrem.dispose();reflectionScene.traverse(o=>{o.geometry?.dispose();o.material?.dispose()});
 function reflectGold(material){material.envMap=knobReflections.texture;material.envMapIntensity=.8;return material;}
 const metal=new THREE.MeshStandardMaterial({color:0xc1c5bd,metalness:.72,roughness:.27}),plate=new THREE.MeshStandardMaterial({color:0x202521,roughness:.48}),gold=new THREE.MeshStandardMaterial({color:0xd9ac48,metalness:.8,roughness:.28}),glass=new THREE.MeshPhysicalMaterial({color:0xd9e4df,metalness:0,roughness:.16,transmission:.67,transparent:true,opacity:.72,thickness:.12,ior:1.46,clearcoat:1});
 reflectGold(gold);
 function rounded(w,d,h,r,material){const s=new THREE.Shape();const x=-w/2,y=-d/2;s.moveTo(x+r,y);s.lineTo(x+w-r,y);s.quadraticCurveTo(x+w,y,x+w,y+r);s.lineTo(x+w,y+d-r);s.quadraticCurveTo(x+w,y+d,x+w-r,y+d);s.lineTo(x+r,y+d);s.quadraticCurveTo(x,y+d,x,y+d-r);s.lineTo(x,y+r);s.quadraticCurveTo(x,y,x+r,y);const g=new THREE.ExtrudeGeometry(s,{depth:h,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.035,bevelThickness:.035,curveSegments:8});g.rotateX(-Math.PI/2);const m=new THREE.Mesh(g,material);m.castShadow=true;m.receiveShadow=true;return m;}
 const base=rounded(4.42,4.42,.32,.24,metal);base.position.y=.05;scene.add(base);const inner=rounded(4.12,4.12,.07,.14,plate);inner.position.y=.39;scene.add(inner);
 const picking=[],keys=new Map(),procedural=[base,inner];let disposed=false,loaded=null;for(let r=0;r<4;r++)for(let c=0;c<4;c++){
   const group=new THREE.Group();group.position.set(c-1.5,.47,r-1.5);group.userData.inputID=`key:${r}:${c}`;scene.add(group);procedural.push(group);keys.set(group.userData.inputID,group);
   if(r===0&&c===3){// Match the continuous .14-high crown in art/board/build_board.py.
     const profile=[new THREE.Vector2(0,.01),new THREE.Vector2(.40,.01),new THREE.Vector2(.42,.03),new THREE.Vector2(.42,.69)];
     for(let i=1;i<24;i++){const angle=i/24*Math.PI/2;profile.push(new THREE.Vector2(.42*Math.cos(angle),.69+.14*Math.sin(angle)));}
     profile.push(new THREE.Vector2(0,.83));
     const geometry=new THREE.LatheGeometry(profile,64),positions=geometry.getAttribute('position'),indices=geometry.index;
     let start=0,material=-1;
     for(let i=0;i<indices.count;i+=3){const crown=Math.min(...[0,1,2].map(j=>positions.getY(indices.getX(i+j))))>=.6899,next=crown?1:0;if(next!==material){if(i>start)geometry.addGroup(start,i-start,material);start=i;material=next;}}
     geometry.addGroup(start,indices.count-start,material);
     const recess=reflectGold(new THREE.MeshStandardMaterial({color:0x81612c,metalness:.8,roughness:.32}));
     const body=new THREE.Mesh(geometry,[recess,gold]);body.name='Gold rounded knob';body.castShadow=true;group.add(body);for(let i=0;i<64;i++){for(const direction of [-1,1]){const points=[];for(let j=0;j<=8;j++){const y=j/8*.58+.1;const a=i/64*Math.PI*2+direction*j/8*.24;points.push(new THREE.Vector3(Math.cos(a)*.425,y,Math.sin(a)*.425));}const ridge=new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),8,.009,3,false),gold);group.add(ridge);}}}
   else {const foot=rounded(.71,.71,.13,.06,new THREE.MeshStandardMaterial({color:0xaebdb4,roughness:.5}));group.add(foot);const stem=new THREE.Mesh(new THREE.BoxGeometry(.28,.3,.28),new THREE.MeshStandardMaterial({color:0x92b3a2,roughness:.3}));stem.position.y=.24;group.add(stem);const cap=rounded(.86,.86,.38,.11,glass);cap.position.y=.14;group.add(cap);const rim=rounded(.68,.68,.025,.11,new THREE.MeshPhysicalMaterial({color:0xf0f7f3,transparent:true,opacity:.35,roughness:.2}));rim.position.y=.54;group.add(rim);}
   group.traverse(obj=>{if(obj.isMesh)picking.push(obj)});
 }
 const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.ShadowMaterial({opacity:.16}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;floor.position.y=-.03;scene.add(floor);
 const highlight=new THREE.Box3Helper(new THREE.Box3(),0x748d51);highlight.visible=false;scene.add(highlight);
 new GLTFLoader().load(new URL('./models/klawos.glb',import.meta.url).href,gltf=>{
   if(disposed){gltf.scene.traverse(o=>o.geometry?.dispose());return;}
   loaded=gltf.scene;for(const item of procedural)scene.remove(item);keys.clear();picking.length=0;
   loaded.traverse(obj=>{if(obj.userData.inputID)keys.set(obj.userData.inputID,obj);if(obj.isMesh){obj.castShadow=true;obj.receiveShadow=true;for(const material of Array.isArray(obj.material)?obj.material:[obj.material]){if(['Gold knob','Knurl recesses'].includes(material.name))reflectGold(material);}picking.push(obj);}});scene.add(loaded);highlight.visible=false;render();
 },undefined,()=>{/* Procedural board and keyboard controls remain usable offline. */});
 const ray=new THREE.Raycaster();let pointerStart;
 const pointerdown=e=>pointerStart=[e.clientX,e.clientY];
 const pointerup=e=>{if(!pointerStart||Math.hypot(e.clientX-pointerStart[0],e.clientY-pointerStart[1])>5)return;const b=renderer.domElement.getBoundingClientRect();ray.setFromCamera(new THREE.Vector2((e.clientX-b.left)/b.width*2-1,-(e.clientY-b.top)/b.height*2+1),camera);const hit=ray.intersectObjects(picking)[0];if(hit){let obj=hit.object;while(obj&&!obj.userData.inputID)obj=obj.parent;if(obj)onSelect(obj.userData.inputID)}};
 renderer.domElement.addEventListener('pointerdown',pointerdown);renderer.domElement.addEventListener('pointerup',pointerup);
 function render(){renderer.render(scene,camera)}controls.addEventListener('change',render);
 const resize=new ResizeObserver(()=>{camera.aspect=container.clientWidth/container.clientHeight;camera.updateProjectionMatrix();renderer.setSize(container.clientWidth,container.clientHeight);render()});resize.observe(container);
 return {select(id){const obj=keys.get(id);highlight.visible=!!obj;if(obj)highlight.box.setFromObject(obj);render()},view(top){camera.position.set(...(top?[0,12,.001]:[5.2,8.4,8.5]));controls.update();render()},dispose(){disposed=true;resize.disconnect();controls.dispose();knobReflections.dispose();renderer.dispose();scene.traverse(o=>{o.geometry?.dispose();if(o.material){for(const m of Array.isArray(o.material)?o.material:[o.material])m.dispose()}});renderer.domElement.remove()}};
}
