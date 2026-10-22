import os
from PIL import Image, ImageDraw, ImageFont

out_dir = "/home/stark/.gemini/antigravity/brain/9c327554-3d68-4656-8b31-6be9c7767fc3/archer_godray_comparison"
sample_frames = [36, 45, 52, 65, 78, 79, 80, 85, 92]

for f in sample_frames:
    ref_path = f"/home/stark/archer_godray/frames_native/frame_{f:04d}.png"
    new_path = f"{out_dir}/new_frame_{f:04d}.png"
    
    if not os.path.exists(ref_path) or not os.path.exists(new_path):
        continue
        
    ref_img = Image.open(ref_path).convert("RGBA")
    new_img = Image.open(new_path).convert("RGBA")
    
    # Target height 400
    target_h = 400
    # Ref native is 240x135 -> scale to height 400: width = int(240 * (400/135)) = 711
    ref_w = int(240 * (target_h / 135.0))
    ref_scaled = ref_img.resize((ref_w, target_h), Image.NEAREST)
    
    # New img is 914x520 or 1280x720 -> crop and scale to same height
    new_scaled = new_img.resize((int(new_img.width * (target_h / float(new_img.height))), target_h), Image.BILINEAR)
    
    total_w = ref_w + new_scaled.width
    comp = Image.new("RGBA", (total_w, target_h + 35), (20, 22, 28, 255))
    
    comp.paste(ref_scaled, (0, 35))
    comp.paste(new_scaled, (ref_w, 35))
    
    draw = ImageDraw.Draw(comp)
    draw.text((15, 10), f"DESIRED REFERENCE (Video Frame {f})", fill=(100, 255, 120, 255))
    draw.text((ref_w + 15, 10), f"OUR GODOT RIG (Updated Frame {f})", fill=(255, 215, 80, 255))
    
    comp_path = f"{out_dir}/updated_comp_frame_{f:04d}.png"
    comp.save(comp_path)
    print(f"Generated {comp_path}")

