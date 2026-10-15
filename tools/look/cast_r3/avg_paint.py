"""average_m round 3: hand edits only (shading stays in skin_neutral; no alpha change, so the normal strip stays valid)."""
from px import *
from draw import line
import os
O = os.environ.get('CAST_R3_WORK', '.').rstrip('/') + '/'
def front_edge(s, f, y):
    xs = [x for x in range(176) if s.get(f, x, y) != '.']
    return max(xs) if xs else None
def S(s):
    # upper arms: carry the existing arm/torso shadow line up to the armpit
    line(s, 0, (75, 70), (75, 76), 'A'); line(s, 0, (99, 70), (99, 77), 'A')
def E(s):
    f = 2
    # the arm hangs over the side: one shadow line on its back edge, one terminator inside it
    for y in range(84, 118):
        xr = front_edge(s, f, y)
        s.put(f, xr - 7, y, 'A')
        for x in range(xr - 6, xr - 3): s.put(f, x, y, 'C')
        for x in range(xr - 3, xr): s.put(f, x, y, 'B')
    # thigh banding (C B C B A C) clumped into a lit and a shadow plane
    for y in range(121, 126):
        xr = front_edge(s, f, y)
        for x in range(81, xr):
            s.put(f, x, y, 'C' if x < 87 else ('B' if x < xr - 1 else 'A'))
def NW(s):
    f = 5
    # mid-back slab: shade the back by plane, lit left of the spine, shadow right
    for y in range(72, 93):
        for x in range(82, 98):
            if s.get(f, x, y) in 'AB': s.put(f, x, y, 'C' if x < 89 else 'B')
    line(s, f, (79, 84), (77, 104), 'A'); line(s, f, (77, 104), (77, 117), 'A')
def NE(s):
    f = 3
    # mid-back slab: part of the lit plane; the shadow plane is the right edge
    for y in range(79, 94):
        for x in range(86, 98):
            if s.get(f, x, y) == 'B': s.put(f, x, y, 'C')
def avg():
    s = Sheet(O + 'orig/average_m_body_rest.png', 'avg')
    S(s); E(s); NW(s); NE(s)
    return s
if __name__ == '__main__':
    s = avg(); s.save(O + 'avg_p.png')
    print(s.dump(3, 70, 56, 108, 110))
