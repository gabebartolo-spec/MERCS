import numpy as np
from px import *
import os
O = os.environ.get('CAST_R3_WORK', '.').rstrip('/') + '/'
MAIL=8
OLD_ORC=[(40,48,22),(66,74,38),(94,102,55),(124,131,73),(155,161,92)]   # skin_orc before the grey-olive ruling
def old_to_new(a):
    for i,c in enumerate(OLD_ORC):
        m=(a[...,:3]==c).all(-1)&(a[...,3]>0); a[m,:3]=P[f'skin_orc_{i}']
def orc_global():
    s=Sheet(O+'orig/orc_look_heartland.png','orc')
    old_to_new(s.a)
    L=np.load(O+'orc_matid.npy')
    notmail=lambda f,x,y: L[y,f*176+x]!=MAIL
    s.remap(None,{'k':'m','q':'n','Q':'o'},where=notmail)
    s.remap(None,{'A':'C','B':'C','C':'C','D':'D','E':'D'})
    return s
if __name__=='__main__':
    s=orc_global(); s.save(O+'orc_g.png')
    import sys
    for f in map(int,sys.argv[1:]):
        import numpy as np
        a=s.a[:,f*176:(f+1)*176,3]; ys,xs=np.nonzero(a)
        print(f'FRAME {f}'); print(s.dump(f,xs.min()-1,ys.min()-1,xs.max()+2,ys.max()+2))
