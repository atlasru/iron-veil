#!/usr/bin/env python3
"""Tileable machining detail: fine grain, scratches and worn coating."""
from pathlib import Path
from io import BytesIO
import numpy as np
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1];rng=np.random.default_rng(9117);size=1024
grain=rng.normal(0,6,(size,size))
low=np.asarray(Image.fromarray(rng.integers(90,165,(64,64),dtype=np.uint8)).resize((size,size),Image.Resampling.BICUBIC),float)
red=np.clip(135+(low-127)*.25+grain,0,255).astype(np.uint8)
rough=np.clip(132+(low-127)*.65+grain*.7,0,255).astype(np.uint8)
wear=Image.new('L',(size,size));d=ImageDraw.Draw(wear)
for i in range(180):
 x,y=rng.integers(0,size,2);length=int(rng.integers(2,68));shade=int(rng.integers(40,200))
 d.line((int(x),int(y),int(x+length),int(y+rng.integers(-3,4))),fill=shade,width=1 if i%5 else 2)
for i in range(90):
 x,y=rng.integers(0,size,2);d.ellipse((int(x),int(y),int(x+3),int(y+2)),fill=90)
image=Image.fromarray(np.dstack([red,rough,np.asarray(wear)]))
buffer=BytesIO();image.save(buffer,format='PNG');(root/'assets/machine_detail.png').write_bytes(buffer.getvalue())
