#!/usr/bin/env python3
"""Original indexed hard-surface machines and service bay, authored for IRON//VEIL.
COLOR.rgb: coating; COLOR.a: roughness; UV2.x: metallic. No runtime primitive rig.
The recovered Wraith GLB is promoted unchanged. New chassis share manufactured
leg assemblies, with individual support layouts, armor, optics and cooling.
"""
from pathlib import Path
from collections import defaultdict
import json, struct, shutil, math
import numpy as np
from scipy.spatial import ConvexHull

ROOT=Path(__file__).resolve().parents[1];ASSETS=ROOT/'assets'
DARK=(.065,.083,.092,.38,.92);STEEL=(.34,.40,.43,.27,.98)
PAINT=(.38,.44,.39,.64,.65);AMBER=(.72,.36,.10,.58,.55)
RUBBER=(.022,.029,.032,.88,.04);CYAN=(.22,.72,.86,.28,.2)
HOT=(.90,.21,.04,.30,.18);WHITE=(.63,.66,.61,.62,.45)
def rotation(axis,angle):
 a=np.asarray(axis,float);a/=np.linalg.norm(a);x,y,z=a;c,s=math.cos(angle),math.sin(angle);t=1-c
 return np.array([[t*x*x+c,t*x*y-s*z,t*x*z+s*y],[t*x*y+s*z,t*y*y+c,t*y*z-s*x],[t*x*z-s*y,t*y*z+s*x,t*z*z+c]])

class Part:
 def __init__(self,name,at=(0,0,0)):self.name=name;self.at=list(at);self.groups=defaultdict(list)
 def triangles(self,positions,normals,mat=PAINT,emit=0,transform=None):
  p=np.asarray(positions,np.float32).reshape(-1,3);n=np.asarray(normals,np.float32).reshape(-1,3)
  if transform is not None:
   p=p@transform[:3,:3].T+transform[:3,3];n=n@np.linalg.inv(transform[:3,:3]);n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-9)
  a=np.empty((len(p),14),np.float32);a[:,:3]=p;a[:,3:6]=n;a[:,6:10]=mat[:4];a[:,10:12]=p[:,[0,2]]*.8;a[:,12]=mat[4];a[:,13]=1
  self.groups[emit].append(a)
 def box(self,at,size,mat=PAINT,bevel=.03,angles=(0,0,0),emit=0):
  h=np.asarray(size,float)*.5;b=min(bevel,min(h)*.4);pts=[]
  for x in (-1,1):
   for y in (-1,1):
    for z in (-1,1):
     for axis in range(3):
      v=h-b;v[axis]=h[axis];pts.append(v*np.array([x,y,z]))
  pts=np.unique(pts,axis=0);hull=ConvexHull(pts);triangles=[];normals=[]
  for tri,plane in zip(hull.simplices,hull.equations):
   p=pts[tri].copy();normal=plane[:3]
   if np.dot(np.cross(p[1]-p[0],p[2]-p[0]),normal)<0:p=p[[0,2,1]]
   triangles.extend(p);normals.extend([normal]*3)
  rx,ry,rz=angles;t=np.eye(4);t[:3,:3]=rotation((0,0,1),rz)@rotation((0,1,0),ry)@rotation((1,0,0),rx);t[:3,3]=at
  self.triangles(triangles,normals,mat,emit,t)
 def cylinder(self,at,radius,length,mat=STEEL,axis=(0,1,0),segments=24,emit=0,tip=None):
  axis=np.asarray(axis,float);axis/=np.linalg.norm(axis);helper=np.array((1,0,0)) if abs(axis[0])<.8 else np.array((0,0,1))
  u=np.cross(axis,helper);u/=np.linalg.norm(u);v=np.cross(axis,u);b=min(radius*.14,length*.09,.025);r2=radius if tip is None else tip
  rings=[(-length*.5,radius-b),(-length*.5+b,radius),(length*.5-b,r2),(length*.5,r2-b)];pts=[];norm=[];center=np.array(at)
  def add(p,n):pts.extend(p);norm.extend(n)
  for i in range(segments):
   aa=2*math.pi*i/segments;ab=2*math.pi*(i+1)/segments;ra=u*math.cos(aa)+v*math.sin(aa);rb=u*math.cos(ab)+v*math.sin(ab)
   for (ya,sa),(yb,sb) in zip(rings,rings[1:]):
    slope=(sa-sb)/max(yb-ya,1e-6);na=ra+axis*slope;na/=np.linalg.norm(na);nb=rb+axis*slope;nb/=np.linalg.norm(nb)
    pa=center+axis*ya+ra*sa;pb=center+axis*ya+rb*sa;pc=center+axis*yb+rb*sb;pd=center+axis*yb+ra*sb
    add([pa,pb,pc,pa,pc,pd],[na,nb,nb,na,nb,na])
   for y,r in (rings[0],rings[-1]):
    nn=axis*(-1 if y<0 else 1);pa=center+axis*y+ra*r;pb=center+axis*y+rb*r
    add([center+axis*y,pb,pa] if y<0 else [center+axis*y,pa,pb],[nn]*3)
  self.triangles(pts,norm,mat,emit)
 def tube(self,a,b,radius,mat=STEEL,segments=16):
  a=np.array(a);b=np.array(b);self.cylinder((a+b)*.5,radius,np.linalg.norm(b-a),mat,b-a,segments)
 def panel(self,at,size,mat=PAINT,bevel=.025):
  self.box(at,size,mat,bevel);x,y,z=at;w,h,d=size
  for sx in (-1,1):
   for sy in (-1,1):self.cylinder((x+sx*(w*.5-.075),y+sy*(h*.5-.075),z-d*.5-.008),.024,.018,STEEL,(0,0,1),6)

class Model:
 def __init__(self):self.parts=[]
 def part(self,name,at=(0,0,0)):
  p=Part(name,at);self.parts.append(p);return p
 def write(self,path):
  data=bytearray();views=[];accessors=[];meshes=[];nodes=[];triangles=0
  def accessor(arr,typ,component=5126,target=34962):
   arr=np.ascontiguousarray(arr,np.uint32 if component==5125 else np.float32)
   while len(data)%4:data.append(0)
   start=len(data);data.extend(arr.tobytes());vi=len(views);views.append({'buffer':0,'byteOffset':start,'byteLength':arr.nbytes,'target':target})
   item={'bufferView':vi,'componentType':component,'count':len(arr),'type':typ}
   if typ=='VEC3':item['min']=arr.min(axis=0).tolist();item['max']=arr.max(axis=0).tolist()
   accessors.append(item);return len(accessors)-1
  for part in self.parts:
   primitives=[]
   for emit,arrays in sorted(part.groups.items()):
    allv=np.concatenate(arrays);unique,indices=np.unique(allv,axis=0,return_inverse=True)
    attrs={'POSITION':accessor(unique[:,:3],'VEC3'),'NORMAL':accessor(unique[:,3:6],'VEC3'),'COLOR_0':accessor(unique[:,6:10],'VEC4'),'TEXCOORD_0':accessor(unique[:,10:12],'VEC2'),'TEXCOORD_1':accessor(unique[:,12:14],'VEC2')}
    primitives.append({'attributes':attrs,'indices':accessor(indices,'SCALAR',5125,34963),'material':emit});triangles+=len(indices)//3
   meshes.append({'name':part.name,'primitives':primitives});nodes.append({'name':part.name,'translation':part.at,'mesh':len(meshes)-1})
  mats=[{'name':'Machined PBR','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.7,'roughnessFactor':.5}}]
  for name,color in [('Optical cyan',[.25,.9,1]),('Thermal amber',[1,.25,.03])]:mats.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.15,'roughnessFactor':.3},'emissiveFactor':color})
  j={'asset':{'version':'2.0','generator':'IRON//VEIL original manufacturing tools'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':mats,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':accessors}
  js=json.dumps(j,separators=(',',':')).encode();js+=b' '*(-len(js)%4);data+=b'\0'*(-len(data)%4)
  out=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
  path.write_bytes(out);print(path.name,triangles,'triangles',len(out),'bytes');return triangles

def read_wraith():
 b=(ROOT/'docs/production-assets/wraith.glb').read_bytes();ln=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+ln]);payload=b[20+ln+8:]
 def array(index):
  a=j['accessors'][index];view=j['bufferViews'][a['bufferView']];count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
  return np.frombuffer(payload,dtype=np.float32 if a['componentType']==5126 else np.uint32,count=a['count']*count,offset=view.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,count)
 parts={}
 for node in j['nodes']:
  groups={}
  for primitive in j['meshes'][node['mesh']]['primitives']:
   a=primitive['attributes'];v=np.concatenate([array(a[x]) for x in ['POSITION','NORMAL','COLOR_0','TEXCOORD_0','TEXCOORD_1']],axis=1);groups[primitive['material']]=v[array(primitive['indices']).ravel()].copy()
  parts[node['name']]=(node,groups)
 return parts
COMMON=read_wraith()
PROFILES={
 'wraith':{'height':3.5,'width':2.55,'depth':1.8,'upper':1.12,'lower':1.12,'hip_y':1.83,'torso_y':2.67,'hips':[[-.93,.1],[.93,.1]],'leg_scale':1.0,'mount':[1.37,2.91,-.25]},
 'sentinel':{'height':3.24,'width':2.7,'depth':1.75,'upper':1.05,'lower':1.05,'hip_y':1.69,'torso_y':2.42,'hips':[[-.96,.06],[.96,.06]],'leg_scale':.938,'mount':[1.42,2.58,-.20]},
 'heavy':{'height':3.25,'width':3.65,'depth':2.45,'upper':.92,'lower':.96,'hip_y':1.39,'torso_y':2.05,'hips':[[-1.48,-.86],[1.48,-.86],[-1.48,.91],[1.48,.91]],'leg_scale':.86,'mount':[1.50,2.86,-.45]},
 'warden':{'height':5.25,'width':4.8,'depth':3.45,'upper':1.38,'lower':1.40,'hip_y':2.22,'torso_y':3.15,'hips':[[-1.78,-1.23],[1.78,-1.23],[-2.03,0],[2.03,0],[-1.78,1.23],[1.78,1.23]],'leg_scale':1.245,'mount':[2.08,3.68,-.6]},
 'scout':{'height':1.15,'width':2.2,'depth':1.5,'upper':0,'lower':0,'hip_y':0,'torso_y':.45,'hips':[],'leg_scale':1,'mount':[.68,.43,-.25]},
}
def legs(model,profile):
 s=profile['leg_scale']
 for i,(x,z) in enumerate(profile['hips']):
  side='L' if x<0 else 'R';name=side+str(i//2)
  for component,y,zoff in [('hip',profile['hip_y'],0),('thigh',profile['hip_y'],0),('shin',profile['hip_y']-profile['upper'],.5*s),('foot',.15*s,-.13*s)]:
   p=model.part(component+'_'+name,(x,y,z+zoff))
   for emit,arr in COMMON[component+'_'+side+'0'][1].items():
    v=arr.copy();v[:,:3]*=s
    if component in ('thigh','foot'):v[:,6:9]*=np.array([.92,.84,.72]) if len(profile['hips'])==4 else np.array([.92,.92,.99])
    p.groups[emit].append(v)
def reactor(model,profile,radius,amber=False):
 p=model.part('reactor',(0,profile['torso_y'],profile['depth']*.51));p.cylinder((0,0,0),radius,.22,DARK,(0,0,1),32);p.cylinder((0,0,.16),radius*.85,.16,STEEL,(0,0,1),32);p.cylinder((0,0,.26),radius*.66,.09,HOT if amber else CYAN,(0,0,1),32,2 if amber else 1)
 for a in range(12):
  angle=a*math.tau/12;p.box((math.cos(angle)*radius*.87,math.sin(angle)*radius*.87,.23),(.07,.07,.07),DARK,.01)
 p.box((0,0,.37),(radius*.25,radius*1.95,.16),DARK,.025)
def cooling(model,profile):
 w=profile['width'];d=profile['depth']
 for sx,side in [(-1,'L'),(1,'R')]:
  p=model.part('radiator_'+side,(sx*w*.38,profile['torso_y']+.10,d*.39));p.box((0,0,0),(.34,.78,.62),DARK)
  for y in np.linspace(-.34,.34,10):p.box((0,float(y),.05),(.48,.025,.68),STEEL,.005)
  p.cylinder((sx*.16,.5,0),.115,.56,STEEL);p.cylinder((sx*.16,.82,0),.14,.08,DARK);p.tube((sx*.2,-.4,-.12),(sx*.27,.40,-.12),.035,AMBER)
def platform(kind):
 cfg=PROFILES[kind];m=Model();w=cfg['width'];d=cfg['depth'];y=cfg['torso_y']
 paint=(.43,.46,.43,.66,.62) if kind=='sentinel' else ((.37,.31,.23,.67,.61) if kind=='heavy' else (.30,.32,.36,.57,.75))
 p=m.part('torso',(0,y,0));p.box((0,-.08,0),(w*.77,.68 if kind=='heavy' else 1.00,d),DARK,.10);p.box((0,.24,.05),(w*.67,.37,d*.98),paint,.09);p.panel((0,-.17,-d*.51),(w*.38,.5,.16),paint);p.box((0,-.42,.03),(w*.60,.22,d*1.05),STEEL,.07)
 for sx in (-1,1):
  a=m.part('armor_front_'+('L' if sx<0 else 'R'),(sx*w*.24,y+.07,-d*.49));a.panel((0,0,0),(w*.38,.79,.20),paint,.06);a.box((0,.08,-.12),(w*.31,.13,.035),AMBER if kind!='warden' else WHITE,.008)
  for xx in (-.1,.1):a.box((xx,-.13,-.13),(.07,.26,.04),DARK,.01)
 p=m.part('sensor',(0,y+.13,-d*.63));p.box((0,0,0),(.72 if kind!='warden' else 1.08,.23,.24),DARK,.04)
 for sx in (-1,1):
  p.cylinder((sx*.22,0,-.14),.068,.06,CYAN if kind=='sentinel' else HOT,(0,0,1),24,1 if kind=='sentinel' else 2);p.box((sx*.2,.145,0),(.26,.052,.30),STEEL,.01)
 p=m.part('pelvis',(0,cfg['hip_y'],.10));p.box((0,0,0),(w*.62,.32,d*.82),DARK,.05);p.cylinder((0,.22,0),w*.24,.24,STEEL);p.cylinder((0,.37,0),w*.2,.1,AMBER)
 for sx,side in [(-1,'L'),(1,'R')]:
  p=m.part('hardpoint_'+side,(sx*w*.48,y+.18,-.12));p.cylinder((0,0,0),.23,.23,STEEL,(1,0,0),24);p.box((0,0,-.15),(.31,.32,.65),DARK);p.panel((sx*.03,.18,-.05),(.43,.14,.57),paint)
 p=m.part('ammo',(-w*.42,y,.25));p.cylinder((0,0,0),.31,.70,DARK,(0,0,1))
 for zz in np.linspace(-.3,.3,6):p.cylinder((0,0,float(zz)),.335,.035,STEEL,(0,0,1))
 p.cylinder((0,0,-.38),.20,.11,AMBER,(0,0,1));cooling(m,cfg);reactor(m,cfg,.43 if kind!='warden' else .67,kind!='sentinel');legs(m,cfg)
 if kind=='sentinel':
  p=m.part('spine',(0,y+.66,.28));p.box((0,0,0),(.28,.32,.82),STEEL);p.tube((-.18,.05,.16),(-.25,.63,.16),.026,DARK);p.box((0,.19,-.20),(.24,.085,.18),CYAN,emit=1)
 elif kind=='heavy':
  p=m.part('siege_mount',(0,y+.73,.23));p.cylinder((0,0,0),.61,.25,DARK);p.box((0,.15,0),(1.59,.54,1.38),paint,.10)
  for sx in (-1,1):
   p.cylinder((sx*.43,.24,-.93),.18,1.32,STEEL,(0,0,1),24);p.cylinder((sx*.43,.24,-1.66),.235,.23,DARK,(0,0,1),24);p.cylinder((sx*.43,.24,-1.80),.115,.03,RUBBER,(0,0,1),24)
  for i in range(7):p.box((0,.47,-.5+i*.16),(1.38,.09,.055),DARK,.01)
 else:
  p=m.part('spine',(0,y+.91,.35));p.cylinder((0,0,0),.79,.55,DARK,segments=32);p.cylinder((0,.34,0),.66,.11,HOT,segments=32,emit=2)
  for i in range(8):
   a=i*math.tau/8;p.box((math.sin(a)*.83,.13,math.cos(a)*.83),(.19,.88,.35),STEEL,.03,angles=(0,a,0))
  for sx,side in [(-1,'L'),(1,'R')]:
   p=m.part('missile_'+side,(sx*1.65,y+.75,.31));p.box((0,0,0),(.88,.78,1.14),paint,.08);p.panel((0,0,-.60),(.91,.8,.12),DARK)
   for xx in (-.22,.22):
    for yy in (-.2,.2):p.cylinder((xx,yy,-.69),.145,.06,STEEL,(0,0,1),20);p.cylinder((xx,yy,-.72),.096,.025,RUBBER,(0,0,1),20)
   p.box((0,.45,-.10),(.66,.075,.83),AMBER,.015)
 return m
def scout():
 m=Model();p=m.part('torso',(0,.45,0));p.box((0,0,0),(1.07,.40,.89),DARK,.10);p.panel((0,.19,-.04),(.83,.19,.87),PAINT,.05)
 for sx,side in [(-1,'L'),(1,'R')]:
  p=m.part('lift_'+side,(sx*.77,.39,.09));p.box((0,0,0),(.50,.16,.98),STEEL)
  for z in (-.29,.29):
   p.cylinder((0,0,z),.30,.27,DARK,segments=32);p.cylinder((0,.16,z),.22,.025,STEEL,segments=24)
   for i in range(5):p.box((0,.19,z),(.035,.025,.38),RUBBER,.005,angles=(0,i*math.tau/5,0))
   p.cylinder((0,-.15,z),.185,.035,CYAN,segments=24,emit=1)
 p=m.part('sensor',(0,.46,-.52));p.box((0,0,0),(.56,.22,.20),DARK);p.cylinder((0,0,-.12),.086,.03,HOT,(0,0,1),24,2)
 p=m.part('reactor',(0,.50,.46));p.box((0,0,0),(.57,.19,.09),CYAN,emit=1);p=m.part('hardpoint_R',(.57,.43,-.2));p.box((0,0,0),(.25,.22,.45),PAINT);return m
def weapon(kind):
 m=Model();p=m.part('receiver');p.box((0,0,.02),(.43,.48,.86),DARK,.07);p.panel((0,.23,.06),(.5,.17,.92),PAINT)
 for sx in (-1,1):p.panel((sx*.26,0,.12),(.085,.35,.58),STEEL);p.cylinder((sx*.28,-.03,.25),.09,.065,STEEL,(1,0,0))
 p=m.part('barrel',(0,0,-.35))
 if kind=='autocannon':
  p.cylinder((0,0,-.07),.24,.25,STEEL,(0,0,1))
  for i in range(6):
   a=i*math.tau/6;xx=math.cos(a)*.12;yy=math.sin(a)*.12;p.cylinder((xx,yy,-.71),.067,1.28,STEEL,(0,0,1));p.cylinder((xx,yy,-1.37),.071,.12,DARK,(0,0,1));p.cylinder((xx,yy,-1.44),.038,.027,RUBBER,(0,0,1))
  for z in (-.33,-1.14):p.cylinder((0,0,z),.235,.09,DARK,(0,0,1))
 elif kind=='breacher':
  for sx in (-1,1):p.cylinder((sx*.12,0,-.55),.118,1.10,STEEL,(0,0,1));p.box((sx*.12,0,-1.12),(.25,.24,.21),DARK);p.cylinder((sx*.12,0,-1.24),.08,.03,RUBBER,(0,0,1))
  for z in np.linspace(-.13,-.88,6):p.box((0,.18,float(z)),(.62,.08,.08),PAINT,.012)
 else:
  for sx in (-1,1):
   p.box((sx*.19,0,-.77),(.17,.27,1.54),STEEL);p.box((sx*.09,0,-.72),(.045,.12,1.31),CYAN,.008,emit=1)
   for z in np.linspace(-.17,-1.32,7):p.box((sx*.25,0,float(z)),(.16,.35,.09),DARK,.013)
  p.box((0,0,-1.58),(.64,.34,.14),PAINT);p.box((0,0,-1.66),(.19,.13,.035),CYAN,.008,emit=1)
 p=m.part('breech',(0,0,.47));p.box((0,0,0),(.29,.31,.19),STEEL)
 p=m.part('magazine',(-.28,-.17,.14));p.cylinder((0,0,0),.23,.46,DARK,(0,0,1))
 for z in np.linspace(-.20,.2,6):p.cylinder((0,0,float(z)),.25,.026,STEEL,(0,0,1))
 p=m.part('heat_sink',(0,.38,-.12))
 for z in np.linspace(-.4,.4,9):p.box((0,0,float(z)),(.38,.13,.025),DARK,.005)
 return m
def hangar():
 m=Model()
 for row in range(8):
  p=m.part('deck_'+str(row))
  for col in range(10):
   x=-16.2+col*3.6;z=-14+row*4;p.box((x,-.16,z),(3.53,.30,3.92),(.13,.16,.17,.66,.71),.025)
   for zz in (-1.73,1.73):
    for xx in (-1.5,1.5):p.cylinder((x+xx,.008,z+zz),.055,.024,STEEL,segments=6)
   if col in (1,8):
    p.box((x,.009,z),(1.0,.025,3.79),DARK,.008)
    for dz in np.linspace(-1.8,1.8,18):p.box((x,.026,z+float(dz)),(.85,.027,.06),STEEL,.005)
 p=m.part('service_plinth');p.cylinder((0,.09,0),3.65,.19,DARK,segments=16);p.cylinder((0,.20,0),3.41,.12,STEEL,segments=16);p.cylinder((0,.265,0),3.17,.035,(.16,.2,.22,.67,.74),segments=16)
 for i in range(48):
  a=i*math.tau/48;p.box((math.sin(a)*3.46,.274,math.cos(a)*3.46),(.28,.035,.16),AMBER,.005,angles=(0,a,0))
 for sx in (-1,1):
  p=m.part('wall_'+str(sx))
  for z in range(-16,17,4):
   p.box((sx*18,6,z),(.35,12,3.97),(.18,.23,.25,.78,.50),.04);p.box((sx*17.79,4,z),(.14,5.9,3.53),DARK,.02)
   for h in (1.3,6.6,10.8):p.box((sx*17.68,h,z),(.12,.14,3.56),STEEL,.018)
   for xx in (sx*17.47,sx*17.90):p.box((xx,6,z+1.92),(.17,11.9,.56),STEEL,.018)
   p.box((sx*17.68,6,z+1.92),(.44,11.9,.13),DARK,.018);p.tube((sx*17.50,8,z-1.50),(sx*17.50,11.2,z+1.50),.075,STEEL);p.box((sx*17.48,10.5,z),(.05,.18,2.95),CYAN,.01,emit=1)
  for h in (1.1,1.5,9.3,9.8):
   p.tube((sx*16.95,h,-16),(sx*16.95,h,16),.09 if h<2 else .16,STEEL)
   for z in range(-14,16,4):p.cylinder((sx*16.95,h,z),.145 if h<2 else .215,.07,AMBER,(0,0,1),24)
  p.box((sx*13.7,4.9,0),(6.2,.27,28),DARK,.03)
  for z in range(-12,13,2):p.tube((sx*10.65,5,z),(sx*10.65,6.1,z),.035,AMBER)
  p.tube((sx*10.65,6.1,-14),(sx*10.65,6.1,14),.05,AMBER)
  for z in range(-12,13,6):
   p=m.part('cabinet_%s_%s'%(sx,z));p.panel((sx*14,1.25,z),(2.25,2.5,1.35),(.25,.32,.32,.69,.56))
   for y in np.linspace(.8,1.5,6):p.box((sx*14,y,z-.7),(1.65,.065,.025),DARK,.008)
   p.box((sx*14,2.18,z-.71),(.32,.16,.045),CYAN,emit=1)
 p=m.part('bulkhead');p.box((0,6,16.3),(36,12,.4),DARK,.06)
 for x in range(-15,16,3):p.panel((x,5.2,16.01),(2.90,9.6,.20),(.24,.29,.29,.75,.49))
 for sx in (-1,1):
  p.box((sx*3.12,3.53,15.68),(6.10,6.86,.55),(.14,.20,.23,.48,.80),.08)
  for x in np.linspace(sx*3.1-2.7,sx*3.1+2.7,7):p.box((float(x),3.52,15.35),(.13,6.50,.11),STEEL,.02)
  p.box((sx*.20,3.5,15.24),(.08,6.25,.09),HOT,.01,emit=2)
 p.box((0,7.12,15.32),(13.85,.20,.19),CYAN,.015,emit=1);p=m.part('overhead')
 for z in range(-14,17,5):
  p.box((0,12,z),(36,.24,4.83),(.055,.080,.10,.78,.47),.025)
  for y in (10.97,11.55):p.box((0,y,z),(35.6,.18,.78),STEEL,.025)
  p.box((0,11.27,z),(35.5,.46,.13),DARK,.025)
  for x in range(-14,15,7):p.box((x,10.84,z),(4.15,.12,.70),DARK);p.box((x,10.75,z),(3.85,.05,.36),WHITE,.01,emit=1)
 for sx in (-1,1):p.box((sx*5.7,9.55,1.5),(.75,.55,28),STEEL,.035);p.box((sx*5.7,9.9,1.5),(.38,.12,28),AMBER,.02)
 p=m.part('bridge_crane');p.box((0,9.3,3.5),(13.8,.65,1.3),AMBER,.06);p.box((0,9.03,3.5),(13.1,.13,1.5),DARK);p.box((2.3,8.75,3.5),(2.3,.45,2.0),STEEL)
 for x in (1.65,2.95):p.tube((x,8.6,3.5),(x,5.5,3.5),.028,DARK)
 p.cylinder((2.3,5.3,3.5),.23,.4,AMBER)
 for sx in (-1,1):
  p=m.part('service_arm_'+('L' if sx<0 else 'R'),(sx*4.8,.3,0));p.box((0,1.58,0),(.70,3.1,.70),DARK);p.panel((sx*.12,1.55,-.35),(.75,2.7,.18),AMBER);p.cylinder((0,2.9,0),.37,.90,STEEL,(0,0,1));p.tube((0,2.8,0),(-sx*1.40,3.30,0),.16,STEEL);p.tube((0,2.31,.22),(-sx*1.24,2.99,.22),.08,DARK);p.tube((-sx*.4,2.55,.22),(-sx*1.24,2.99,.22),.04,STEEL);p.box((-sx*1.55,3.23,0),(.44,.60,.50),DARK);p.box((-sx*1.83,3.23,-.04),(.25,.19,.22),CYAN,.02,emit=1)
 for z in (-9,-5,5,9):
  p=m.part('service_mark_'+str(z))
  for x in np.linspace(-3.5,3.5,12):p.box((float(x),.023,z),(.32,.03,.20),AMBER,.005,angles=(0,-.6,0))
 return m
def main():
 ASSETS.mkdir(exist_ok=True);shutil.copyfile(ROOT/'docs/production-assets/wraith.glb',ASSETS/'wraith.glb');report={}
 for kind in ('sentinel','heavy','warden'):report[kind]=platform(kind).write(ASSETS/(kind+'.glb'))
 report['scout']=scout().write(ASSETS/'scout.glb')
 for kind in ('autocannon','breacher','coil_lance'):report[kind]=weapon(kind).write(ASSETS/(kind+'.glb'))
 report['hangar']=hangar().write(ASSETS/'hangar.glb')
 (ASSETS/'mech_profiles.json').write_text(json.dumps(PROFILES,indent=2)+'\n');(ASSETS/'machine_asset_report.json').write_text(json.dumps({'wraith':70924,**report},indent=2)+'\n')
if __name__=='__main__':main()
