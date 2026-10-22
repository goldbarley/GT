using Godot;
using System;
using System.Collections.Generic;

public partial class BattleBoard : Control
{
    public MatchSession Session;
    public SoundEffects Sound;
    public bool TileView;
    public bool TrackCamera = true;
    public int CursorRow = -1, CursorCol = -1;
    public System.Collections.Generic.IEnumerable<Node2D> Fighters => actors.Values;
    readonly Node2D world = new();
    Vector2 cameraOffset;
    float cameraScale = 1;
    public Snapshot ReplayFrame;
    public event Action<int, int> TileClicked;
    public event Action<string> TileHovered;
    
    readonly GDScript visualScript = GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd");
    readonly Dictionary<(int, int), Node2D> actors = new();
    readonly List<(Vector2 position, string text, Color color)> damage = new();
    readonly Color blue = new("70d9ef"), red = new("ff9984"), gold = new("edcc88");
    readonly Color pending = new("f0d264"), settled = new("8fd694");
    string loadedTheme = "";
    Snapshot visualBefore, visualAfter;
    float tickElapsed;
    bool impactShown = true;
    public event Action ImpactShown;
    public int DisplayHP(int player, int fighter)
    {
        var frame = ReplayFrame ?? (!impactShown ? visualBefore : visualAfter);
        if (frame != null && Session.Phase is MatchPhase.Combat or MatchPhase.Rewind)
            return player == 0 ? frame.player1CharacterHPs[fighter] : frame.player2CharacterHPs[fighter];
        return BattleEngine.getPlayer((uint)player + 1).getCharacter(fighter).currentHP();
    }
    int Rows => Session?.Map?.GetLength(0) ?? 15;
    int Columns => Session?.Map?.GetLength(1) ?? 13;
    Vector2 origin;
    float zoom, tile, flash;
    readonly System.Collections.Generic.Dictionary<MapElement, Texture2D> tileTextures = new();
    Vector2I hover = new(-1, -1);
    int[,] effects;
    public bool Concealed => Session.Phase == MatchPhase.Menu || Session.Phase == MatchPhase.Handoff;
    public BattleBoard() { ClipContents = true; MouseFilter = MouseFilterEnum.Stop; TextureFilter = TextureFilterEnum.Nearest; }

    public override void _Ready()
    {
        AddChild(world);
        Resized += () => { LayoutMap(); if (Session.Phase != MatchPhase.Combat && Session.Phase != MatchPhase.Rewind) Sync(); };
        LayoutMap();

        MouseExited += () => { hover = new(-1, -1); TileHovered?.Invoke(""); QueueRedraw(); };
    }

    void LoadTileTextures()
    {
        string theme = Session.MapName.StartsWith("Volcanic", StringComparison.OrdinalIgnoreCase) ? "Volcanic Ruins" : "Grasslands";
        if (theme == loadedTheme) return;
        loadedTheme = theme; tileTextures.Clear();
        foreach (var pair in MapPreview.GetTileTexturesForTheme(theme)) tileTextures[pair.Key] = pair.Value;
    }

    void LayoutMap()
    {
        zoom = 1;
        origin = Vector2.Zero;
        tile = 48;
    }

    public Vector2 Center(int row, int col) => origin + new Vector2(col + 0.5f, row + 0.5f) * tile;
    Rect2 Tile(int row, int col) => new(origin + new Vector2(col, row) * tile, Vector2.One * tile);

    public override void _GuiInput(InputEvent input)
    {
        if (Concealed || Session.Map == null || cameraScale <= 0) return;
        Vector2 local = (GetLocalMousePosition() - cameraOffset.Round()) / cameraScale - origin;
        int row = (int)Math.Floor(local.Y / tile), col = (int)Math.Floor(local.X / tile);
        if (row < 0 || row >= Rows || col < 0 || col >= Columns) return;
        if (input is InputEventMouseMotion)
        {
            hover = new Vector2I(col, row);
            string type = Session.Map[row, col] switch { MapElement.W => "Wall / obstacle · blocks movement", MapElement.K => "Chasm · fatal", MapElement.D => "Hazard · damages fighters", _ => "Safe ground" };
            TileHovered?.Invoke($"{col + 1:00} / {row + 1:00}   {type}"); QueueRedraw();
        }
        if (input is InputEventMouseButton mouse && mouse.Pressed && mouse.ButtonIndex == MouseButton.Left)
            TileClicked?.Invoke(row, col);
    }

    public void Reset()
    {
        foreach (var actor in actors.Values) actor.QueueFree();
        actors.Clear(); visualBefore = visualAfter = null; impactShown = true; cameraScale = 0; hover = new(-1, -1); effects = null; damage.Clear(); ReplayFrame = null; QueueRedraw();
    }

    public void Sync()
    {
        if (Session?.Map == null) return;
        LoadTileTextures();
        foreach (var actor in actors.Values) actor.Visible = false;
        if (Concealed) { QueueRedraw(); return; }
        for (int p = 0; p < 2; p++)
            for (int i = 0; i < Session.Rosters[p].Count; i++)
            {
                var key = (p, i);
                if (!actors.TryGetValue(key, out Node2D actor))
                {
                    actor = new Node2D { ProcessMode = ProcessModeEnum.Pausable }; actor.SetScript(visualScript); world.AddChild(actor);
                    actor.Call("configure", (int)Session.Rosters[p][i]);
                    actors[key] = actor;
                }
                var unit = Unit(p, i);
                actor.Call("reset_visual");
                actor.Visible = unit.hp > 0;
                actor.Call("fit_tile", tile);
                actor.Position = Center(unit.at.x, unit.at.y);
                actor.ZIndex = unit.at.x * 2 + 10;
            }
        QueueRedraw();
    }

    (IVector2 at, int hp, int max) Unit(int p, int i)
    {
        CharacterClass c = Session.Rosters[p][i];
        int max = c == CharacterClass.MAGE ? 75 : 120;
        if (ReplayFrame != null)
            return (p == 0 ? ReplayFrame.player1CharacterPositions[i] : ReplayFrame.player2CharacterPositions[i],
                p == 0 ? ReplayFrame.player1CharacterHPs[i] : ReplayFrame.player2CharacterHPs[i], max);
        if (Session.Phase == MatchPhase.Deploy) return (Session.Spawns[p][i], max, max);
        Character unit = BattleEngine.getPlayer((uint)p + 1).getCharacter(i);
        bool hidden = p != Session.Viewer - 1 && (Session.Phase == MatchPhase.Planning || Session.Phase == MatchPhase.Foresight);
        return (hidden ? Session.Spawns[p][i] : unit.currentPosition(), DisplayHP(p, i), max);
    }

    public void PlayTick(Snapshot before, Snapshot after)
    {
        if (actors.Count == 0) Sync();
        visualBefore = before; visualAfter = after; tickElapsed = 0; impactShown = false;
        damage.Clear(); effects = new int[Rows, Columns]; flash = 0;
        for (int p = 0; p < 2; p++)
        {
            int[,] skill = p == 0 ? after.player1SkillGrid : after.player2SkillGrid;
            for (int r = 0; r < Rows; r++) for (int c = 0; c < Columns; c++) effects[r, c] += Math.Abs(skill[r, c]);
            for (int i = 0; i < Session.Rosters[p].Count; i++)
            {
                Node2D actor = actors[(p, i)];
                IVector2 to = p == 0 ? after.player1CharacterPositions[i] : after.player2CharacterPositions[i];
                int hp = p == 0 ? after.player1CharacterHPs[i] : after.player2CharacterHPs[i];
                int oldHp = p == 0 ? before.player1CharacterHPs[i] : before.player2CharacterHPs[i];
                actor.Call("reset_visual");
                actor.Visible = oldHp > 0;
                var from = p == 0 ? before.player1CharacterPositions[i] : before.player2CharacterPositions[i];
                actor.Position = Center(from.x, from.y);
                actor.ZIndex = to.x * 2 + 10;

                if (before.selected[p] == i && oldHp > 0)
                {
                    int slot = before.exchangeTick;
                    int action = slot < before.steps[p][i].Length ? before.steps[p][i][slot] : 0;
                    if (action < 0 && before.cooldowns[p][i][-action - 1] > 1) action = 0;
                    if (action == 5 && before.teleportCooldowns[p][i] > 1) action = 0;
                    int direction = slot < before.directions[p][i].Length ? before.directions[p][i][slot] : 2;
                    IVector2 length = slot < before.lengths[p][i].Length ? before.lengths[p][i][slot] : new IVector2(1, 1);
                    IVector2 target = MatchSession.Move(to, direction, direction <= 2 ? length.x : length.y);
                    actor.Call("perform", action, direction, Center(to.x, to.y), Center(target.x, target.y), (float)Session.TickSeconds);
                    if (action == -1 && Session.Rosters[p][i] == CharacterClass.MAGE) Sound?.Play("fireball", 0.05f);
                    if (action == -4 && Session.Rosters[p][i] == CharacterClass.WARRIOR) Sound?.Play("flame_sword", 0.05f);
                }
            }
        }
        QueueRedraw();
    }

    void PresentImpact()
    {
        impactShown = true; flash = 1;
        bool hurt = false;
        for (int p = 0; p < 2; p++) for (int i = 0; i < Session.Rosters[p].Count; i++)
        {
            int oldHp = p == 0 ? visualBefore.player1CharacterHPs[i] : visualBefore.player2CharacterHPs[i];
            int hp = p == 0 ? visualAfter.player1CharacterHPs[i] : visualAfter.player2CharacterHPs[i];
            if (oldHp == hp) continue;
            var to = p == 0 ? visualAfter.player1CharacterPositions[i] : visualAfter.player2CharacterPositions[i];
            damage.Add((Center(to.x, to.y), hp <= 0 ? "KO" : hp < oldHp ? $"−{oldHp - hp}" : $"+{hp - oldHp}", hp < oldHp ? red : settled));
            actors[(p, i)].Call("react_to_hit", hp <= 0);
            hurt |= hp < oldHp;
        }
        if (hurt) Sound?.Play(KnightBladeSound() ?? "hurt", 0.06f);
        ImpactShown?.Invoke();
    }

    string KnightBladeSound()
    {
        if (visualBefore == null || visualAfter == null) return null;
        for (int p = 0; p < 2; p++)
        {
            int actor = visualBefore.selected[p];
            if (actor < 0 || actor >= Session.Rosters[p].Count) continue;
            if (Session.Rosters[p][actor] != CharacterClass.WARRIOR) continue;
            int slot = visualBefore.exchangeTick;
            int[] steps = visualBefore.steps[p][actor];
            if (slot < 0 || slot >= steps.Length) continue;
            int action = steps[slot];
            if (action < 0 && visualBefore.cooldowns[p][actor][-action - 1] > 1) action = 0;
            // Knight actions: -1 is Slash, -3 is Plunge.
            if (action != -1 && action != -3) continue;

            int[,] grid = p == 0 ? visualAfter.player1SkillGrid : visualAfter.player2SkillGrid;
            if (grid == null) continue;
            for (int i = 0; i < Session.Rosters[1 - p].Count; i++)
            {
                int oldHp = (1 - p) == 0 ? visualBefore.player1CharacterHPs[i] : visualBefore.player2CharacterHPs[i];
                int hp = (1 - p) == 0 ? visualAfter.player1CharacterHPs[i] : visualAfter.player2CharacterHPs[i];
                IVector2 at = (1 - p) == 0 ? visualAfter.player1CharacterPositions[i] : visualAfter.player2CharacterPositions[i];
                if (hp >= oldHp) continue;
                if (at.x >= 0 && at.y >= 0 && at.x < grid.GetLength(0) && at.y < grid.GetLength(1) && grid[at.x, at.y] > 0) return action == -3 ? "plunge" : "sword_hit";
            }
        }
        return null;
    }

    public override void _Process(double delta)
    {
        if (Session?.Map == null || Concealed || Size.X <= 0 || Size.Y <= 0) return;
        if (!GetTree().Paused && !Session.Paused)
        {
            tickElapsed += (float)delta;
            if (!impactShown && tickElapsed >= Session.TickSeconds * 0.58) PresentImpact();
            flash = Math.Max(0, flash - (float)delta / 0.5f);
        }
        Vector2 mapSize = new(Columns * tile, Rows * tile);
        float fit = Math.Min((Size.X - 32) / mapSize.X, (Size.Y - 32) / mapSize.Y);
        float desiredScale = fit;
        Vector2 focus = mapSize / 2;
        if (TrackCamera && Session != null && !Concealed && Session.Phase != MatchPhase.Deploy)
        {
            if (Session.Phase == MatchPhase.Combat || Session.Phase == MatchPhase.Rewind)
            {
                var snapshot = ReplayFrame ?? BattleEngine.getDetails();
                if (actors.TryGetValue((0, snapshot.selected[0]), out var first) && actors.TryGetValue((1, snapshot.selected[1]), out var second))
                {
                    focus = (first.Position + second.Position) / 2;
                    var distance = (first.Position - second.Position).Abs() + new Vector2(240, 240);
                    desiredScale = Math.Min(1.5f, Math.Min(Size.X / distance.X, Size.Y / distance.Y));
                }
            }
            else if (Session.Current != null)
            {
                var at = BattleEngine.previewPosition((uint)Session.Viewer, Session.Fighter, Session.Slot - 1);
                focus = Center(at.x, at.y); desiredScale = 1.35f;
            }
        }
        float blend = 1 - Mathf.Exp(-(float)delta * 5);
        if (cameraScale <= 0) { cameraScale = fit; cameraOffset = Size / 2 - focus * fit; }
        cameraScale = Mathf.Lerp(cameraScale, Math.Max(fit, desiredScale), blend);
        Vector2 halfView = Size / (2 * cameraScale);
        focus.X = mapSize.X <= halfView.X * 2 ? mapSize.X / 2 : Mathf.Clamp(focus.X, halfView.X, mapSize.X - halfView.X);
        focus.Y = mapSize.Y <= halfView.Y * 2 ? mapSize.Y / 2 : Mathf.Clamp(focus.Y, halfView.Y, mapSize.Y - halfView.Y);
        Vector2 desiredOffset = Size / 2 - focus * cameraScale;
        cameraOffset = cameraOffset.Lerp(desiredOffset, blend);
        world.Position = cameraOffset.Round(); world.Scale = Vector2.One * cameraScale;
        foreach (var actor in actors.Values) actor.Call("set_arena_clip", GetGlobalRect());

        QueueRedraw();
    }

    public override void _Draw()
    {
        if (Session?.Map == null || Concealed || zoom <= 0) return;
        
        DrawSetTransform(cameraOffset.Round(), 0, Vector2.One * cameraScale);
        
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Columns; c++)
            {
                Rect2 rect = Tile(r, c);
                MapElement t = Session.Map[r, c];
                if (tileTextures.TryGetValue(t, out Texture2D tex) && tex != null)
                    DrawTextureRect(tex, rect, false, new Color(0.75f, 0.78f, 0.8f));
                else
                    DrawRect(rect, Colors.Gray);
            }
        
        bool deploy = Session.Phase == MatchPhase.Deploy;
        bool planning = Session.Phase == MatchPhase.Planning || Session.Phase == MatchPhase.Foresight;
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Columns; c++)
            {
                Rect2 rect = Tile(r, c);
                if (TileView)
                {
                    Color tint = Session.Map[r, c] switch { MapElement.W => new Color(0.65f, 0.6f, 0.5f, 0.48f), MapElement.K => new Color(0.3f, 0.5f, 1, 0.55f), _ => new Color(0.4f, 0.9f, 0.8f, 0.12f) };
                    DrawRect(rect.Grow(-1), tint);
                }
                if (deploy && Session.Safe(r, c) && (Session.Viewer == 1 ? r < 8 : r >= 8))
                    DrawRect(rect.Grow(-1), new Color(blue, 0.18f));
                DrawRect(rect, new Color(1, 1, 1, TileView ? 0.3f : 0.08f), false, 1);
                if (effects != null && flash > 0 && effects[r, c] != 0 && !planning && !deploy)
                    DrawRect(rect.Grow(-2), new Color(gold, flash * 0.45f));
            }
        if (planning) DrawPlan();
        if (hover.X >= 0) DrawRect(Tile(hover.Y, hover.X).Grow(-1), gold, false, 2);
        foreach (var pair in actors)
        {
            if (!pair.Value.Visible) continue;
            var (p, i) = pair.Key;
            var unit = Unit(p, i);
            DrawCircle(pair.Value.Position + new Vector2(0, tile * 0.34f), tile * 0.3f, new Color(0, 0, 0, 0.28f));
            DrawRect(Tile(unit.at.x, unit.at.y).Grow(-3), new Color(p == 0 ? blue : red, 0.65f), false, 1);
            Vector2 feet = pair.Value.Position + new Vector2(0, tile * 0.48f);
            Color color = p == 0 ? blue : red;
            Vector2 health = pair.Value.Position - new Vector2(tile * 0.4f, tile * 0.58f);
            DrawRect(new Rect2(health - Vector2.One, new Vector2(tile * 0.8f + 2, 6)), new Color("3a2a1b"));
            DrawRect(new Rect2(health, new Vector2(tile * 0.8f * unit.hp / unit.max, 4)), color);
        }
        if (flash > 0)
            foreach (var hit in damage)
                DrawString(GetThemeDefaultFont(), hit.position - new Vector2(10, tile + (1 - flash) * 28), hit.text, HorizontalAlignment.Left, -1, 23, new Color(hit.color, flash));
    }

    void DrawPlan()
    {
        Character unit = Session.Current;
        if (unit == null || !unit.isAlive()) return;
        IVector2 previous = unit.currentPosition();
        for (int i = 0; i < unit.stepCount(); i++)
        {
            if (unit.getStep(i) == 0) break;
            IVector2 next = BattleEngine.previewPosition((uint)Session.Viewer, Session.Fighter, i);
            DrawLine(Center(previous.x, previous.y), Center(next.x, next.y), new Color(settled, 0.55f), 2, true);
            Shade(next, settled);
            previous = next;
        }
        IVector2 from = BattleEngine.previewPosition((uint)Session.Viewer, Session.Fighter, Session.Slot - 1);
        int action = Session.Action;
        if (action >= 1 && action <= 4)
        {
            IVector2 to = MatchSession.Move(from, action, 1);
            Shade(to, pending);
            DrawLine(Center(from.x, from.y), Center(to.x, to.y), new Color(pending, 0.5f), 2, true);
        }
        else if (action == 5)
        {
            Shade(MatchSession.Move(from, Session.Direction, Session.Range), pending);
        }
        else if (action < 0)
        {
            int skill = -action - 1;
            foreach (int distance in MatchSession.SkillRanges(unit.characterClass(), skill))
            {
                if (distance == Session.Range) continue;
                foreach (var cell in SkillCells(unit, skill, Session.Direction, distance)) Dotted(cell);
            }
            foreach (var cell in SkillCells(unit, skill, Session.Direction, Session.Range)) Shade(new IVector2(cell.row, cell.col), pending);
        }
    }

    List<(int row, int col)> SkillCells(Character unit, int skill, int direction, int range)
    {
        var cells = new List<(int, int)>();
        int[,] grid = new int[Rows, Columns];
        IVector2 from = BattleEngine.previewPosition((uint)Session.Viewer, Session.Fighter, Session.Slot - 1);
        SkillTable.skills[(int)unit.characterClass()][skill](from, new IVector2(range, range), MatchSession.Axis(direction), ref grid);
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Columns; c++)
                if (grid[r, c] != 0) cells.Add((r, c));
        return cells;
    }

    void Shade(IVector2 cell, Color color)
    {
        if (cell.x < 0 || cell.y < 0 || cell.x >= Rows || cell.y >= Columns) return;
        Rect2 rect = Tile(cell.x, cell.y).Grow(-2);
        DrawRect(rect, new Color(color, 0.28f));
        DrawRect(rect, color, false, 2);
    }

    void Dotted((int row, int col) cell)
    {
        Rect2 rect = Tile(cell.row, cell.col).Grow(-2);
        var color = new Color(pending, 0.8f);
        for (float x = rect.Position.X; x < rect.End.X; x += 8)
        {
            DrawRect(new Rect2(x, rect.Position.Y, 3, 1), color);
            DrawRect(new Rect2(x, rect.End.Y - 1, 3, 1), color);
        }
        for (float y = rect.Position.Y; y < rect.End.Y; y += 8)
        {
            DrawRect(new Rect2(rect.Position.X, y, 1, 3), color);
            DrawRect(new Rect2(rect.End.X - 1, y, 1, 3), color);
        }
    }
}
