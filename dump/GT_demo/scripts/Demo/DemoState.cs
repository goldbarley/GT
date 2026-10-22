using System;

public sealed class DemoUnit
{
    public int Player { get; set; }
    public int Class { get; set; }
    public int Index { get; set; }
    public int Row { get; set; }
    public int Col { get; set; }
    public int Hp { get; set; }
    public int MaxHp { get; set; }
    public bool LivePosition { get; set; }
}

public sealed class DemoUsedTile
{
    public int Tick { get; set; }
    public int Row { get; set; }
    public int Col { get; set; }
    public int Owner { get; set; }
    public int Kind { get; set; }
}

public sealed class DemoView
{
    public int Player { get; set; }
    public int[][] Map { get; set; } = Array.Empty<int[]>();
    public DemoUnit[] Units { get; set; } = Array.Empty<DemoUnit>();
    public bool[] Configured { get; set; } = new bool[2];
    public bool[] Locked { get; set; } = new bool[2];
    public bool[] Selected { get; set; } = new bool[2];
    public int[] Perks { get; set; } = new int[] { -1, -1 };
    public int[] DraftPerks { get; set; } = new[] { 0, 1 };
    public int[] Classes { get; set; } = new int[] { -1, -1 };
    public int[][] TeamClasses { get; set; } = new[] { Array.Empty<int>(), Array.Empty<int>() };
    public int[][] TeamSteps { get; set; } = Array.Empty<int[]>();
    public int[][] TeamDirections { get; set; } = Array.Empty<int[]>();
    public int[][] TeamRanges { get; set; } = Array.Empty<int[]>();
    public bool[][] TeamCommitted { get; set; } = Array.Empty<bool[]>();
    public int[] SelectedIndices { get; set; } = new[] { -1, -1 };
    public int PlanningTurn { get; set; } = 1;
    public float FutureSightSeconds { get; set; }
    public int[] Steps { get; set; } = Array.Empty<int>();
    public int[] Directions { get; set; } = Array.Empty<int>();
    public int[] Ranges { get; set; } = Array.Empty<int>();
    public bool Active { get; set; }
    public bool RewindPending { get; set; }
    public bool Replaying { get; set; }
    public DemoUsedTile[] UsedTiles { get; set; } = Array.Empty<DemoUsedTile>();
    public int[][] RewindOrigins { get; set; } = Array.Empty<int[]>();
    public bool FutureSight { get; set; }
    public bool CanSelect { get; set; }
    public int DefyOwner { get; set; }
    public int Tick { get; set; }
    public int ExchangeTick { get; set; }
    public int Exchange { get; set; }
    public int Cycle { get; set; }
    public int Outcome { get; set; }
    public string Intel { get; set; } = "";
    public string Message { get; set; } = "";
}

public sealed class DemoCommand
{
    public int Row { get; set; }
    public int Col { get; set; }
    public int Class { get; set; }
    public int Perk { get; set; }
    public int CharacterIndex { get; set; }
    public int Slot { get; set; }
    public int Step { get; set; }
    public int Direction { get; set; } = 1;
    public int Range { get; set; } = 1;
}
