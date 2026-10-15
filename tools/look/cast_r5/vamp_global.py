import numpy as np
from px import *
import os
O = os.environ.get('CAST_R3_WORK', '.').rstrip('/') + '/'
def vamp_global(path=O+'orig/vampyr_look_heartland.png'):
    s=Sheet(path,'vampyr')
    s.remap(None,{'r':'s','Q':'r'})     # cape one step up the red ramp; never soot in it (critic V1)
    return s
if __name__=='__main__':
    s=vamp_global(); s.save(O+'vamp_g.png')
