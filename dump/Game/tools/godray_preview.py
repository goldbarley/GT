#!/usr/bin/env python3
"""
A preview of the Archer's godray charge shader.

The shader itself is a Godot fragment shader, and this is its twin written out
in numpy, so the look can be checked and tuned without a window.  The two have
to be kept in step: the maths here is the maths there.

    gather      green streaks flying in toward the bow
    spiral      the ring that spins around the bow
    focus       the ring collapsing to a single point
    energy_bow  the big white bow that opens over the real one
    charge      the overall glow
    flash       the white out on the release

Everything is worked out in a space where the node runs from -1 to 1, with the
centre on the bow's grip.

Run it with:  python3 tools/godray_preview.py
"""

import os

import numpy as np
from PIL import Image

SIZE = 256          # the preview is this many pixels across
OUT = "/tmp/opencode"

FRINGE = np.array([0.62, 0.92, 0.18])   # the green
MID = np.array([0.86, 1.00, 0.42])
CORE = np.array([1.00, 1.00, 1.00])


def hashf(n):
    """A cheap hash, the same one the shader uses."""
    return np.modf(np.sin(n) * 43758.5453123)[0]


def shader(uv, t, gather, spiral, focus, energy_bow, charge, flash, arrow=0.0, aim=1.0):
    """
    The charge effect, in the shader's own words.

    `uv` runs from 0 to 1 across the node; the centre of the node is the
    bow's grip.
    """
    p = (uv - 0.5) * 2.0
    d = np.sqrt(p[..., 0] ** 2 + p[..., 1] ** 2)
    a = np.arctan2(p[..., 1], p[..., 0])

    col = np.zeros(p.shape[:-1] + (3,), dtype=np.float64)
    alpha = np.zeros(p.shape[:-1], dtype=np.float64)

    # --- the streaks flying in -------------------------------------------
    if gather > 0.001:
        for i in range(16):
            ang = hashf(i * 3.7) * 6.2831853
            start = 1.15 + hashf(i * 7.1) * 0.8
            speed = 0.55 + hashf(i * 11.3) * 0.55
            k = np.clip(gather * speed + hashf(i * 5.9) * 0.30, 0.0, 1.0)
            r = start * (1.0 - k) + 0.34 * k
            tail = 0.09 + 0.16 * k
            band = np.abs(d - r)
            streak = np.clip(1.0 - band / tail, 0.0, 1.0) ** 1.6
            side = np.cos(a - ang)
            streak = streak * np.clip((side - 0.86) / 0.14, 0.0, 1.0)
            streak = streak * (1.0 - k * 0.55) * gather * 2.6
            col += FRINGE * streak[..., None]
            alpha = np.maximum(alpha, streak)

    # --- the spiral that winds in -----------------------------------------
    if spiral > 0.001:
        radius = 0.62 * (1.0 - focus * 0.90) + 0.05 * focus
        thick = 0.16 + 0.10 * focus
        band = np.abs(d - radius)
        # the arms wind in: the further out, the further round they are
        arms = 3.0
        swirl = np.sin(a * arms - np.log(np.maximum(d, 0.02)) * 5.5 + t * 4.2)
        arm = np.clip((swirl + 0.15) / 1.15, 0.0, 1.0) ** 1.6
        # the band the arms live in, fading out towards the middle
        reach = np.clip(1.0 - band / (thick * (0.5 + 0.9 * (1.0 - focus))), 0.0, 1.0)
        reach = reach ** 1.4
        ring = arm * reach
        ring *= spiral * (1.0 - focus * 0.45)
        col += FRINGE * ring[..., None] * 1.5
        col += CORE * (ring ** 3.0)[..., None] * 0.5
        alpha = np.maximum(alpha, ring * 0.95)

    # --- the point it collapses to ----------------------------------------
    if focus > 0.001:
        r0 = 0.05 + 0.10 * focus
        dot = np.clip(1.0 - d / r0, 0.0, 1.0) ** 2
        dot = dot * focus * (1.0 - energy_bow * 0.75)
        col += CORE * dot[..., None] * 1.7
        alpha = np.maximum(alpha, dot)

    # --- the big energy bow ----------------------------------------------
    # A fan of sharp white shards out of the grip, the way the energy comes
    # apart in the source, rather than a smooth arc.
    if energy_bow > 0.001:
        body = np.zeros_like(d)
        hot = np.zeros_like(d)
        for i in range(7):
            a0 = -2.6 + hashf(i * 3.7) * 3.6
            l = 0.45 + 0.55 * hashf(i * 7.1)
            w = 0.15 + 0.13 * hashf(i * 5.3)
            rel = np.mod(a - a0 + np.pi, 2.0 * np.pi) - np.pi
            along = d * np.cos(rel)
            perp = np.abs(d * np.sin(rel))
            width = np.maximum(w * (1.0 - 0.55 * np.clip(along / max(l, 1e-3), 0, 1)), 1e-3)
            shard = np.clip(1.0 - perp / width, 0.0, 1.0)
            shard = shard * (along >= 0.0) * (along <= l)
            # the shard is torn, not a clean blade
            tear = 0.78 + 0.22 * np.clip(
                np.sin(along * 9.0 + hashf(i * 11.0) * 6.2831853) * 0.5 + 0.75, 0.0, 1.0)
            shard = shard * tear
            body = np.maximum(body, shard)
            hot = np.maximum(hot, shard * np.clip(1.0 - perp / (width * 0.55), 0.0, 1.0))
        # the hot heart of it, where the shards come out of the bow
        heart = np.clip(1.0 - d / 0.42, 0.0, 1.0) ** 1.8
        body = np.maximum(body, heart * 0.8)
        hot = np.maximum(hot, heart)
        col += FRINGE * body[..., None] * 1.1
        col += CORE * hot[..., None] * 1.6
        alpha = np.maximum(alpha, np.maximum(body * 0.8, hot))

    # --- the drawn arrow along the line of the shot ------------------------
    if arrow > 0.001:
        x = p[..., 0] * aim
        y = p[..., 1]
        along = np.clip(1.0 - np.maximum(0.0, -x) / 0.9, 0.0, 1.0)
        along = along * np.clip(x / 0.9, 0.0, 1.0)
        shaft = np.clip(1.0 - np.abs(y) / 0.045, 0.0, 1.0) ** 1.4
        head = np.clip(1.0 - np.abs(np.abs(x) - 0.86) / 0.10, 0.0, 1.0)
        head = head * np.clip(1.0 - np.abs(y) / 0.11, 0.0, 1.0)
        shaft = shaft * along
        head = head * along
        glow = shaft * 0.5 + head * 0.5
        col += FRINGE * glow[..., None] * arrow * 1.3
        col += CORE * (shaft * 0.8 + head) [..., None] * arrow * 1.4
        alpha = np.maximum(alpha, (shaft * 0.9 + head) * arrow)

    # --- the flash on the release ------------------------------------------
    if flash > 0.001:
        f = np.clip(1.0 - d / 1.2, 0.0, 1.0) ** 1.5 * flash
        col += CORE * f[..., None] * 1.8
        alpha = np.maximum(alpha, f)

    return np.clip(col, 0, 1), np.clip(alpha, 0, 1)


def render(**kw):
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    uv = np.stack([xs, ys], axis=-1) / (SIZE - 1.0)
    col, alpha = shader(uv, **kw)
    img = np.zeros((SIZE, SIZE, 4), dtype=np.float64)
    img[..., :3] = col
    img[..., 3] = alpha
    return Image.fromarray((img * 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    stages = [
        ("gather", dict(t=0.10, gather=0.7, spiral=0.0, focus=0.0, energy_bow=0.0, charge=0.0, flash=0.0)),
        ("spiral", dict(t=0.40, gather=1.0, spiral=0.8, focus=0.0, energy_bow=0.0, charge=0.2, flash=0.0)),
        ("focus", dict(t=0.60, gather=1.0, spiral=1.0, focus=0.6, energy_bow=0.0, charge=0.4, flash=0.0)),
        ("energy_bow", dict(t=0.80, gather=1.0, spiral=0.6, focus=1.0, energy_bow=1.0, charge=0.6, flash=0.0)),
        ("hold", dict(t=1.40, gather=0.0, spiral=0.25, focus=1.0, energy_bow=1.0, charge=0.8, flash=0.0, arrow=1.0)),
        ("flash", dict(t=1.90, gather=0.0, spiral=0.0, focus=1.0, energy_bow=1.0, charge=1.0, flash=1.0, arrow=1.0)),
    ]
    tiles = []
    for name, kw in stages:
        im = render(**kw)
        im.save(os.path.join(OUT, f"godray_{name}.png"))
        tiles.append(im)
    row = Image.new("RGBA", (SIZE * len(tiles), SIZE), (26, 22, 30, 255))
    for i, im in enumerate(tiles):
        row.alpha_composite(im, (i * SIZE, 0))
    row.save(os.path.join(OUT, "godray_stages.png"))
    print("wrote", os.path.join(OUT, "godray_stages.png"))


if __name__ == "__main__":
    main()
