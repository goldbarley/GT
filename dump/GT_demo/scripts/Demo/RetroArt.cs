using System;
using Godot;

public partial class RetroArt : Control
{
    public bool Quiet { get; set; }
    public override void _Draw()
    {
        DrawRect(new Rect2(Vector2.Zero, Size), new Color("#0a1020"));
        float w = Size.X, h = Size.Y;
        DrawRect(new Rect2(0, h * .55f, w, h * .45f), new Color("#111c30"));
        for (int i = 0; i < 90; i++)
        {
            float x = (i * 157 + 31) % Math.Max(1, (int)w);
            float y = (i * 109 + 49) % Math.Max(1, (int)(h * .62f));
            int pixel = i % 8 == 0 ? 4 : 2;
            DrawRect(new Rect2(x, y, pixel, pixel), i % 5 == 0 ? new Color("#f4d48c") : new Color("#526c83"));
        }
        if (Quiet) return;
        float baseLine = h * .78f;
        for (int i = 0; i <= (int)(w / 28) + 2; i++)
        {
            float x = i * 28;
            float rise = (i * 37 % 5) * 11;
            DrawRect(new Rect2(x, baseLine - rise, 26, h - baseLine + rise), new Color("#172a37"));
            if (i % 3 == 0) DrawRect(new Rect2(x + 8, baseLine - rise + 20, 5, 9), new Color("#d6a56e"));
        }
        DrawRect(new Rect2(0, h * .93f, w, h * .07f), new Color("#253745"));
        DrawRect(new Rect2(0, h * .93f, w, 4), new Color("#526874"));
        for (int j = 0; j < 16; j++)
            DrawRect(new Rect2((j * 163) % Math.Max(1, (int)w), h * .93f + 10 + (j % 3) * 8, 15, 3), new Color("#1d2e3a"));
    }
}

