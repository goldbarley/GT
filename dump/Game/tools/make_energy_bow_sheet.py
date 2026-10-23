import os
import numpy as np
from PIL import Image

VIDEO_FRAMES = "/home/stark/archer_godray/frames_native"
OUT_DIR = "/home/stark/Game/Archer/art"
OUT_PNG = os.path.join(OUT_DIR, "energy_bow_sheet.png")

# Native grip coordinate in reference video
GRIP_X, GRIP_Y = 152, 89
CANVAS = 128
VIDEO_ARCHER_HEIGHT = 45
GAME_ARCHER_HEIGHT = 32
scale = GAME_ARCHER_HEIGHT / float(VIDEO_ARCHER_HEIGHT)
BRIGHT = 100

# 6 distinct subtle flame frames extracted straight from the reference video
frames_to_extract = [66, 68, 70, 72, 74, 76]

sheet_w = CANVAS * len(frames_to_extract)
sheet_h = CANVAS
sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

for i, fnum in enumerate(frames_to_extract):
    path = os.path.join(VIDEO_FRAMES, f"frame_{fnum:04d}.png")
    frame = np.array(Image.open(path).convert("RGB")).astype(int)
    bright = frame.max(axis=2) > BRIGHT
    
    # Cut shape
    cut = np.zeros((frame.shape[0], frame.shape[1], 4), dtype=np.uint8)
    cut[..., :3] = frame.astype(np.uint8)
    cut[..., 3] = np.where(bright, 255, 0).astype(np.uint8)
    art = Image.fromarray(cut, "RGBA")
    
    new_w = int(round(art.width * scale))
    new_h = int(round(art.height * scale))
    art = art.resize((new_w, new_h), Image.NEAREST)
    
    scaled_grip_x = int(round(GRIP_X * scale))
    scaled_grip_y = int(round(GRIP_Y * scale))
    
    frame_canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    frame_canvas.alpha_composite(art, (CANVAS // 2 - scaled_grip_x, CANVAS // 2 - scaled_grip_y))
    
    sheet.paste(frame_canvas, (i * CANVAS, 0))
    print(f"Frame {fnum} packed at index {i}")

sheet.save(OUT_PNG)
print("Saved", OUT_PNG, sheet.size)
