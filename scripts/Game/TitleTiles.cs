using Godot;
using System;
using System.Collections.Generic;

public partial class TitleTiles : Control
{
    const int TileSize = 80;
    const float ScrollSpeed = 12f;
    const float WalkerSpeed = 38f;
    const float CharacterTileSize = 64f;

    sealed class Walker
    {
        public Node2D Figure;
        public Vector2 WorldPosition;
        public Vector2 Target;
        public Vector2 ShadowOffset;
        public float StuckSeconds;
        public float SpawnDelay;
        public int Facing = 2;
        public bool Initialized;
        public bool Entering;
        public bool WaitingToSpawn;
    }

    readonly List<Texture2D> textures = new();
    readonly List<Walker> walkers = new();
    readonly int[,] pattern = new int[32, 32];
    readonly Random random = new();
    double travel;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        TextureFilter = TextureFilterEnum.Nearest;
        ClipContents = true;
        foreach (string theme in new[] { "Grasslands", "Volcanic Ruins" })
        {
            var tiles = MapPreview.GetTileTexturesForTheme(theme);
            foreach (var type in new[] { MapElement.G, MapElement.W, MapElement.K, MapElement.D })
                textures.Add(tiles[type]);
        }
        for (int row = 0; row < 32; row++)
            for (int col = 0; col < 32; col++)
                pattern[row, col] = random.Next(2) * 4 + (random.Next(4) == 0 ? random.Next(1, 4) : 0);

        for (int kind = 0; kind < 3; kind++)
        {
            int characterKind = kind;
            var figure = new Node2D { ProcessMode = ProcessModeEnum.Always, ZIndex = 1 };
            var walker = new Walker { Figure = figure };
            walkers.Add(walker);
            figure.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd"));
            figure.Visible = false;
            figure.Ready += () =>
            {
                figure.Call("configure", characterKind);
                figure.Call("fit_tile", CharacterTileSize);
                figure.Call("set_menu_walk", true);
                walker.ShadowOffset = (Vector2)figure.Call("get_menu_shadow_offset");
                figure.Visible = !walker.WaitingToSpawn;
            };
            AddChild(figure);
        }
        InitializeWalkers();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationResized)
            InitializeWalkers();
    }

    void InitializeWalkers()
    {
        if (Size.X <= 0 || Size.Y <= 0) return;
        for (int i = 0; i < walkers.Count; i++)
        {
            var walker = walkers[i];
            if (walker.Initialized) continue;
            walker.Initialized = true;
            walker.WaitingToSpawn = true;
            walker.SpawnDelay = (float)random.NextDouble() * 2.4f + i * 1.2f;
            walker.Figure.Visible = false;
        }
    }

    public override void _Process(double delta)
    {
        travel += delta * ScrollSpeed;
        InitializeWalkers();
        foreach (var walker in walkers)
        {
            if (!walker.Initialized) continue;
            if (walker.WaitingToSpawn)
            {
                walker.SpawnDelay -= (float)delta;
                if (walker.SpawnDelay <= 0)
                    RespawnAtRandomBorder(walker);
                else
                    continue;
            }
            if (walker.WorldPosition.DistanceTo(walker.Target) < 0.5f)
            {
                walker.Entering = false;
                SetNextTarget(walker);
            }
            var previous = walker.WorldPosition;
            walker.WorldPosition = walker.WorldPosition.MoveToward(walker.Target, WalkerSpeed * (float)delta);
            if (walker.WorldPosition.DistanceTo(previous) < 0.01f)
                walker.StuckSeconds += (float)delta;
            else
                walker.StuckSeconds = 0;
            walker.Figure.Position = new Vector2(walker.WorldPosition.X, walker.WorldPosition.Y - (float)travel);
            if (walker.Figure.Position.Y > Size.Y + CharacterTileSize || walker.StuckSeconds >= 1.5f)
                ScheduleRespawn(walker);
        }
        QueueRedraw();
    }

    void RespawnAtRandomBorder(Walker walker)
    {
        int columns = Math.Clamp(Mathf.CeilToInt(Size.X / TileSize), 1, 32);
        int firstVisibleRow = Mathf.FloorToInt((float)travel / TileSize);
        var candidates = new List<Vector2I>();
        int border = random.Next(3);
        int firstRow = firstVisibleRow;
        int lastRow = Mathf.CeilToInt(((float)travel + Size.Y) / TileSize);
        for (int row = firstRow; row <= lastRow; row++)
        {
            for (int col = 0; col < columns; col++)
            {
                if (border == 1 && col != 0) continue;
                if (border == 2 && col != columns - 1) continue;
                if (IsSafe(new Vector2I(col, row))) candidates.Add(new Vector2I(col, row));
            }
        }
        if (candidates.Count == 0)
        {
            int col = border == 1 ? 0 : border == 2 ? columns - 1 : random.Next(columns);
            candidates.Add(FindNearestSafeTile(new Vector2I(col, firstVisibleRow)));
        }
        var spawn = candidates[random.Next(candidates.Count)];
        Vector2 entry = TileCenter(spawn);
        walker.WorldPosition = border switch
        {
            0 => entry + new Vector2(0, -CharacterTileSize * 1.25f),
            1 => entry + new Vector2(-CharacterTileSize * 1.25f, 0),
            _ => entry + new Vector2(CharacterTileSize * 1.25f, 0)
        };
        walker.Target = entry;
        walker.Entering = true;
        walker.StuckSeconds = 0;
        walker.WaitingToSpawn = false;
        walker.Figure.Visible = true;
        int facing = border switch { 0 => 2, 1 => 4, _ => 3 };
        if (walker.Facing != facing)
        {
            walker.Facing = facing;
            walker.Figure.Call("set_menu_direction", facing);
            walker.ShadowOffset = (Vector2)walker.Figure.Call("get_menu_shadow_offset");
        }
    }

    void ScheduleRespawn(Walker walker)
    {
        walker.WaitingToSpawn = true;
        walker.SpawnDelay = (float)random.NextDouble() * 1.8f + 0.5f;
        walker.StuckSeconds = 0;
        walker.Figure.Visible = false;
    }

    void SetNextTarget(Walker walker)
    {
        if (walker.Entering) return;
        var current = TileAt(walker.WorldPosition);
        var next = FindNextSafeTile(current);
        if (next == current) return;
        walker.Target = TileCenter(next);
        int facing = next.X < current.X ? 3 : next.X > current.X ? 4 : next.Y < current.Y ? 1 : 2;
        if (facing != walker.Facing)
        {
            walker.Facing = facing;
            walker.Figure.Call("set_menu_direction", facing);
            walker.ShadowOffset = (Vector2)walker.Figure.Call("get_menu_shadow_offset");
        }
    }

    Vector2I FindNextSafeTile(Vector2I start)
    {
        var pending = new Queue<Vector2I>();
        var previous = new Dictionary<Vector2I, Vector2I>();
        var visited = new HashSet<Vector2I> { start };
        pending.Enqueue(start);
        Vector2I goal = start;
        while (pending.Count > 0)
        {
            var tile = pending.Dequeue();
            if (tile.Y > start.Y)
            {
                goal = tile;
                break;
            }
            foreach (var step in new[] { Vector2I.Down, Vector2I.Left, Vector2I.Right, Vector2I.Up })
            {
                var candidate = tile + step;
                if (candidate.X < 0 || candidate.X >= 32 || candidate.Y < start.Y - 32 || candidate.Y > start.Y + 32)
                    continue;
                if (!IsSafe(candidate) || !visited.Add(candidate))
                    continue;
                previous[candidate] = tile;
                pending.Enqueue(candidate);
            }
        }
        if (goal == start) return start;
        while (previous[goal] != start)
            goal = previous[goal];
        return goal;
    }

    Vector2I FindNearestSafeTile(Vector2I origin)
    {
        for (int radius = 0; radius < 32; radius++)
        {
            for (int rowOffset = -radius; rowOffset <= radius; rowOffset++)
            {
                int colOffset = radius - Math.Abs(rowOffset);
                var left = new Vector2I(origin.X - colOffset, origin.Y + rowOffset);
                if (left.X >= 0 && left.X < 32 && IsSafe(left)) return left;
                var right = new Vector2I(origin.X + colOffset, origin.Y + rowOffset);
                if (right != left && right.X >= 0 && right.X < 32 && IsSafe(right)) return right;
            }
        }
        return origin;
    }

    bool IsSafe(Vector2I tile)
    {
        int row = (tile.Y % 32 + 32) % 32;
        int col = (tile.X % 32 + 32) % 32;
        return pattern[row, col] % 4 == 0;
    }

    static Vector2 TileCenter(Vector2I tile) => new((tile.X + 0.5f) * TileSize, (tile.Y + 0.5f) * TileSize);

    static Vector2I TileAt(Vector2 position) =>
        new(Mathf.FloorToInt(position.X / TileSize), Mathf.FloorToInt(position.Y / TileSize));

    public override void _Draw()
    {
        if (textures.Count == 0) return;
        int offset = (int)(travel % (32 * TileSize));
        int firstRow = offset / TileSize;
        for (int row = 0; row < Size.Y / TileSize + 2; row++)
            for (int col = 0; col < Size.X / TileSize + 1; col++)
            {
                var at = new Vector2(col * TileSize, row * TileSize - offset % TileSize);
                DrawTextureRect(textures[pattern[(row + firstRow) % 32, col % 32]], new Rect2(at, Vector2.One * TileSize), false, new Color(0.8f, 0.83f, 0.8f));
            }
        foreach (var walker in walkers)
        {
            if (!walker.Initialized || walker.WaitingToSpawn || !walker.Figure.Visible) continue;
            var center = new Vector2(walker.WorldPosition.X, walker.WorldPosition.Y - (float)travel) + walker.ShadowOffset;
            var points = new Vector2[20];
            for (int i = 0; i < points.Length; i++)
            {
                float angle = Mathf.Tau * i / points.Length;
                points[i] = center + new Vector2(Mathf.Cos(angle) * 17f, Mathf.Sin(angle) * 5f);
            }
            DrawColoredPolygon(points, new Color(0.08f, 0.06f, 0.04f, 0.42f));
        }
    }
}
