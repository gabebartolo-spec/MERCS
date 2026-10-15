import json, os
from pathlib import Path
R = Path(__file__).resolve().parents[3].as_posix() + '/'
def load():
    pal={}
    for f in ['assets/palette/core.json','assets/palette/biomes/heartland.json']:
        d=json.load(open(R+f))
        for r in d['ramps']:
            for i,c in enumerate(r['colours']):
                pal[f"{r['name']}_{i}"]=tuple(int(c[k:k+2],16) for k in (1,3,5))
    return pal
def lab(c):
    def f(u):
        u/=255; return u/12.92 if u<=0.04045 else ((u+0.055)/1.055)**2.4
    r,g,b=map(f,c)
    X=(0.4124*r+0.3576*g+0.1805*b)/0.95047;Y=0.2126*r+0.7152*g+0.0722*b;Z=(0.0193*r+0.1192*g+0.9505*b)/1.08883
    g_=lambda t: t**(1/3) if t>0.008856 else 7.787*t+16/116
    return (116*g_(Y)-16,500*(g_(X)-g_(Y)),200*(g_(Y)-g_(Z)))
def dE(a,b):
    A,B=lab(a),lab(b); return sum((x-y)**2 for x,y in zip(A,B))**.5
