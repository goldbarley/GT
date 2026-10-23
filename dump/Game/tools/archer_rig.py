#!/usr/bin/env python3
"""
Build the modular Archer rig: slice the four source atlases into pieces, work
out where every piece belongs in the assembled sprite, derive its rotation
pivot, and write the data the game needs.

WHY THIS EXISTS
---------------
The Archer art arrives the same way the Mage's did: four 128x32 atlases, each
holding a handful of separated pieces plus the assembled archer itself.  The
pieces have to be put back together in the right place before anything can be
animated, and getting that wrong is exactly the failure that matters - a piece
attached one pixel off, or turning about the wrong joint.

HOW THE ATLASES ARE PUT TOGETHER
--------------------------------
Each atlas has one region that holds the *assembled* archer, and the loose
pieces that make it up:

    front  the assembled archer is the reference sprite at the right hand end
    back   the assembled archer is the big blob on the left, with the bow,
           the quiver and the sword already drawn into it
    left   the assembled archer is the reference sprite at the right hand end
    right  the assembled archer is the reference sprite at the right hand end

For the back view the loose pieces are drawn *into* the assembled archer, so
they are found by matching them against it and the body is what is left over.

HOW IT WORKS
------------
1.  Each atlas is cut into named pieces.  A piece is a list of rectangles, so
    a piece the artist drew as several disconnected blobs is still one piece.
2.  Every loose piece is matched against the assembled archer by trying every
    position it could sit at.  A position is scored on how much of the piece
    lands on art of the same colour, so art the assembled archer hides (the
    quiver behind the hair, for instance) does not rule the right position out.
3.  The z order is read back out of the answer: where two pieces disagree
    about a pixel they share, the one whose colour matches the assembled archer
    is the one in front.
4.  The composite is then checked against the assembled archer pixel by pixel.
    A clean run means every piece is attached where it belongs.
5.  The pivot of each piece is derived from the art, the way the Mage's pivots
    were: the bow turns about the hand that grips it, the boot turns about the
    hip, the body turns about the waist.

The output is the same shape the Mage uses: a `pieces.json` per perspective, a
clean atlas that no two pieces overlap in, and a `.tscn` scene per perspective.
"""

import json
import math
import os
import sys

from PIL import Image

PI = math.pi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHER_DIR = os.path.join(ROOT, "Archer")
SOURCE_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "Archer_sprites")
PERSPECTIVES = ["front", "back", "left", "right"]
PAD = 1  # transparent gutter between packed pieces


# --------------------------------------------------------------------------- #
# the cut
# --------------------------------------------------------------------------- #
# `assembled` is the rectangle of the source atlas that holds the assembled
# archer.  It is the answer key the pieces are matched against, and it is what
# the composite is checked against.
#
# `pieces` lists the loose pieces: a name and the rectangles they occupy in
# the source atlas.  A piece may need more than one rectangle when the artist
# drew it as several disconnected blobs.
#
# `body` names the piece that is *not* loose: the part of the assembled archer
# that no loose piece claims.  Only the back view has one, because there the
# pieces are drawn into the assembled archer.
#
# `role` says what the piece is for, which is how its pivot is worked out:
#   body    the whole character, turns about the waist
#   bow     the bow, turns about the grip
#   quiver  the quiver on the back, turns about the strap
#   weapon  the sword, turns about the hand
#   cape    the leaves and cloth, turn about the shoulder
#   foot    a boot, turns about the hip
#   leaf    loose leaves, turn about where they meet the body
PIECES = {
    "front": {
        "assembled": (95, 0, 33, 32),
        "body": None,
        "pieces": [
            ("leaf_a", "leaf",   [(1, 9, 7, 8)]),
            ("cape",   "cape",   [(4, 18, 13, 13)]),
            ("foot_a", "foot",   [(42, 25, 4, 3)]),
            ("foot_b", "foot",   [(51, 26, 5, 4)]),
            ("arm",    "arm",    [(8, 1, 7, 12)]),
            ("body",   "body",   [(18, 1, 20, 29)]),
            ("bow",    "bow",    [(41, 1, 19, 19)]),
            ("quiver", "quiver", [(62, 3, 12, 23)]),
        ],
    },
    "back": {
        "assembled": (1, 0, 38, 32),
        "body": "body",
        # the back view draws its pieces on top of each other, so a piece can
        # hold art that another piece covers
        "trim": True,
        # the quiver is drawn over the hair, not behind it
        "in_front": [("quiver", "body")],
        "pieces": [
            ("foot_a", "foot",   [(47, 19, 4, 4)]),
            ("foot_b", "foot",   [(47, 26, 4, 4)]),
            ("quiver", "quiver", [(54, 3, 13, 22)]),
            ("bow",    "bow",    [(68, 1, 19, 19)]),
            ("leaf_a", "leaf",   [(65, 18, 10, 12)]),
            ("cape",   "cape",   [(81, 2, 11, 10)]),
            ("arm",    "arm",    [(78, 22, 9, 7)]),
        ],
    },
    "left": {
        "assembled": (93, 1, 35, 31),
        "body": None,
        "pieces": [
            ("quiver", "quiver", [(1, 8, 12, 23)]),
            ("bow",    "bow",    [(14, 13, 19, 19)]),
            ("arm",    "arm",    [(16, 3, 9, 7)]),
            ("foot_a", "foot",   [(21, 11, 4, 3)]),
            ("foot_b", "foot",   [(28, 16, 4, 4)]),
            ("spare_blade", "arm", [(29, 2, 8, 10)]),
            ("body",   "body",   [(36, 1, 26, 28)]),
            ("cape",   "cape",   [(55, 19, 22, 12)]),
            ("leaf_a", "leaf",   [(62, 9, 10, 10)]),
        ],
    },
    "right": {
        "assembled": (93, 1, 35, 31),
        "body": None,
        "pieces": [
            ("bow",    "bow",    [(1, 11, 19, 19)]),
            ("arm",    "arm",    [(2, 4, 8, 10)]),
            ("quiver", "quiver", [(21, 9, 12, 23)]),
            ("leaf_a", "leaf",   [(33, 4, 10, 10)]),
            ("cape",   "cape",   [(34, 13, 22, 12)]),
            ("foot_a", "foot",   [(45, 27, 4, 3)]),
            ("foot_b", "foot",   [(36, 26, 4, 4)]),
            ("body",   "body",   [(57, 2, 27, 28)]),
        ],
    },
}


# --------------------------------------------------------------------------- #
# pixel helpers
# --------------------------------------------------------------------------- #
def rect_pixels(tex, rects):
    """
    The opaque pixels of a piece, as (x, y, colour) in the atlas's own pixels.
    """
    px = tex.load()
    out = []
    for (rx, ry, w, h) in rects:
        for j in range(h):
            for i in range(w):
                ax, ay = rx + i, ry + j
                if 0 <= ax < tex.width and 0 <= ay < tex.height:
                    c = px[ax, ay]
                    if c[3] > 0:
                        out.append((ax, ay, c[:3]))
    return out


def score_positions(pixels, origin, target, explained=None):
    """
    Every position the piece could sit at inside the target, best first.

    A position is scored on how much of the piece lands on art of the same
    colour, with a penalty for putting art onto the wrong colour.  Art the
    target hides (the quiver behind the hair) is neither rewarded nor
    punished, so it does not rule the right position out.

    `explained` is the set of target pixels another piece already owns.  When
    it is given, only the pixels that are still free are judged, so a piece
    that sits behind another one can still be found.
    """
    tw, th = target.width, target.height
    tp = target.load()
    ox, oy = origin
    pw = max(p[0] - ox for p in pixels)
    ph = max(p[1] - oy for p in pixels)
    results = []
    for py in range(-ph, th + ph):
        for px in range(-pw, tw + pw):
            matched = 0
            bad = 0
            for (ax, ay, col) in pixels:
                tx = ax - ox + px
                ty = ay - oy + py
                if tx < 0 or ty < 0 or tx >= tw or ty >= th:
                    continue
                if explained is not None and (tx, ty) in explained:
                    continue
                c = tp[tx, ty]
                if c[3] == 0:
                    continue
                if c[:3] == col:
                    matched += 1
                else:
                    bad += 1
            # the sort key is how much of the piece lands on identical art.
            # Art the target hides counts for nothing rather than against the
            # piece, because a piece behind another one is allowed to
            # disagree with what is drawn on top of it.
            results.append((matched, -bad, px, py))
    results.sort(reverse=True)
    return results


def solve_position(pixels, origin, target):
    """Where does the piece go?  (position, matched, contradicted)."""
    top = score_positions(pixels, origin, target)[0]
    matched, negbad, px, py = top
    return (px, py), matched, -negbad


def pixels_in_target(pixels, origin, pos):
    """The piece's pixels in the target's space: { (x, y): colour }."""
    out = {}
    for (ax, ay, col) in pixels:
        out[(ax - origin[0] + pos[0], ay - origin[1] + pos[1])] = col
    return out


def compose(sheet, placed, order, w, h):
    """Draw the placed pieces on a fresh canvas, lowest first."""
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for name in order:
        piece = placed[name]
        pos, origin, rects = piece["pos"], piece["origin"], piece["rects"]
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        lp = layer.load()
        if piece.get("pixels_only"):
            for (tx, ty, col) in piece["pixels_only"]:
                if 0 <= tx < w and 0 <= ty < h:
                    lp[tx, ty] = (col[0], col[1], col[2], 255)
        else:
            for (ax, ay, col) in rect_pixels(sheet, rects):
                tx = ax - origin[0] + pos[0]
                ty = ay - origin[1] + pos[1]
                if 0 <= tx < w and 0 <= ty < h:
                    lp[tx, ty] = (col[0], col[1], col[2], 255)
        canvas.alpha_composite(layer)
    return canvas


def compare(a, b):
    """(wrong, missing, extra) pixel counts between two sprites."""
    wrong = missing = extra = 0
    ap, bp = a.load(), b.load()
    for y in range(min(a.height, b.height)):
        for x in range(min(a.width, b.width)):
            ca, cb = ap[x, y], bp[x, y]
            if ca[3] == 0 and cb[3] == 0:
                continue
            if ca[3] == 0:
                missing += 1
            elif cb[3] == 0:
                extra += 1
            elif ca[:3] != cb[:3]:
                wrong += 1
    return wrong, missing, extra


def derive_order(placed, target, w, h, body_name=None):
    """
    Which piece is in front of which?

    Every pixel of the assembled archer belongs to the piece whose art is the
    art that is really there.  Where a piece's own art is not the art that is
    really there, something is drawn on top of it, and that something is in
    front.  So the order is read straight off the assembled sprite rather
    than guessed.

    Where two pieces disagree about it - one of them covers the other in one
    place and the other way round somewhere else - the one that covers more
    of the other is the one in front.  A few pieces can end up in a circle,
    because the art really does have them over each other in different
    places; the weakest claim in the circle is the one that is given up.
    """
    owner = {}
    for name, piece in placed.items():
        for pt, col in piece.get("own", {}).items():
            owner.setdefault(pt, name)

    names = list(placed.keys())
    votes = {}
    for name in names:
        for q in placed[name].get("hidden", []):
            other = owner.get(q)
            if other is None:
                # nothing explains this pixel, so the archer herself is the
                # one covering it
                other = body_name
            if other is None or other == name:
                continue
            key = (name, other)
            votes[key] = votes.get(key, 0) + 1

    # `above[a]` holds the pieces that are drawn on top of a
    above = {n: set() for n in names}
    weight = {}
    for (a, b), count in votes.items():
        net = count - votes.get((b, a), 0)
        if net > 0:
            above[a].add(b)
            weight[(a, b)] = net

    while True:
        order = _sort_above(above)
        if order is not None:
            return order
        # a circle: give up the weakest claim in it
        cycle = _find_cycle(above)
        weakest = min(cycle, key=lambda e: weight.get(e, 0))
        a, b = weakest
        above[a].discard(b)
        weight.pop((a, b), None)


def _sort_above(above):
    """The pieces from the bottom up, or None when they are in a circle."""
    order = []
    remaining = {n: set(v) for n, v in above.items()}
    while remaining:
        ready = [n for n in remaining if not any(n in remaining[m] for m in remaining)]
        if not ready:
            return None
        ready.sort()
        for n in ready:
            order.append(n)
            del remaining[n]
    return order


def _find_cycle(above):
    """One circle of pieces, as the list of (below, above) claims in it."""
    state = {}
    stack = []

    def walk(node):
        state[node] = 1
        stack.append(node)
        for other in sorted(above.get(node, ())):
            if state.get(other, 0) == 0:
                found = walk(other)
                if found:
                    return found
            elif state.get(other) == 1:
                start = stack.index(other)
                circle = stack[start:]
                return [(circle[i], circle[(i + 1) % len(circle)])
                        for i in range(len(circle))]
        stack.pop()
        state[node] = 2
        return None

    for node in sorted(above):
        if state.get(node, 0) == 0:
            found = walk(node)
            if found:
                return found
    return []


# --------------------------------------------------------------------------- #
# pivots
# --------------------------------------------------------------------------- #
# The skin colours the artist's hands are drawn in.  A hand is the thing that
# holds a weapon or a bow, so the pixels of that colour say where the grip is.
SKIN = [
    (254, 215, 177), (248, 191, 163), (238, 195, 154), (233, 152, 111),
    (195, 147, 114), (203, 150, 114), (203, 136, 103), (174, 134, 107),
]


def near(a, b, tolerance=0):
    """Are two colours the same colour, allowing for a little difference?"""
    if tolerance <= 0:
        return a == b
    return (abs(a[0] - b[0]) <= tolerance
            and abs(a[1] - b[1]) <= tolerance
            and abs(a[2] - b[2]) <= tolerance)


def is_green(col):
    """The archer's leaves: green over both red and blue."""
    return col[1] > col[0] and col[1] > col[2]


def is_skin(col):
    for s in SKIN:
        if abs(col[0] - s[0]) <= 12 and abs(col[1] - s[1]) <= 12 and abs(col[2] - s[2]) <= 12:
            return True
    return False


def piece_art(piece):
    """The piece's art in the target's space: { (x, y): colour }."""
    if piece.get("pixels_only"):
        return {(x, y): col for (x, y, col) in piece["pixels_only"]}
    return piece["pixels"]


def centroid(points):
    if not points:
        return None
    sx = sum(p[0] for p in points)
    sy = sum(p[1] for p in points)
    return (sx / len(points), sy / len(points))


def _solid_pixels(art):
    """
    The art pixels that are part of a shape rather than a thin line.

    The bowstring is one pixel wide, so the point nearest a hand is often a
    pixel of string.  The limbs are solid, and the grip is on one of them.
    """
    out = []
    for (x, y), col in art.items():
        same = 0
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            other = art.get((x + dx, y + dy))
            if other == col:
                same += 1
        if same >= 2:
            out.append((x, y))
    return out


def derive_pivot(name, role, piece, placed, w, h):
    """
    Where does this piece turn about?

    The pivot is worked out from the art rather than written down by hand,
    the way the Mage's pivots were:

        body    the waist, so the whole character turns about its middle
        foot    the hip, where the leg enters the boot
        weapon  the hand that holds it
        bow     the grip, where the hand holds the bow
        quiver  the strap, over the shoulder
        cape    the shoulder, where it is worn
        leaf    where it meets the body

    The answer comes back in the target's own pixels, and is turned into the
    piece's own space by the caller.
    """
    art = piece_art(piece)
    if not art:
        return None

    if role == "body":
        xs = [p[0] for p in art]
        ys = [p[1] for p in art]
        # the waist: the middle of the character's width, five pixels above
        # the bottom of the art, which is where the robe ends
        return ((min(xs) + max(xs)) * 0.5, max(ys) - 5.0)

    if role == "foot":
        top = min(p[1] for p in art)
        row = [p[0] for p in art if abs(p[1] - top) < 0.5]
        return (sum(row) / len(row), float(top))

    body = placed.get("body")
    body_art = piece_art(body) if body else {}

    if role == "arm":
        # the shoulder: the leaves at the top of the arm, where it goes into
        # the body.  Where the view has no leaves on the arm, the top of the
        # sleeve is the shoulder.
        green = [p for p, c in art.items() if is_green(c)]
        if green:
            return centroid(green)
        top = min(p[1] for p in art)
        return centroid([p for p in art if p[1] == top])

    if role == "bow":
        # the grip is the hand, and the hand is the one on the weapon arm.
        # The hand is drawn in skin tones, so it is found by its colour.
        hands = [p for other in placed.values() if other["role"] == "arm"
                 for p, c in piece_art(other).items() if is_skin(c)]
        if hands:
            return centroid(hands)
        own = [p for p, c in art.items() if is_skin(c)]
        if own:
            return centroid(own)
        shared = [p for p in art if p in body_art]
        if shared:
            return centroid(shared)
        return centroid(list(art.keys()))

    if role == "quiver":
        # the middle of the quiver, which is where it sits against the torso.
        # The top of the quiver is the strap, and that hangs on the hair.
        xs = [p[0] for p in art]
        ys = [p[1] for p in art]
        return ((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5)

    if role in ("cape", "leaf"):
        shared = [p for p in art if p in body_art]
        if shared:
            return centroid(shared)
        if body_art:
            near = min(art.keys(),
                       key=lambda p: min((q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2
                                         for q in body_art))
            return near
        return centroid(list(art.keys()))

    return centroid(list(art.keys()))


# --------------------------------------------------------------------------- #
# the analysis
# --------------------------------------------------------------------------- #
def analyse(persp, verbose=True):
    spec = PIECES[persp]
    sheet = Image.open(os.path.join(SOURCE_DIR, f"Archer_{persp}.png")).convert("RGBA")
    ax, ay, aw, ah = spec["assembled"]
    target = sheet.crop((ax, ay, ax + aw, ay + ah))

    # ---- pass one: the pieces that find an unambiguous place on their own
    todo = []
    solved = {}
    for entry in spec["pieces"]:
        name, role, rects = entry[0], entry[1], entry[2]
        nudge = entry[3] if len(entry) > 3 else (0, 0)
        origin = (rects[0][0], rects[0][1])
        pix = rect_pixels(sheet, rects)
        top = score_positions(pix, origin, target)
        matched, negbad, px, py = top[0]
        bad = -negbad
        px += nudge[0]
        py += nudge[1]
        second = top[1][0] if len(top) > 1 else 0
        confident = (matched >= 0.5 * len(pix)) and (matched > 2 * second)
        if confident:
            solved[name] = {"pos": (px, py), "origin": origin, "rects": rects,
                            "role": role, "pix": pix, "matched": matched,
                            "bad": bad}
        else:
            todo.append(entry)
        if verbose:
            print(f"   {name:8s} {len(pix):4d} px -> canvas ({px},{py})  "
                  f"matched {matched}  contradicted {bad}"
                  f"{'' if confident else '   (not certain yet)'}")

    explained = set()
    for name, piece in solved.items():
        for (ax2, ay2, col) in piece["pix"]:
            tx = ax2 - piece["origin"][0] + piece["pos"][0]
            ty = ay2 - piece["origin"][1] + piece["pos"][1]
            if 0 <= tx < aw and 0 <= ty < ah:
                if target.getpixel((tx, ty))[:3] == col:
                    explained.add((tx, ty))

    # ---- pass two: the pieces that are hidden behind another one
    while todo:
        best = None
        for entry in todo:
            name, role, rects = entry[0], entry[1], entry[2]
            nudge = entry[3] if len(entry) > 3 else (0, 0)
            origin = (rects[0][0], rects[0][1])
            pix = rect_pixels(sheet, rects)
            top = score_positions(pix, origin, target, explained)
            matched, negbad, px, py = top[0]
            bad = -negbad
            px += nudge[0]
            py += nudge[1]
            if best is None or matched > best[0]:
                best = (matched, bad, px, py, name, role, rects, origin, pix)
        matched, bad, px, py, name, role, rects, origin, pix = best
        if verbose:
            print(f"   {name:8s} {len(pix):4d} px -> canvas ({px},{py})  "
                  f"matched {matched}  contradicted {bad}   (hidden piece)")
        solved[name] = {"pos": (px, py), "origin": origin, "rects": rects,
                        "role": role, "pix": pix, "matched": matched}
        for (ax2, ay2, col) in pix:
            tx = ax2 - origin[0] + px
            ty = ay2 - origin[1] + py
            if 0 <= tx < aw and 0 <= ty < ah:
                if target.getpixel((tx, ty))[:3] == col:
                    explained.add((tx, ty))
        todo = [t for t in todo if t[0] != name]

    placed = {}
    claimed = {}
    tolerance = 0 if spec.get("trim") else 20
    for name, piece in solved.items():
        origin, pos = piece["origin"], piece["pos"]
        tgt = pixels_in_target(piece["pix"], origin, pos)
        own = {}
        hidden = []
        for (x, y), col in tgt.items():
            if x < 0 or y < 0 or x >= aw or y >= ah:
                continue
            tc = target.getpixel((x, y))
            if tc[3] == 0:
                # the piece reaches past the archer, so it is simply visible
                continue
            if near(tc[:3], col, tolerance):
                own[(x, y)] = col
            else:
                # something is drawn on top of the piece here, so the art that
                # belongs there is not the piece's
                hidden.append((x, y))
        piece["own"] = own
        piece["hidden"] = hidden

        if spec.get("trim") and name != "quiver":
            # The back view draws its pieces on top of each other, so a piece
            # can hold art that another piece covers.  That art is dropped
            # here: the piece does not carry it away, and the body keeps it.
            drop = set(hidden)
            piece["pix"] = [(ax, ay, c) for (ax, ay, c) in piece["pix"]
                            if (ax - origin[0] + pos[0],
                                ay - origin[1] + pos[1]) not in drop]
            tgt = pixels_in_target(piece["pix"], origin, pos)

        placed[name] = {"pos": piece["pos"], "origin": piece["origin"],
                        "rects": piece["rects"], "pixels": tgt,
                        "pix": piece["pix"], "role": piece["role"],
                        "matched": piece["matched"], "bad": piece.get("bad", 0),
                        "own": own, "hidden": hidden}
        for pt in own:
            if pt not in claimed:
                claimed[pt] = name

    # the body is whatever of the assembled archer no loose piece claims
    if spec["body"]:
        body_pixels = []
        body_own = {}
        tp = target.load()
        for y in range(ah):
            for x in range(aw):
                if tp[x, y][3] > 0 and (x, y) not in claimed:
                    body_pixels.append((x, y, tp[x, y][:3]))
                    body_own[(x, y)] = tp[x, y][:3]
        placed[spec["body"]] = {"pos": (0, 0), "origin": (ax, ay),
                                "rects": [(ax, ay, aw, ah)], "pixels": {},
                                "pix": [], "role": "body", "own": body_own,
                                "hidden": [],
                                "pixels_only": body_pixels}
        if verbose:
            print(f"   {spec['body']:8s} {len(body_pixels):4d} px -> canvas (0, 0)  (the rest)")

    order = derive_order(placed, target, aw, ah, spec.get("body"))

    # The back view draws the archer's hair over the top of the quiver.  The
    # quiver is of more use in front of the hair than behind it, so it is
    # brought forward.
    for name, in_front_of in spec.get("in_front", []):
        if name not in order or in_front_of not in order:
            continue
        order.remove(name)
        order.insert(order.index(in_front_of) + 1, name)

    if verbose:
        print(f"   z order (low to high): {order}")

    comp = compose(sheet, placed, order, aw, ah)
    wrong, missing, extra = compare(comp, target)
    if verbose:
        print(f"   composite vs assembled: wrong {wrong}, missing {missing}, extra {extra}")
    return sheet, target, placed, order, (wrong, missing, extra)


def preview(persp):
    sheet, target, placed, order, diffs = analyse(persp)
    comp = compose(sheet, placed, order, target.width, target.height)
    out = Image.new("RGBA", (target.width * 2 + 4, target.height), (60, 20, 20, 255))
    out.alpha_composite(target, (0, 0))
    out.alpha_composite(comp, (target.width + 4, 0))
    out.resize((out.width * 10, out.height * 10), Image.NEAREST).save(
        os.path.join("/tmp/opencode", f"preview_{persp}.png"))
    diff = Image.new("RGBA", target.size, (0, 0, 0, 0))
    dp = diff.load()
    cp = comp.load()
    tp = target.load()
    for y in range(target.height):
        for x in range(target.width):
            rc, cc = tp[x, y], cp[x, y]
            if rc[3] == 0 and cc[3] == 0:
                continue
            if rc[3] > 0 and cc[3] == 0:
                dp[x, y] = (255, 0, 0, 255)
            elif rc[3] == 0 and cc[3] > 0:
                dp[x, y] = (0, 255, 0, 255)
            elif rc[:3] != cc[:3]:
                dp[x, y] = (255, 255, 0, 255)
    diff.resize((target.width * 12, target.height * 12), Image.NEAREST).save(
        os.path.join("/tmp/opencode", f"diff_{persp}.png"))
    print(f"   preview -> /tmp/opencode/preview_{persp}.png, diff -> diff_{persp}.png")





# --------------------------------------------------------------------------- #
# building the rig
# --------------------------------------------------------------------------- #
def piece_art_canvas(piece):
    """The piece's art in the canvas's own pixels: [ (x, y, colour) ]."""
    if piece.get("pixels_only"):
        return list(piece["pixels_only"])
    pos, origin = piece["pos"], piece["origin"]
    out = []
    for (ax, ay, col) in piece["pix"]:
        out.append((ax - origin[0] + pos[0], ay - origin[1] + pos[1], col))
    return out


def tight_box(art):
    """The smallest rectangle that holds a piece's art."""
    xs = [p[0] for p in art]
    ys = [p[1] for p in art]
    return (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


def pack(rects, width):
    """First fit decreasing shelf packer: {name: (w, h)} -> ({name: (x, y)}, height)."""
    order = sorted(rects.items(), key=lambda kv: (-kv[1][1], -kv[1][0]))
    placed = {}
    shelf_y = 0
    shelf_h = 0
    cursor_x = 0
    for name, (w, h) in order:
        if cursor_x + w > width:
            shelf_y += shelf_h + PAD
            shelf_h = 0
            cursor_x = 0
        placed[name] = (cursor_x, shelf_y)
        cursor_x += w + PAD
        shelf_h = max(shelf_h, h)
    return placed, shelf_y + shelf_h


def node_name(piece_name):
    """body -> Body, foot_a -> FootA, leaf_a -> LeafA"""
    return "".join(part.capitalize() for part in piece_name.split("_"))


# which pieces each perspective knows about, and what they are for
ROLE_NAMES = ["body", "bow", "quiver", "arm", "cape", "leaf_a",
              "foot_a", "foot_b"]

# what the clips call each piece, whatever the perspective calls it
ROLES = {
    "body": "body", "bow": "bow", "quiver": "quiver", "arm": "arm",
    "cape": "cape", "leaf_a": "leaf", "foot_a": "foot_a", "foot_b": "foot_b",
}


def solve(persp):
    """
    Work out where every piece goes and where it turns, for one perspective.
    Nothing is written yet: the profile views have to agree with each other
    first, and they can only do that once both have been solved.
    """
    verbose = True
    sheet, target, placed, order, diffs = analyse(persp, verbose=True)

    # ---- the pieces that could not be found at all are dropped ------------
    for name in list(placed.keys()):
        piece = placed[name]
        if "matched" not in piece:
            continue
        pix = piece["pix"]
        if not pix:
            continue
        good = piece["matched"]
        # a piece that is barely in the assembled archer, and disagrees with
        # it more than it agrees, is not part of this view at all
        if good < 0.15 * len(pix) or (good < 0.5 * len(pix)
                                     and piece.get("bad", 0) > 2 * good):
            if verbose:
                print(f"   {name:8s} DROPPED - it is not in the assembled archer")
            del placed[name]

    # ---- the art of every piece, in the canvas's own pixels ---------------
    art = {name: piece_art_canvas(piece) for name, piece in placed.items()}

    # ---- where each piece sits, and where it turns -----------------------
    boxes = {name: tight_box(a) for name, a in art.items()}
    pivots = {}
    for name, piece in placed.items():
        pv = derive_pivot(name, piece["role"], piece, placed, target.width, target.height)
        if pv is None:
            continue
        bx, by = boxes[name][0], boxes[name][1]
        pivots[name] = (round(pv[0] - bx, 2), round(pv[1] - by, 2))

    return {
        "persp": persp,
        "sheet": sheet,
        "target": target,
        "placed": placed,
        "order": order,
        "art": art,
        "boxes": boxes,
        "pivots": pivots,
    }


def write(persp, solved):
    """Write the atlas, the data and the scene for one perspective."""
    verbose = True
    sheet = solved["sheet"]
    target = solved["target"]
    placed = solved["placed"]
    order = solved["order"]
    art = solved["art"]
    boxes = solved["boxes"]
    pivots = solved["pivots"]

    # ---- the clean atlas --------------------------------------------------
    order_low_high = order
    z_of = {name: i for i, name in enumerate(order_low_high)}
    packed, pieces_h = pack({n: (boxes[n][2], boxes[n][3]) for n in art}, 128)
    ref_h = target.height
    sheet_h = pieces_h + PAD + ref_h
    clean = Image.new("RGBA", (128, sheet_h), (0, 0, 0, 0))
    new_regions = {}
    for name, a in art.items():
        bx, by, bw, bh = boxes[name]
        layer = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        lp = layer.load()
        for (x, y, col) in a:
            lp[x - bx, y - by] = (col[0], col[1], col[2], 255)
        px, py = packed[name]
        clean.paste(layer, (px, py), layer)
        new_regions[name] = {"x": px, "y": py, "w": bw, "h": bh}
    ref_y = pieces_h + PAD
    clean.paste(target, (0, ref_y), target)
    ref_rect = {"x": 0, "y": ref_y, "w": target.width, "h": target.height}

    # ---- the folder -------------------------------------------------------
    base = os.path.join(ARCHER_DIR, f"archer_{persp}")
    os.makedirs(base, exist_ok=True)
    sheet.save(os.path.join(base, f"Archer_{persp}.png"))
    clean_name = f"Archer_{persp}_clean.png"
    clean.save(os.path.join(base, clean_name))

    # ---- pieces.json ------------------------------------------------------
    roles = {}
    for name in placed:
        if name in ROLE_NAMES:
            roles[ROLES.get(name, name)] = name
    body_box = boxes["body"]
    waist = (body_box[0] + body_box[2] / 2.0, body_box[1] + body_box[3] - 5.0)
    # The arm hangs off the shoulder, so it is part of the torso and travels
    # with it, the same way the mage's arm does.
    torso_members = [n for n in ("body", "arm", "cape", "leaf_a") if n in placed]
    data = {
        "perspective": persp,
        "canvas_size": {"width": target.width, "height": target.height},
        "spritesheet": clean_name,
        "reference_rect": ref_rect,
        "roles": roles,
        "groups": {
            "torso": {
                "pivot": {"x": round(waist[0], 2), "y": round(waist[1], 2)},
                "members": torso_members,
            },
            "all": {
                "pivot": {"x": target.width // 2, "y": target.height},
                "members": list(placed.keys()),
            },
        },
        # The bow is held in the hand at the end of the arm, so it rides on
        # the arm: raising the arm raises the bow with it.  The quiver hangs on
        # the back, so it rides on the body.
        "piece_parents": {n: p for n, p in
                          (("bow", "arm"), ("quiver", "body"))
                          if n in placed and p in placed},
        "pieces": {},
    }
    for name, piece in placed.items():
        bx, by, bw, bh = boxes[name]
        pvx, pvy = pivots.get(name, (0.0, 0.0))
        data["pieces"][name] = {
            "region": new_regions[name],
            "position": {"x": bx, "y": by},
            "pivot": {"x": pvx, "y": pvy},
            "z_index": z_of.get(name, 0),
            "description": piece["role"],
        }
    with open(os.path.join(base, "pieces.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")

    # ---- the script for the perspective ------------------------------------
    write_rig_script(persp, base, data)

    # ---- the scene --------------------------------------------------------
    write_tscn(persp, base, clean_name, data)
    return data


def write_rig_script(persp, base, data):
    """
    Write the script for one perspective.

    It sets which perspective the rig is and how big its canvas is, and falls
    back to assembling the rig from pieces.json when the scene has no children
    of its own.
    """
    cap = persp.capitalize()
    w = data["canvas_size"]["width"]
    h = data["canvas_size"]["height"]
    text = f"""extends ArcherModularBase
class_name Archer{cap}

const JSON_PATH = "res://Archer/archer_{persp}/pieces.json"
const TEXTURE_PATH = "res://Archer/archer_{persp}/{data['spritesheet']}"


func _init() -> void:
	perspective_name = "{persp}"
	canvas_size = Vector2({w}, {h})


func _ready() -> void:
	super._ready()
	# If no children exist (e.g. instantiated from pure script without .tscn), assemble from json
	if get_child_count() == 0:
		assemble_from_json(JSON_PATH, TEXTURE_PATH)
"""
    with open(os.path.join(base, f"Archer{cap}.gd"), "w") as fh:
        fh.write(text)


# The godray charge, the effect that gathers on the bow before a shot.  It is
# a child of the bow, so it stays on the grip however the bow is turned.
#
# `aim` is the way the shot goes along the effect: the archer fires to the
# right in the front and right views, and to the left in the back and left
# ones.
GODRAY = {
    "front": {"aim": 1.0},
    "back": {"aim": -1.0},
    "left": {"aim": -1.0},
    "right": {"aim": 1.0},
}


def write_tscn(persp, base, clean_name, data):
    """
    Write the scene for one perspective.

    Every piece is a Sprite2D that samples its own rectangle out of the clean
    atlas.  The node's origin is the pivot: `offset` pulls the art back by the
    pivot and `position` puts the origin on the joint, so the piece turns
    about the joint and nowhere else.  This is the same arrangement the Mage
    uses.
    """
    cap = persp.capitalize()
    lines = [
        "[gd_scene load_steps=6 format=3]",
        "",
        f'[ext_resource type="Script" path="res://Archer/archer_{persp}/Archer{cap}.gd" id="1_script"]',
        f'[ext_resource type="Texture2D" path="res://Archer/archer_{persp}/{clean_name}" id="2_tex"]',
        '[ext_resource type="Shader" path="res://Archer/anim/shaders/archer_character_clip.gdshader" id="3_clip"]',
        '[ext_resource type="Shader" path="res://Archer/anim/shaders/archer_godray.gdshader" id="4_godray"]',
        '[ext_resource type="Texture2D" path="res://Archer/art/energy_bow.png" id="5_energy"]',
        "",
        "",
        '[sub_resource type="ShaderMaterial" id="ShaderMaterial_character_clip"]',
        "resource_local_to_scene = true",
        'shader = ExtResource("3_clip")',
        "shader_parameter/band_top = -100000.0",
        "shader_parameter/band_bottom = 100000.0",
        "",
        '[sub_resource type="ShaderMaterial" id="ShaderMaterial_godray"]',
        "resource_local_to_scene = true",
        'shader = ExtResource("4_godray")',
        "shader_parameter/gather = 0.0",
        "shader_parameter/spiral = 0.0",
        "shader_parameter/focus = 0.0",
        "shader_parameter/energy_bow = 0.0",
        "shader_parameter/arrow = 0.0",
        "shader_parameter/charge = 0.0",
        "shader_parameter/flash = 0.0",
        f"shader_parameter/aim = {GODRAY[persp]['aim']}",
        'shader_parameter/energy_tex = ExtResource("5_energy")',
        "",
        f'[node name="Archer{cap}" type="Node2D"]',
        "texture_filter = 1",
        'script = ExtResource("1_script")',
        "",
    ]
    for name, piece in data["pieces"].items():
        r = piece["region"]
        pos = piece["position"]
        piv = piece["pivot"]
        node = node_name(name)
        lines += [
            f'[node name="{node}" type="Sprite2D" parent="."]',
            'material = SubResource("ShaderMaterial_character_clip")',
            f"z_index = {piece['z_index']}",
            "texture_filter = 1",
            'texture = ExtResource("2_tex")',
            "region_enabled = true",
            f"region_rect = Rect2({r['x']}, {r['y']}, {r['w']}, {r['h']})",
            "centered = false",
            f"offset = Vector2({-piv['x']}, {-piv['y']})",
            f"position = Vector2({pos['x'] + piv['x']}, {pos['y'] + piv['y']})",
            f"metadata/pivot = Vector2({piv['x']}, {piv['y']})",
            "",
        ]
        if name == "bow":
            # the charge effect sits on the grip, which is the bow's own origin
            lines += [
                '[node name="GodrayFX" type="ColorRect" parent="Bow"]',
                'material = SubResource("ShaderMaterial_godray")',
                "z_index = 3",
                "offset_left = -64.0",
                "offset_top = -64.0",
                "offset_right = 64.0",
                "offset_bottom = 64.0",
                "mouse_filter = 2",
                "color = Color(1, 1, 1, 1)",
                "",
            ]
    with open(os.path.join(base, f"archer_{persp}.tscn"), "w") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = args if args else PERSPECTIVES
    if "--build" in sys.argv:
        solved = {}
        for p in only:
            print(f"== {p}")
            solved[p] = solve(p)
        for p in only:
            write(p, solved[p])
            print(f"   wrote {os.path.join(ARCHER_DIR, 'archer_' + p)}")
    else:
        for p in only:
            print(f"== {p}")
            if "--preview" in sys.argv:
                preview(p)
            else:
                analyse(p)
