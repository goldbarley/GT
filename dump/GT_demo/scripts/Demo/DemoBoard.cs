using System;
using Godot;

public partial class DemoBoard : Control
{
    public DemoView View { get; set; }
    public Action<int, int> CellClicked;
    public Action<int, int> TargetClicked;
    public Action<int, int> ReplayTileClicked;
    public bool ShowUsedTiles, RewindChoiceMode;
    public int RewindTick = -1, RewindSelectedRow = -1, RewindSelectedCol = -1;
    public int CursorRow = -1, CursorCol = -1;
    public int PendingStep = int.MinValue, PendingDirection = 1, PendingRange = 1, PendingSlot;
    public bool ShowPlanningPreview;
    public bool ShowDeployment;
    public int ActiveCharacter;
    public bool[] Committed = Array.Empty<bool>();
    private static readonly Color Ink = new("#dce7d4");
    private static readonly Color Cyan = new("#65d6bb");
    private static readonly Color Ember = new("#ffae74");
    private static readonly Color Highlight = new("#f7df96");
    private Vector2 origin;
    private float cell;
    private int hoverRow = -1, hoverCol = -1;

    public DemoBoard()
    {
        MouseFilter = MouseFilterEnum.Stop;
        CustomMinimumSize = new Vector2(450, 450);
        SizeFlagsHorizontal = SizeFlags.ExpandFill;
        SizeFlagsVertical = SizeFlags.ExpandFill;
    }

    public override void _Draw()
    {
        DrawRect(new Rect2(Vector2.Zero, Size), new Color("#101925"));
        for (int i = 0; i < Size.Y / 10; i++)
            DrawLine(new Vector2(0, i * 10 + 1), new Vector2(Size.X, i * 10 + 1), new Color("#182634"), 1);
        if (View?.Map == null || View.Map.Length == 0) return;
        int rows = View.Map.Length, cols = View.Map[0].Length;
        cell = Mathf.Floor(Mathf.Min((Size.X - 50) / cols, (Size.Y - 56) / rows));
        if (cell < 12) return;
        origin = ((Size - new Vector2(cols * cell, rows * cell)) / 2).Floor();
        Font font = ThemeDB.FallbackFont;
        DrawRect(new Rect2(origin - new Vector2(9, 9), new Vector2(cols * cell + 18, rows * cell + 18)), new Color("#060b14"));
        DrawRect(new Rect2(origin - new Vector2(5, 5), new Vector2(cols * cell + 10, rows * cell + 10)), new Color("#789089"), false, 3);
        for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
        {
            Vector2 p = origin + new Vector2(c, r) * cell;
            Rect2 tile = new(p, new Vector2(cell - 1, cell - 1));
            Color ground = ((r + c) & 1) == 0 ? new Color("#29483d") : new Color("#305044");
            switch (View.Map[r][c])
            {
                case 1:
                    DrawRect(tile, new Color("#263742"));
                    DrawRect(new Rect2(p + new Vector2(2, 2), new Vector2(cell - 5, cell - 8)), new Color("#65747c"));
                    DrawRect(new Rect2(p + new Vector2(4, 4), new Vector2(cell - 9, 4)), new Color("#95a49b"));
                    DrawRect(new Rect2(p + new Vector2(3, cell - 5), new Vector2(cell - 7, 3)), new Color("#374955"));
                    break;
                case 3:
                    DrawRect(tile, new Color("#151728"));
                    DrawRect(tile.Grow(-3), new Color("#29263a"), false, 2);
                    DrawRect(new Rect2(p + new Vector2(cell / 2 - 3, cell / 2 - 3), new Vector2(6, 6)), new Color("#9f5264"));
                    break;
                case 2:
                    DrawRect(tile, new Color("#6b4343"));
                    DrawRect(new Rect2(p + new Vector2(5, 5), new Vector2(cell - 10, cell - 10)), new Color("#9d5946"), false, 2);
                    break;
                default:
                    DrawRect(tile, ground);
                    if ((r * 7 + c * 11) % 5 == 0)
                        DrawRect(new Rect2(p + new Vector2(cell - 9, 7), new Vector2(3, 4)), new Color("#4d6b51"));
                    break;
            }
            if (r < (rows + 1) / 2)
                DrawRect(new Rect2(p, new Vector2(3, cell - 1)), new Color(Cyan.R, Cyan.G, Cyan.B, 0.38f));
            else DrawRect(new Rect2(p + new Vector2(cell - 4, 0), new Vector2(3, cell - 1)), new Color(Ember.R, Ember.G, Ember.B, 0.38f));
            if (ShowDeployment)
            {
                bool ownHalf = View.Player == 1 ? r < (rows + 1) / 2 : r >= (rows + 1) / 2;
                bool legal = ownHalf && View.Map[r][c] != 1 && View.Map[r][c] != 3;
                if (legal) DrawRect(tile.Grow(-2), new Color(.28f, .95f, .65f, .09f));
                else DrawRect(tile.Grow(-1), new Color(.10f, .10f, .18f, .42f));
                if (r == hoverRow && c == hoverCol)
                    DrawRect(tile.Grow(-3), legal ? new Color(.42f, 1f, .72f) : new Color(1f, .36f, .38f), false, 3);
            }
            else if (r == hoverRow && c == hoverCol)
                DrawRect(tile.Grow(-2), new Color(1, 1, 1, .12f));
        }
        DrawLine(new Vector2(origin.X, origin.Y + ((rows + 1) / 2) * cell),
            new Vector2(origin.X + cols * cell, origin.Y + ((rows + 1) / 2) * cell), Highlight, 2);
        if (ShowUsedTiles) DrawExchangeFootprints();
        if (ShowPlanningPreview)
        {
            if (!RewindChoiceMode) DrawSavedOverlay(rows, cols);
            DrawPreview(rows, cols);
        }
        foreach (DemoUnit unit in View.Units)
        {
            if (!Valid(unit.Row, unit.Col)) continue;
            Vector2 p = origin + new Vector2(unit.Col, unit.Row) * cell;
            Color color = unit.Player == 1 ? Cyan : Ember;
            int stacks = 0;
            foreach (DemoUnit other in View.Units)
                if (other.Player == unit.Player && other.Index < unit.Index && other.Row == unit.Row && other.Col == unit.Col) stacks++;
            Rect2 body = new(p + new Vector2(5 + stacks * 5, 5 + stacks * 5),
                new Vector2(cell - 11 - stacks * 5, cell - 12 - stacks * 5));
            if (unit.LivePosition)
            {
                DrawRect(new Rect2(body.Position + new Vector2(3, 4), body.Size), new Color("#0b1320"));
                DrawRect(body, new Color("#142734"));
                DrawRect(body.Grow(-3), color);
                DrawRect(new Rect2(body.Position + new Vector2(7, 7), new Vector2(5, 5)), new Color("#fff0c3"));
                DrawRect(new Rect2(body.End - new Vector2(12, 12), new Vector2(5, 5)), new Color("#fff0c3"));
            }
            else
            {
                DrawRect(body, new Color(color.R, color.G, color.B, .14f));
                DrawRect(body, color, false, 3);
            }
            string glyph = unit.Class switch { 0 => "M", 1 => "K", 2 => "A", 3 => "O", _ => "?" };
            int fs = (int)Math.Max(12, cell * .36f);
            DrawString(font, body.Position + new Vector2(body.Size.X / 2 - fs * .32f, body.Size.Y / 2 + fs * .30f),
                glyph, HorizontalAlignment.Left, -1, fs, unit.LivePosition ? new Color("#091925") : color);
            if (unit.Player == View.Player && unit.Index == ActiveCharacter && ShowPlanningPreview)
                DrawRect(body.Grow(2), Highlight, false, 2);
            if (unit.LivePosition && unit.Hp >= 0)
            {
                Rect2 hp = new(p + new Vector2(3, cell - 7), new Vector2(cell - 6, 4));
                DrawRect(hp, new Color("#111b28"));
                DrawRect(new Rect2(hp.Position, new Vector2(hp.Size.X * Mathf.Clamp((float)unit.Hp / Math.Max(1, unit.MaxHp), 0f, 1f), 4)), color);
            }
        }
        if (CursorRow >= 0 && Valid(CursorRow, CursorCol))
        {
            Vector2 pos = origin + new Vector2(CursorCol, CursorRow) * cell;
            DrawRect(new Rect2(pos + Vector2.One * 2, Vector2.One * (cell - 5)), Highlight, false, 4);
            DrawRect(new Rect2(pos + new Vector2(cell / 2 - 2, cell / 2 - 2), new Vector2(4, 4)), Highlight);
        }
        DrawString(font, origin + new Vector2(0, -15), "NORTH / PLAYER 1", HorizontalAlignment.Left, -1, 14, Cyan);
        DrawString(font, origin + new Vector2(0, rows * cell + 24), "SOUTH / PLAYER 2", HorizontalAlignment.Left, -1, 14, Ember);
        DrawString(font, origin + new Vector2(cols * cell - 85, rows * cell + 24), "SKY ISLAND", HorizontalAlignment.Left, -1, 12, Ink);
    }

    private void DrawExchangeFootprints()
    {
        if (View?.UsedTiles == null) return;
        var groups = new System.Collections.Generic.Dictionary<Vector2I, DemoUsedTile>();
        foreach (DemoUsedTile tile in View.UsedTiles)
        {
            Vector2I key = new(tile.Row, tile.Col);
            if (!groups.TryGetValue(key, out DemoUsedTile old) || tile.Tick > old.Tick ||
                (tile.Tick == old.Tick && tile.Kind > old.Kind)) groups[key] = tile;
        }
        Font font = ThemeDB.FallbackFont;
        foreach (var item in groups)
        {
            DemoUsedTile trace = item.Value;
            if (!Valid(trace.Row, trace.Col)) continue;
            Rect2 rect = CellRect(trace.Row, trace.Col).Grow(-2);
            bool chosen = trace.Row == RewindSelectedRow && trace.Col == RewindSelectedCol;
            bool hover = trace.Row == hoverRow && trace.Col == hoverCol && RewindChoiceMode;
            Color ink = trace.Kind == 1 ? new Color("#f6ad78") :
                trace.Owner == 1 ? new Color("#78ead0") : new Color("#e9b187");
            DrawRect(rect, new Color(ink.R, ink.G, ink.B, chosen ? .36f : hover ? .30f : .19f));
            DrawDottedRect(rect.Grow(-2), chosen ? Highlight : ink, chosen ? 4 : 3);
            DrawString(font, rect.Position + new Vector2(4, 13), $"T{trace.Tick + 1:00}",
                HorizontalAlignment.Left, -1, 10, Highlight);
        }
    }

    public static (int Minimum, int Maximum) RangeFor(int characterClass, int skill, int rows, int cols)
    {
        int full = Math.Max(rows, cols);
        return (characterClass, skill) switch
        {
            (0, 1) => (1, full),
            (0, 2) => (0, 0),
            (0, 3) => (1, full),
            (0, 4) => (4, 4),
            (1, 1) => (1, 1),
            (1, 2) => (2, 2),
            (1, 3) => (2, 3),
            (1, 4) => (2, 2),
            (1, 5) => (0, 0),
            (2, 1) => (3, 3),
            (2, 2) => (4, 5),
            (2, 3) => (1, full),
            (3, 1) => (1, full),
            (3, 2) => (1, full),
            (3, 3) => (0, 0),
            _ => (1, full)
        };
    }

    private static bool SelfTargeted(int characterClass, int skill) =>
        (characterClass == 0 && (skill == 2 || skill == 4)) ||
        (characterClass == 1 && skill == 5) || (characterClass == 3 && skill == 3);

    public bool TryGetAimOrigin(out int row, out int col)
    {
        row = col = -1;
        if (View?.Map == null || View.Units == null) return false;
        if (RewindChoiceMode && RewindTick >= 0 &&
            RewindTick < View.RewindOrigins.Length && View.RewindOrigins[RewindTick].Length >= View.Player * 2)
        {
            row = View.RewindOrigins[RewindTick][(View.Player - 1) * 2];
            col = View.RewindOrigins[RewindTick][(View.Player - 1) * 2 + 1];
            return Valid(row, col);
        }
        DemoUnit own = null;
        foreach (DemoUnit unit in View.Units)
            if (unit.Player == View.Player && unit.Index == ActiveCharacter && unit.LivePosition)
            { own = unit; break; }
        if (own == null) return false;
        row = own.Row; col = own.Col;
        int limit = Math.Min(PendingSlot, View.Steps.Length);
        for (int slot = 0; slot < limit; slot++)
        {
            if (slot >= Committed.Length || !Committed[slot]) break;
            int action = View.Steps[slot];
            if (action == 0) break;
            if (action < 1 || action > 5) continue;
            int direction = action == 5 ? View.Directions[slot] : action;
            (int dr, int dc) = Delta(direction);
            int distance = action == 5 ? Math.Max(1, View.Ranges[slot]) : 1;
            int newRow = row + dr * distance, newCol = col + dc * distance;
            if (action == 5 ? !Valid(newRow, newCol) : !Passable(newRow, newCol)) break;
            row = newRow; col = newCol;
            if (View.Map[row][col] == 3) break;
        }
        return Valid(row, col);
    }

    public bool TryAimAt(int row, int col, out int direction, out int distance, out string reason)
    {
        direction = PendingDirection;
        distance = PendingRange;
        reason = "Select an ability on the numpad first.";
        if (PendingStep >= 0 || PendingStep == int.MinValue || !ShowPlanningPreview) return false;
        if (!Valid(row, col) || !TryGetAimOrigin(out int casterRow, out int casterCol))
        { reason = "Select a tile within the battlefield."; return false; }
        int characterClass = View.TeamClasses[View.Player - 1][ActiveCharacter];
        int skill = -PendingStep;
        if (characterClass == 0 && skill == 4)
        {
            int deltaRow = Math.Abs(row - casterRow), deltaCol = Math.Abs(col - casterCol);
            if (deltaRow == 0 || deltaRow != deltaCol || deltaRow > 4)
            { reason = "Quad Beam hits the four diagonals up to four tiles away."; return false; }
            direction = 1; distance = 4;
            return true;
        }
        if (SelfTargeted(characterClass, skill))
        {
            if (row != casterRow || col != casterCol)
            { reason = "This ability is centered on your character. Click their square."; return false; }
            direction = 1;
            distance = Math.Max(1, RangeFor(characterClass, skill, View.Map.Length, View.Map[0].Length).Maximum);
            return true;
        }
        int differenceR = row - casterRow, differenceC = col - casterCol;
        if ((differenceR == 0) == (differenceC == 0))
        { reason = "Aim along a straight row or column; diagonal aiming is not supported."; return false; }
        direction = differenceR < 0 ? 1 : differenceR > 0 ? 2 : differenceC < 0 ? 3 : 4;
        distance = Math.Abs(differenceR) + Math.Abs(differenceC);
        (int minimum, int maximum) = RangeFor(characterClass, skill, View.Map.Length, View.Map[0].Length);
        if (distance < minimum || distance > maximum)
        { reason = $"This ability targets {minimum}{(minimum == maximum ? "" : $"–{maximum}")} tiles away."; return false; }
        if (characterClass == 2 && skill == 2) distance = 5; // Double Shot always hits tiles four and five.
        if (characterClass == 2 && skill == 3) distance = maximum; // Piercing shot reaches the map edge.
        return true;
    }

    private static System.Collections.Generic.List<Vector2I> SkillCells(int characterClass, int skill,
        int row, int col, int direction, int range, int rows, int cols)
    {
        var cells = new System.Collections.Generic.List<Vector2I>();
        (int dr, int dc) = Delta(direction);
        void Add(int r, int c)
        {
            if (r >= 0 && r < rows && c >= 0 && c < cols) cells.Add(new Vector2I(r, c));
        }
        if (SelfTargeted(characterClass, skill))
        {
            if (characterClass == 0 && skill == 4)
            {
                for (int i = 1; i <= 4; i++)
                    foreach (int sr in new[] { -1, 1 })
                        foreach (int sc in new[] { -1, 1 }) Add(row + sr * i, col + sc * i);
            }
            else Add(row, col);
            return cells;
        }
        if (characterClass == 2 && skill == 3)
        {
            for (int i = 1; i <= Math.Max(rows, cols); i++) Add(row + dr * i, col + dc * i);
            return cells;
        }
        if (characterClass == 2 && skill == 2)
        {
            Add(row + dr * 4, col + dc * 4);
            Add(row + dr * 5, col + dc * 5);
            return cells;
        }
        int impactRange = (characterClass, skill) switch
        {
            (1, 1) => 1, (1, 2) => 2, (1, 4) => 2, (2, 1) => 3,
            (1, 3) => range >= 3 ? 3 : 2,
            _ => Math.Max(1, range)
        };
        int targetR = row + dr * impactRange, targetC = col + dc * impactRange;
        bool area = (characterClass == 0 && skill == 3) || (characterClass == 1 && skill == 3) ||
                    (characterClass == 3 && skill == 2);
        if (area)
            for (int rr = -1; rr <= 1; rr++)
                for (int cc = -1; cc <= 1; cc++) Add(targetR + rr, targetC + cc);
        else Add(targetR, targetC);
        return cells;
    }

    private void DrawSavedOverlay(int rows, int cols)
    {
        if (!TryGetUnit(out DemoUnit own)) return;
        int row = own.Row, col = own.Col;
        for (int slot = 0; slot < View.Steps.Length && slot < Committed.Length; slot++)
        {
            if (!Committed[slot]) break;
            int step = View.Steps[slot];
            if (step == 0) break;
            int direction = step is >= 1 and <= 4 ? step : View.Directions[slot];
            (int dr, int dc) = Delta(direction);
            int distance = step == 5 ? Math.Max(1, View.Ranges[slot]) : 1;
            if (step > 0)
            {
                int nextR = row + dr * distance, nextC = col + dc * distance;
                if (!Valid(nextR, nextC) || (step != 5 && !Passable(nextR, nextC))) continue;
                DrawRect(CellRect(nextR, nextC).Grow(-cell * .22f), new Color(.43f, .88f, .69f, .19f));
                DrawRect(CellRect(nextR, nextC).Grow(-cell * .22f), new Color(.43f, .88f, .69f, .32f), false, 1);
                row = nextR; col = nextC;
            }
            else
                foreach (Vector2I target in SkillCells(own.Class, -step, row, col, direction,
                    Math.Max(1, View.Ranges[slot]), rows, cols)) GhostCell(target.X, target.Y);
            if (View.Map[row][col] == 3) break;
        }
    }

    private bool TryGetUnit(out DemoUnit own)
    {
        own = null;
        if (View?.Units == null) return false;
        foreach (DemoUnit unit in View.Units)
            if (unit.Player == View.Player && unit.Index == ActiveCharacter && unit.LivePosition)
            { own = unit; return true; }
        return false;
    }

    private void GhostCell(int row, int col)
    {
        if (Valid(row, col)) DrawRect(CellRect(row, col).Grow(-cell * .28f), new Color(.98f, .66f, .35f, .18f));
    }

    private void DrawPreview(int rows, int cols)
    {
        if (!TryGetAimOrigin(out int row, out int col)) return;
        int currentClass = View.TeamClasses[View.Player - 1][ActiveCharacter];
        DrawRect(CellRect(row, col).Grow(-3), new Color("#d9edb3"), false, 2);
        if (PendingStep == int.MinValue) return;
        int direction = PendingStep is >= 1 and <= 4 ? PendingStep : PendingDirection;
        (int dr, int dc) = Delta(direction);
        if (PendingStep == 0) { DrawRect(CellRect(row, col).Grow(-7), Highlight, false, 3); return; }
        if (PendingStep > 0)
        {
            int amount = PendingStep == 5 ? PendingRange : 1;
            int nextR = row + dr * amount, nextC = col + dc * amount;
            PaintPreviewCell(nextR, nextC, PendingStep == 5 || Passable(nextR, nextC) ? Highlight : new Color("#e46d76"));
            return;
        }
        int skill = -PendingStep;
        (int minimum, int maximum) = RangeFor(currentClass, skill, rows, cols);
        DrawCastRange(currentClass, skill, row, col, minimum, maximum, rows, cols);
        var affected = SkillCells(currentClass, skill, row, col, direction, PendingRange, rows, cols);
        foreach (Vector2I tile in affected) PaintPreviewCell(tile.X, tile.Y, new Color("#f5b679"));
        DrawImpactOutline(affected, new Color("#ffdb93"));
        if (hoverRow >= 0 && hoverCol >= 0 && TryAimAt(hoverRow, hoverCol,
            out int hoverDirection, out int hoverRange, out _))
        {
            var hoverCells = SkillCells(currentClass, skill, row, col, hoverDirection, hoverRange, rows, cols);
            foreach (Vector2I tile in hoverCells)
                DrawRect(CellRect(tile.X, tile.Y).Grow(-5), new Color(.78f, .91f, 1f, .18f));
            DrawImpactOutline(hoverCells, new Color("#bdeaff"));
        }
    }

    private void DrawCastRange(int characterClass, int skill, int row, int col, int minimum, int maximum, int rows, int cols)
    {
        Color dots = new(.62f, .88f, .95f, .8f);
        if (characterClass == 0 && skill == 4)
        {
            for (int distance = 1; distance <= 4; distance++)
                foreach (int rowSign in new[] { -1, 1 })
                    foreach (int colSign in new[] { -1, 1 })
                    {
                        int rr = row + rowSign * distance, cc = col + colSign * distance;
                        if (!Valid(rr, cc)) continue;
                        Vector2 center = CellRect(rr, cc).GetCenter();
                        DrawRect(new Rect2(center - Vector2.One * 2, Vector2.One * 4), dots);
                    }
            return;
        }
        if (minimum == 0 && maximum == 0)
        {
            DrawDottedRect(CellRect(row, col).Grow(-1), dots);
            return;
        }
        if (minimum == maximum && maximum <= 5)
        {
            Rect2 frame = new(origin + new Vector2(col - maximum, row - maximum) * cell,
                new Vector2((2 * maximum + 1) * cell, (2 * maximum + 1) * cell));
            DrawDottedRect(frame, dots);
        }
        for (int dir = 1; dir <= 4; dir++)
        {
            (int dr, int dc) = Delta(dir);
            for (int d = Math.Max(1, minimum); d <= maximum; d++)
            {
                int rr = row + dr * d, cc = col + dc * d;
                if (!Valid(rr, cc)) break;
                Rect2 tile = CellRect(rr, cc);
                DrawRect(new Rect2(tile.GetCenter() - Vector2.One * 2, Vector2.One * 4), dots);
            }
        }
    }

    private void DrawImpactOutline(System.Collections.Generic.List<Vector2I> affected, Color color)
    {
        if (affected.Count == 0) return;
        int minR = int.MaxValue, maxR = int.MinValue, minC = int.MaxValue, maxC = int.MinValue;
        foreach (Vector2I tile in affected)
        {
            minR = Math.Min(minR, tile.X); maxR = Math.Max(maxR, tile.X);
            minC = Math.Min(minC, tile.Y); maxC = Math.Max(maxC, tile.Y);
        }
        if (affected.Count > 1 && affected.Count == (maxR - minR + 1) * (maxC - minC + 1))
        {
            Rect2 footprint = new(origin + new Vector2(minC, minR) * cell + Vector2.One * 3,
                new Vector2((maxC - minC + 1) * cell - 7, (maxR - minR + 1) * cell - 7));
            DrawDottedRect(footprint, color, 5);
        }
        else
            foreach (Vector2I tile in affected) DrawDottedRect(CellRect(tile.X, tile.Y).Grow(-3), color, 4);
    }

    private void DrawDottedRect(Rect2 rect, Color color, float dash = 6f)
    {
        float unit = Math.Max(2f, dash);
        for (float x = rect.Position.X; x < rect.End.X; x += unit * 2)
        {
            float end = Math.Min(x + unit, rect.End.X);
            DrawLine(new Vector2(x, rect.Position.Y), new Vector2(end, rect.Position.Y), color, 2);
            DrawLine(new Vector2(x, rect.End.Y), new Vector2(end, rect.End.Y), color, 2);
        }
        for (float y = rect.Position.Y; y < rect.End.Y; y += unit * 2)
        {
            float end = Math.Min(y + unit, rect.End.Y);
            DrawLine(new Vector2(rect.Position.X, y), new Vector2(rect.Position.X, end), color, 2);
            DrawLine(new Vector2(rect.End.X, y), new Vector2(rect.End.X, end), color, 2);
        }
    }

    private bool Valid(int r, int c) => View?.Map != null && r >= 0 && r < View.Map.Length && c >= 0 && c < View.Map[0].Length;
    private bool Passable(int r, int c) => Valid(r, c) && View.Map[r][c] != 1;
    private Rect2 CellRect(int r, int c) => new(origin + new Vector2(c, r) * cell, new Vector2(cell - 1, cell - 1));
    private void PaintPreviewCell(int r, int c, Color color)
    {
        if (!Valid(r, c)) return;
        Rect2 rect = CellRect(r, c).Grow(-4);
        DrawRect(rect, new Color(color.R, color.G, color.B, .28f));
        DrawRect(rect, color, false, 3);
    }
    private static (int, int) Delta(int dir) => dir switch { 1 => (-1, 0), 2 => (1, 0), 3 => (0, -1), 4 => (0, 1), _ => (0, 0) };

    public override void _GuiInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion motion)
        {
            Locate(motion.Position, out hoverRow, out hoverCol);
            QueueRedraw();
        }
        if (@event is InputEventMouseButton button && button.Pressed && button.ButtonIndex == MouseButton.Left)
        {
            Locate(button.Position, out int row, out int col);
            if (row < 0) return;
            if (ShowDeployment)
            {
                if (IsLegalSpawn(row, col)) CellClicked?.Invoke(row, col);
            }
            else if (RewindChoiceMode && RewindTick < 0)
                ReplayTileClicked?.Invoke(row, col);
            else if (ShowPlanningPreview && PendingStep < 0 && PendingStep != int.MinValue)
                TargetClicked?.Invoke(row, col);
            else if (RewindChoiceMode)
                ReplayTileClicked?.Invoke(row, col);
        }
    }

    private bool IsLegalSpawn(int row, int col)
    {
        if (!Valid(row, col)) return false;
        int middle = (View.Map.Length + 1) / 2;
        return (View.Player == 1 ? row < middle : row >= middle) &&
            View.Map[row][col] != 1 && View.Map[row][col] != 3;
    }

    private void Locate(Vector2 point, out int row, out int col)
    {
        row = col = -1;
        if (View?.Map == null || View.Map.Length == 0 || cell <= 0) return;
        Vector2 delta = point - origin;
        int c = Mathf.FloorToInt(delta.X / cell), r = Mathf.FloorToInt(delta.Y / cell);
        if (Valid(r, c)) { row = r; col = c; }
    }
}
