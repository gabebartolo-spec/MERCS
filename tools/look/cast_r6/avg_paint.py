"""average_m rounds 3-4: hand edits only (shading stays in skin_neutral). Round 4 cuts a 1-px gap between the
hand and the hip on SE and SW (the normal strip takes the same alpha), carries the arm line down the forearm,
and shades the E arm and thigh by planes (one line, one irregular terminator)."""
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
    # the arm hangs over the side: ONE line on its back edge, down to the hand; its front is a 1-2 px shadow
    FRONT = [1, 1, 2, 2, 1, 2, 2, 2, 1, 1, 2, 1, 1, 2, 2, 1, 2, 2, 1, 1, 1, 2, 2, 1, 2, 1, 1, 2, 2, 1]
    for i, y in enumerate(range(84, 114)):
        xr = front_edge(s, f, y)
        s.put(f, xr - 7, y, 'A')
        w = FRONT[i]
        for x in range(xr - 6, xr): s.put(f, x, y, 'C' if x < xr - w else 'B')
    # below the hand the thigh is two planes: lit (key side) and shadow, one irregular terminator, no lines
    TERM = [3, 4, 4, 5, 5, 4, 3, 3, 4, 5, 4, 4]
    for i, y in enumerate(range(114, 126)):
        xr = front_edge(s, f, y)
        xs = [x for x in range(176) if s.get(f, x, y) != '.']
        for x in range(min(xs) + 1, xr): s.put(f, x, y, 'C' if x < xr - TERM[i] else 'B')
def hand_gap(s, f, line_pts, gap_x, rows):
    """Arm separation line in skin 0 down the inside of the forearm, then a 1-px background gap where the
    hand leaves the hip; the outline is redone so both sides take their edge."""
    for p0, p1 in zip(line_pts, line_pts[1:]): line(s, f, p0, p1, 'A')
    for y in rows: s.put(f, gap_x(y), y, '.')
    s.outline(f)
def SE(s):
    hand_gap(s, 1, [(80, 80), (80, 93), (79, 94), (79, 100)], lambda y: 78, range(101, 111))
def SW(s):
    hand_gap(s, 7, [(93, 84), (95, 95), (96, 101)], lambda y: 96, range(102, 111))
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
    S(s); E(s); NW(s); NE(s); SE(s); SW(s)
    return s
if __name__ == '__main__':
    s = avg(); s.save(O + 'avg_p.png')
    print(s.dump(3, 70, 56, 108, 110))
