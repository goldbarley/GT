using System;
using Godot;

public partial class ActionTimeline : Control
{
    public int[] Steps = Array.Empty<int>();
    public bool[] Filled = Array.Empty<bool>();
    public int CharacterClass;
    public int SelectedSlot;
    public int PendingStep = int.MinValue;
    private const float Height = 43f;
    private static readonly Color EmptyInk = new("#6b7e83");
    private static readonly Color Highlight = new("#f5dc91");

    public ActionTimeline()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        CustomMinimumSize = new Vector2(290, 330);
        SizeFlagsHorizontal = SizeFlags.ExpandFill;
    }

    public override void _Draw()
    {
        int columns = 3;
        float width = Math.Max(48, (Size.X - 14) / columns);
        Font font = ThemeDB.FallbackFont;
        for (int i = 0; i < Steps.Length; i++)
        {
            int x = i % columns, y = i / columns;
            Rect2 r = new(new Vector2(x * width + 2, y * Height + 4), new Vector2(width - 5, Height - 5));
            bool filled = i < Filled.Length && Filled[i];
            bool preview = i == SelectedSlot && PendingStep != int.MinValue;
            Color ink = filled ? new Color("#6bd5ba") : EmptyInk;
            DrawRect(r, preview ? new Color(Highlight.R, Highlight.G, Highlight.B, .28f) :
                filled ? new Color(ink.R, ink.G, ink.B, .19f) : new Color("#0c1824", .22f));
            DrawRect(r, i == SelectedSlot ? Highlight : new Color(ink.R, ink.G, ink.B, filled ? .8f : .3f), false,
                i == SelectedSlot ? 3f : 1f);
            string caption = preview ? ShortStep(PendingStep) + " ?" : filled ? ShortStep(Steps[i]) : "EMPTY";
            DrawString(font, r.Position + new Vector2(6, 15), $"{i + 1:00}", HorizontalAlignment.Left, -1,
                12, i == SelectedSlot ? Highlight : ink);
            DrawString(font, r.Position + new Vector2(6, 31), caption, HorizontalAlignment.Left, -1,
                12, preview ? Highlight : filled ? new Color("#e2ebd7") : EmptyInk);
        }
    }

    private static string ShortStep(int action) => action switch
    {
        0 => "END", 1 => "UP", 2 => "DOWN", 3 => "LEFT", 4 => "RIGHT", 5 => "WARP",
        < 0 => $"SKILL {-action}", _ => "?"
    };
}
