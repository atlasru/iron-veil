#!/usr/bin/env python3
"""Original reproducible hard-surface art and sound. No downloaded assets.
Requires numpy, Pillow, scipy. Uses glTF 2.0 PBR materials and articulated nodes.
"""
from pathlib import Path
import json, math, struct, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial import ConvexHull

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets"
OUT.mkdir(exist_ok=True)
RNG = np.random.default_rng(7119)

def textures():
    n = 512
    for name, base in [('armor',(108,121,113)),('metal',(66,80,86)),('concrete',(106,114,112)),('floor',(65,76,78))]:
        noise = RNG.normal(0, 5, (n,n,1))
        a = np.clip(np.array(base)[None,None,:]+noise,0,255).astype('uint8')
        im = Image.fromarray(a)
        d = ImageDraw.Draw(im)
        if name in ['armor','metal','floor']:
            for x in range(0,n,128):
                d.line((x,0,x,n), fill=(30,39,40),width=3)
                d.line((0,x,n,x), fill=(30,39,40),width=3)
                d.line((x+4,0,x+4,n),fill=(121,128,121),width=1)
                for y in range(10,n,128):
                    d.ellipse((x+10,y,x+15,y+5),fill=(139,146,136))
            for i in range(300):
                x,y=RNG.integers(0,n,2); ln=int(RNG.integers(2,23))
                d.line((x,y,x+ln,y+int(RNG.integers(-2,3))),fill=(143,147,135),width=1)
        else:
            for i in range(400):
                x,y=RNG.integers(0,n,2)
                d.point((x,y),fill=(47,56,57))
        if name=='floor':
            for y in range(5,n,12):
                for x in range(4,n,24): d.line((x,y,x+9,y+4), fill=(104,117,116),width=2)
        im.save(OUT/(name+'.png'))
        gray=np.asarray(im.convert('L'),dtype=float)/255
        gy,gx=np.gradient(gray)
        normal=np.stack([-gx*4,-gy*4,np.ones_like(gray)],axis=-1)
        normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        Image.fromarray(((normal*.5+.5)*255).astype('uint8')).save(OUT/(name+'_normal.png'))
    im=Image.new('RGBA',(512,512),(0,0,0,0));d=ImageDraw.Draw(im)
    d.ellipse((60,90,460,420),fill=(0,0,0,140))
    im=im.filter(ImageFilter.GaussianBlur(45));im.save(OUT/'scorch.png')
    im=Image.new('RGBA',(256,256));d=ImageDraw.Draw(im)
    for i in range(127,0,-1):
        alpha=int(80*(1-i/128)**2)
        d.ellipse((128-i,128-i,128+i,128+i),fill=(196,202,191,alpha))
    im.save(OUT/'smoke.png')

class Builder:
    def __init__(self): self.parts=[]
    def box(self,pos,size,mat=0,bevel=.035,rot=0):
        sx,sy,sz=np.array(size)/2; b=min(bevel,sx*.4,sy*.4,sz*.4)
        pts=[]
        for signs in [(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]:
            for axis in range(3):
                v=np.array([sx-b,sy-b,sz-b]);v[axis]+=b
                pts.append(v*np.array(signs))
        pts=np.unique(np.array(pts),axis=0)
        hull=ConvexHull(pts)
        tris=[]
        for ids,eq in zip(hull.simplices,hull.equations):
            t=pts[ids]
            if np.dot(np.cross(t[1]-t[0],t[2]-t[0]),eq[:3])<0: t=t[[0,2,1]]
            tris.append(t)
        self.add(tris,pos,mat,rot)
    def cylinder(self,pos,radius,length,mat=1,segments=12,axis='y'):
        tris=[]
        for i in range(segments):
            a=i*math.tau/segments;b=(i+1)*math.tau/segments
            p=np.array([[math.cos(a)*radius,-length/2,math.sin(a)*radius],[math.cos(b)*radius,-length/2,math.sin(b)*radius],[math.cos(a)*radius,length/2,math.sin(a)*radius],[math.cos(b)*radius,length/2,math.sin(b)*radius]])
            tris += [p[[0,2,1]],p[[1,2,3]],np.array([[0,-length/2,0],p[0],p[1]]),np.array([[0,length/2,0],p[3],p[2]])]
        if axis=='z': tris=[t[:,[0,2,1]]*np.array([1,1,-1]) for t in tris]
        if axis=='x': tris=[t[:,[1,0,2]]*np.array([-1,1,1]) for t in tris]
        self.add(tris,pos,mat)
    def add(self,tris,pos,mat,rot=0):
        c,s=math.cos(rot),math.sin(rot);m=np.array([[c,-s,0],[s,c,0],[0,0,1]])
        self.parts.append((mat,np.array(tris)@m.T+np.array(pos)))

MATERIALS=[
 {'name':'Field ceramic','pbrMetallicRoughness':{'baseColorFactor':[.66,.73,.63,1],'metallicFactor':.72,'roughnessFactor':.49}},
 {'name':'Graphite titanium','pbrMetallicRoughness':{'baseColorFactor':[.08,.13,.15,1],'metallicFactor':.82,'roughnessFactor':.36}},
 {'name':'Copper hydraulics','pbrMetallicRoughness':{'baseColorFactor':[.72,.38,.12,1],'metallicFactor':.84,'roughnessFactor':.31}},
 {'name':'Signal lime','pbrMetallicRoughness':{'baseColorFactor':[.58,.93,.28,1],'metallicFactor':.25,'roughnessFactor':.27},'emissiveFactor':[.55,1,.22]},
 {'name':'Ballistic steel','pbrMetallicRoughness':{'baseColorFactor':[.17,.22,.23,1],'metallicFactor':.9,'roughnessFactor':.38}},
 {'name':'Batched armor','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.75,'roughnessFactor':.46}},
]

def glb(path,nodes):
    data=bytearray();views=[];accessors=[];meshes=[];gnodes=[]
    def array(a,typ):
        a=np.asarray(a,dtype=np.float32)
        while len(data)%4: data.extend(b'\0')
        offset=len(data);data.extend(a.tobytes())
        views.append({'buffer':0,'byteOffset':offset,'byteLength':a.nbytes})
        accessors.append({'bufferView':len(views)-1,'componentType':5126,'count':len(a),'type':typ,'min':a.min(axis=0).tolist(),'max':a.max(axis=0).tolist()})
        return len(accessors)-1
    for name,builder,pos in nodes:
        prims=[]
        # Vertex colors batch all opaque mechanical materials into one surface.
        # Emitters retain a separate surface for real PBR emission.
        for emitter in [False,True]:
            parts=[(m,t) for m,t in builder.parts if (m==3)==emitter]
            if not parts: continue
            tris=np.concatenate([t for m,t in parts])
            normals=np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]);normals/=np.linalg.norm(normals,axis=1,keepdims=True)
            verts=tris.reshape(-1,3);normals=np.repeat(normals,3,axis=0)
            uv=verts[:,[0,1]]*.7
            attrs={'POSITION':array(verts,'VEC3'),'NORMAL':array(normals,'VEC3'),'TEXCOORD_0':array(uv,'VEC2')}
            if not emitter:
                colors=np.concatenate([np.tile(MATERIALS[m]['pbrMetallicRoughness']['baseColorFactor'],(len(t)*3,1)) for m,t in parts])
                attrs['COLOR_0']=array(colors,'VEC4')
            prims.append({'attributes':attrs,'material':3 if emitter else 5})
        meshes.append({'name':name,'primitives':prims})
        gnodes.append({'name':name,'mesh':len(meshes)-1,'translation':pos})
    doc={'asset':{'version':'2.0','generator':'IRON//VEIL original procedural art'},'scene':0,'scenes':[{'nodes':list(range(len(gnodes)))}],'nodes':gnodes,'meshes':meshes,'materials':MATERIALS,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}]}
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
    data+=b'\0'*((-len(data))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(data))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(data),0x004e4942)+data)

def robot():
    nodes=[]
    b=Builder();b.box((0,0,0),(.93,.79,.58),1,.1);b.box((0,.08,-.29),(.97,.57,.12),0,.07)
    for x in [-.34,.34]:
        b.box((x,.13,-.37),(.26,.48,.11),0,.04,rot=x*.32)
        b.cylinder((x,.3,-.44),.033,.024,2,axis='z')
        b.box((x,.08,.32),(.18,.49,.13),1)
    b.box((0,-.03,-.4),(.18,.26,.05),3,.012)
    for y in [-.19,-.11,-.03,.05]: b.box((0,y,.33),(.4,.025,.065),2,.008)
    nodes.append(('torso',b,[0,1.83,0]))
    b=Builder();b.box((0,0,0),(.45,.34,.43),1,.06);b.box((0,.045,-.15),(.46,.22,.21),0,.06);b.box((0,.02,-.264),(.36,.053,.022),3,.01)
    b.box((0,-.12,-.13),(.31,.085,.17),4);b.cylinder((.24,.04,.04),.075,.04,2,axis='x');b.cylinder((0,-.2,0),.11,.13,1)
    nodes.append(('head',b,[0,2.42,-.03]))
    b=Builder();b.box((0,0,0),(.64,.27,.48),1,.05)
    for x in [-.23,.23]: b.box((x,-.12,-.18),(.21,.32,.16),0,.04,rot=-x*.45)
    nodes.append(('pelvis',b,[0,1.28,0]))
    for side in ['L','R']:
        sign=-1 if side=='L' else 1
        b=Builder();b.cylinder((0,-.03,0),.16,.23,2,axis='x');b.box((0,-.21,0),(.33,.43,.35),1,.05);b.box((sign*.045,-.2,-.08),(.36,.39,.35),0,.08);b.cylinder((0,-.49,0),.14,.28,1,axis='x');b.box((0,-.44,-.13),(.25,.15,.17),4)
        nodes.append(('thigh_'+side,b,[sign*.3,1.24,0]))
        b=Builder();b.box((0,-.22,0),(.21,.46,.23),1);b.box((0,-.22,-.12),(.27,.41,.18),0,.05);b.cylinder((.13,-.22,.07),.034,.37,2);b.cylinder((-.13,-.22,.07),.034,.37,2);b.box((0,-.39,-.22),(.16,.06,.02),3,.006)
        nodes.append(('shin_'+side,b,[sign*.3,.73,0]))
        b=Builder();b.box((0,.06,-.09),(.32,.17,.53),1,.035);b.box((0,.13,-.19),(.3,.12,.35),0,.02)
        for z in [-.29,-.13,.03]: b.box((0,-.035,z),(.34,.04,.06),4,.008)
        nodes.append(('foot_'+side,b,[sign*.3,.1,0]))
        b=Builder();b.cylinder((0,-.04,0),.16,.33,2,axis='x');b.box((sign*.05,-.08,-.02),(.39,.29,.38),0,.055);b.box((0,-.28,0),(.23,.3,.24),1);b.cylinder((0,-.48,0),.12,.25,2,axis='x')
        nodes.append(('upper_arm_'+side,b,[sign*.63,2.08,0]))
        b=Builder();b.box((0,-.22,0),(.23,.39,.25),1);b.box((0,-.17,-.11),(.25,.32,.13),0);b.box((0,-.17,-.19),(.09,.17,.025),3,.008);b.box((0,-.43,0),(.19,.15,.22),4);b.cylinder((.09,-.2,.12),.027,.32,2)
        nodes.append(('forearm_'+side,b,[sign*.63,1.58,0]))
    glb(OUT/'wraith.glb',nodes)

def weapons():
    for i,name in enumerate(['autocannon','breacher','coil_lance']):
        b=Builder();b.box((0,0,0),(.22,.22,.75),1);b.box((0,.1,-.11),(.26,.12,.52),4)
        b.box((0,-.17,.17),(.12,.23,.14),1,rot=-.18);b.box((0,-.17,-.06),(.13,.22,.24),4,rot=.12)
        b.box((0,.09,.3),(.18,.2,.24),0);b.cylinder((0,0,-.61),.065,.42,4,axis='z')
        if i==0:
            for z in [-.29,-.37,-.45]: b.box((0,.09,z),(.24,.025,.025),2,.005)
        if i==1:
            for x in [-.065,.065]: b.cylinder((x,0,-.49),.065,.5,4,axis='z')
            b.box((0,0,-.32),(.29,.27,.26),0)
        if i==2:
            for x in [-.13,.13]:
                b.box((x,.01,-.42),(.09,.15,.66),0)
                b.box((x,.11,-.44),(.04,.035,.57),3,.006)
            for z in [-.62,-.44,-.26]:b.cylinder((0,0,z),.14,.025,2,axis='z')
        glb(OUT/(name+'.glb'),[('weapon',b,[0,0,0])])

def sounds():
    rate=22050
    for name,duration in [('autocannon',.3),('breacher',.55),('coil',.7),('step',.22),('reload',.8),('impact',.19),('explosion',1.5),('servo',.3),('ambient',4.),('ui',.12),('charge',.65)]:
        t=np.arange(int(rate*duration))/rate;noise=RNG.uniform(-1,1,len(t));env=np.exp(-t/(duration*.24))
        if name=='autocannon': x=(noise*.58+np.sin(t*math.tau*78)*.6)*env
        elif name=='breacher': x=(noise*.7+np.sin(t*math.tau*(48-12*t))*.7)*env
        elif name=='coil': x=(np.sin(t*math.tau*(1200-700*t))*.5+noise*.2)*env
        elif name=='charge': x=np.sin(t*math.tau*(160+550*t))*np.minimum(t*2,1)*.35
        elif name=='step':x=(noise*.32+np.sin(t*math.tau*65)*.6)*env
        elif name=='reload':x=noise*.2*(np.exp(-abs(t-.1)*80)+np.exp(-abs(t-.5)*75)) + np.sin(t*math.tau*280)*.08*np.sin(t*math.pi/duration)**2
        elif name=='impact':x=(noise*.3+np.sin(t*math.tau*2200)*.2)*env
        elif name=='explosion':x=(np.convolve(noise,np.ones(8)/8,'same')+np.sin(t*math.tau*39)*.45)*env
        elif name=='ambient':x=(np.sin(t*math.tau*45)+np.sin(t*math.tau*91)*.3+noise*.2)*.06
        elif name=='ui':x=np.sin(t*math.tau*800)*env*.25
        else:x=np.sin(t*math.tau*(170+200*t))*env*.13
        x=np.tanh(x)*.78
        with wave.open(str(OUT/(name+'.wav')),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes((x*32767).astype('<i2').tobytes())

if __name__=='__main__':
    textures();robot();weapons();sounds()
    print('Original PBR textures, Wraith articulated model, three weapons and 11 sounds generated.')
