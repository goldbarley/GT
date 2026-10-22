using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Godot;

public partial class DemoMain : Control
{
    private static readonly string[][] SkillNames =
    {
        new[] { "Fireball", "Shield", "Meteorite", "Quad Beam" },
        new[] { "Slash", "Stab", "Plunge", "Knight's Edge", "Shield" },
        new[] { "Basic Shot", "Double Shot", "Piercing Ultimate" },
        new[] { "Smash", "Area", "Guard" }
    };
    private static readonly string[] ClassNames = { "Mage", "Knight", "Archer", "Orc" };
    private static readonly string[] PerkNames = { "King Crimson", "Defy Destiny", "Teleport", "Tactician" };

    private LanSession lan;
    private DemoBoard board;
    private DemoView view;
    private int perspective = 1;
    private enum Screen { Title, Modes, Help, Lobby, Arena }
    private Screen screen = Screen.Title;
    private Control titleScreen, modeScreen, helpScreen, lobbyScreen, arenaScreen;
    private Label lobbyTitle, lobbyStatus, lobbyInstructions;
    private VBoxContainer modeStack;
    private Button[] mainMenuButtons, modeMenuButtons;
    private int mainMenuIndex, modeMenuIndex;
    private int lastObservedCycle = -1;
    private int[] setupClasses = { 0, 0 };
    private int[] setupPerks = { 0, 1 };
    private int[] spawnRows = { 2, 11 }, spawnCols = { 5, 5 };
    private int draftSlot, pendingStep = int.MinValue, pendingDirection = 1, pendingRange = 1;
    private readonly int[][] draftSlots = { new int[3], new int[3] };
    private readonly List<DemoCommand>[] rosters = { new(), new() };
    private bool[][][] committed = { Array.Empty<bool[]>(), Array.Empty<bool[]>() };
    private readonly int[] editCharacter = new int[2];
    private int planningTurn = 1;
    private float futureSightSeconds;
    private float timerUpdate;
    private ActionTimeline timeline;
    private Label rosterLabel, timerLabel;
    private Button deployDoneButton;
    private Label headlineLabel, hintLabel, actionLabel, listLabel, bannerLabel, classLabel, perkLabel, modeLabel;
    private Label keyboardHelp, waitingLabel, inputLabel;
    private readonly HashSet<Key> pressedGameplayKeys = new();
    private static readonly Key[] GameplayKeys =
    {
        Key.Up, Key.Down, Key.Left, Key.Right,
        Key.Kp0, Key.Kp1, Key.Kp2, Key.Kp3, Key.Kp4, Key.Kp5,
        Key.Kp6, Key.Kp7, Key.Kp8, Key.Kp9,
        Key.Enter, Key.KpEnter, Key.Tab, Key.Backspace, Key.Escape,
        Key.KpAdd, Key.KpSubtract, Key.Equal, Key.Plus, Key.Minus,
        Key.T, Key.F, Key.P, Key.R, Key.S, Key.Space, Key.J, Key.K
    };
    private Button confirmButton, readyButton;
    private Button[] classCards, perkCards;
    private Button undoSpawnButton;
    private Button[] fighterCards;
    private bool remoteViewReady;
    private Button fighterButton, exchangeButton, advanceButton, skipButton, destinyButton, foresightButton, handoffButton;
    private Control classChooser, perkChooser, deployHeader, planHeader, fightHeader;

    private bool[] configured = new bool[2];
    private int[] chosenClasses = { -1, -1 };
    private int[] chosenPerks = { -1, -1 };
    private float playbackElapsed;
    private const float TickSeconds = 0.42f;
    private int rewindRow = -1, rewindCol = -1, rewindTick = -1;
    private bool previousRewindPending;
    private float networkUpdateElapsed;
    private string lastMessage = "Choose Local or Host to start.";

    private LineEdit ipField;
    private Label statusLabel;
    private CheckButton autoTick;

    public override void _Ready()
    {
        SetProcessInput(true);
        SetProcess(true);
        lan = new LanSession { Name = "LanSession" };
        AddChild(lan);
        lan.CommandReceived += ReceiveCommand;
        lan.ViewReceived += json =>
        {
            if (lan.Mode != LanSession.SessionMode.Client ||
                (screen != Screen.Lobby && screen != Screen.Arena)) return;
            try
            {
                DemoView incoming = JsonSerializer.Deserialize<DemoView>(json);
                if (incoming?.Map == null || incoming.Map.Length == 0) return;
                view = incoming;
                if (!incoming.Configured[1] && incoming.DraftPerks.Length > 1)
                    setupPerks[1] = incoming.DraftPerks[1];
                remoteViewReady = true;
                if (screen == Screen.Lobby) EnterArena();
                Refresh();
            }
            catch (Exception e) { lastMessage = "Bad LAN snapshot: " + e.Message; UpdateLobby(); Refresh(); }
        };
        lan.StatusChanged += message =>
        {
            lastMessage = message;
            UpdateLobby();
            Refresh();
        };
        lan.GuestJoined += () =>
        {
            if (lan.Mode != LanSession.SessionMode.Host || !lan.GuestConnected) return;
            if (screen == Screen.Lobby) EnterArena();
            Publish();
        };
        lan.GuestLeft += () =>
        {
            if (lan.Mode != LanSession.SessionMode.Host) return;
            lastMessage = "Player 2 disconnected. Waiting for another player…";
            ShowScreen(Screen.Lobby);
        };
        lan.ConnectionLost += () =>
        {
            lastMessage = "LAN connection lost. Host a new match or join again.";
            remoteViewReady = false;
            view = null;
            ShowScreen(Screen.Modes);
            modeLabel.Text = lastMessage;
        };
        lan.ConnectedToHost += () =>
        {
            if (lan.Mode != LanSession.SessionMode.Client || screen != Screen.Lobby) return;
            lastMessage = "Connected. Waiting for host's battlefield…";
            UpdateLobby();
            lan.RequestView();
        };
        BuildUi();
        Refresh();
    }

    public override void _Process(double delta)
    {
        PollGameplayKeyboard();
        if (screen != Screen.Arena || view == null || lan.Mode == LanSession.SessionMode.Client ||
            (lan.Mode == LanSession.SessionMode.Host && !lan.GuestConnected)) return;
        if (lan.Mode == LanSession.SessionMode.Host && lan.GuestConnected)
        {
            networkUpdateElapsed += (float)delta;
            if (networkUpdateElapsed >= 0.5f)
            {
                networkUpdateElapsed = 0;
                lan.SendView(JsonSerializer.Serialize(BuildView(2)));
            }
        }
        if (configured[0] && configured[1] && BattleEngine.getDetails()?.futureSightPending == true)
        {
            futureSightSeconds = Math.Max(0, futureSightSeconds - (float)delta);
            timerUpdate += (float)delta;
            if (futureSightSeconds <= 0)
            {
                int owner = chosenPerks[0] == (int)SuperPerk.KingCrimson ? 1 : 2;
                BattleEngine.finishFutureSight((uint)owner);
                lastMessage = "Future Sight expired · orders sealed";
                Publish();
            }
            else if (timerUpdate >= .25f) { timerUpdate = 0; Publish(); }
        }
        if (!view.Active || view.RewindPending) return;
        playbackElapsed += (float)delta;
        if (playbackElapsed < TickSeconds) return;
        playbackElapsed = 0;
        networkUpdateElapsed = 0;
        try { if (BattleEngine.advanceOneTick()) Publish(); }
        catch (Exception e) { lastMessage = e.Message; Refresh(); }
    }

    private void StartLocal()
    {
        if (screen != Screen.Modes) return;
        lan.Close();
        perspective = 1;
        remoteViewReady = true;
        InitMatch();
        lastMessage = "LOCAL COUCH · Player 1 deploys first (same keyboard for both players).";
        EnterArena();
        Publish();
    }

    private void StartHost()
    {
        if (screen != Screen.Modes) return;
        Error error = lan.Host();
        if (error != Error.Ok) { lastMessage = $"Could not host: {error}"; modeLabel.Text = lastMessage; return; }
        perspective = 1;
        remoteViewReady = true;
        InitMatch();
        lastMessage = $"HOSTING UDP {LanSession.Port} · waiting for Player 2 before deployment.";
        ShowScreen(Screen.Lobby);
    }

    private void StartJoin()
    {
        if (screen != Screen.Modes) return;
        Error error = lan.Join(ipField.Text);
        if (error != Error.Ok) { lastMessage = $"Could not join: {error}"; modeLabel.Text = lastMessage; return; }
        perspective = 2;
        remoteViewReady = false;
        view = ConnectingView();
        lastMessage = "Joining LAN match… waiting for the host.";
        ShowScreen(Screen.Lobby);
    }

    private static DemoView ConnectingView()
    {
        MapElement[,] tiles = MapTable.getMap(0).map;
        int[][] grid = new int[tiles.GetLength(0)][];
        for (int r = 0; r < grid.Length; r++)
        {
            grid[r] = new int[tiles.GetLength(1)];
            for (int c = 0; c < grid[r].Length; c++) grid[r][c] = (int)tiles[r, c];
        }
        return new DemoView { Player = 2, Map = grid, Message = "Connecting to host… map loaded locally." };
    }

    private void InitMatch()
    {
        BattleEngine.setupEngine(0);
        for (int i = 0; i < 2; i++) { rosters[i].Clear(); draftSlots[i] = new int[3]; editCharacter[i] = 0; }
        planningTurn = 1;
        futureSightSeconds = 0;
        timerUpdate = 0;
        committed = new[] { Array.Empty<bool[]>(), Array.Empty<bool[]>() };
        configured = new bool[2];
        chosenClasses = new[] { -1, -1 };
        chosenPerks = new[] { -1, -1 };
        playbackElapsed = 0;
        draftSlot = 0;
        pendingStep = int.MinValue;
        pendingDirection = 1;
        pendingRange = 1;
        lastObservedCycle = -1;
        rewindRow = rewindCol = rewindTick = -1;
        previousRewindPending = false;
        foreach (int[] slots in draftSlots) Array.Fill(slots, 0);
    }

    private int CurrentPlayer => lan.Mode == LanSession.SessionMode.Client ? 2 :
        lan.Mode == LanSession.SessionMode.Host ? 1 : perspective;

    private void Send(string command, DemoCommand data = null)
    {
        if (lan.Mode == LanSession.SessionMode.Client && !remoteViewReady)
        { lastMessage = "Waiting for host synchronization"; Refresh(); return; }
        if (lan.Mode == LanSession.SessionMode.Host && !lan.GuestConnected)
        { lastMessage = "Waiting for Player 2 to reconnect"; UpdateLobby(); return; }
        lan.SendCommand(command, JsonSerializer.Serialize(data ?? new DemoCommand()));
    }

    private void ReceiveCommand(int sender, string command, string json)
    {
        int player = lan.Mode == LanSession.SessionMode.Hotseat ? perspective : sender;
        if (lan.Mode == LanSession.SessionMode.Host && !lan.GuestConnected) return;
        try
        {
            DemoCommand data = JsonSerializer.Deserialize<DemoCommand>(json) ?? new DemoCommand();
            switch (command)
            {
                case "perk":
                    if (configured[player - 1]) throw new InvalidOperationException("The team is already finalized.");
                    if (data.Perk is < 0 or > 3) throw new ArgumentException("Invalid perk.");
                    if (rosters[2 - player].Count > 0 && rosters[2 - player][0].Perk == data.Perk)
                        throw new InvalidOperationException("That perk belongs to the rival team. Choose another.");
                    setupPerks[player - 1] = data.Perk;
                    foreach (DemoCommand fighter in rosters[player - 1]) fighter.Perk = data.Perk;
                    lastMessage = $"Player {player} equipped {PerkNames[data.Perk]}. You can keep deploying.";
                    break;
                case "spawn":
                    if (configured[player - 1]) break;
                    if (data.Class is < 0 or > 3 || data.Perk is < 0 or > 3)
                        throw new ArgumentException("Invalid class or perk.");
                    if (rosters[player - 1].Count >= 3) throw new InvalidOperationException("Maximum three characters.");
                    data.Perk = setupPerks[player - 1];
                    if (rosters[player - 1].Count > 0 && data.Perk != rosters[player - 1][0].Perk)
                        throw new InvalidOperationException("Perk is chosen once for the whole team.");
                    MapElement[,] tiles = BattleEngine.getCurrentMap().map;
                    int middle = (tiles.GetLength(0) + 1) / 2;
                    if (data.Row < 0 || data.Row >= tiles.GetLength(0) || data.Col < 0 || data.Col >= tiles.GetLength(1) ||
                        (player == 1 && data.Row >= middle) || (player == 2 && data.Row < middle) ||
                        tiles[data.Row, data.Col] == MapElement.W || tiles[data.Row, data.Col] == MapElement.K)
                        throw new ArgumentException("Choose a safe tile within your spawn half.");
                    if (rosters[2 - player].Count > 0 && rosters[2 - player][0].Perk == data.Perk)
                        throw new ArgumentException("The opposing player already chose that perk.");
                    rosters[player - 1].Add(data);
                    lastMessage = $"Player {player} placed {ClassNames[data.Class]} ({rosters[player - 1].Count}/3)";
                    break;
                case "remove_spawn":
                    if (!configured[player - 1] && rosters[player - 1].Count > 0)
                    {
                        rosters[player - 1].RemoveAt(rosters[player - 1].Count - 1);
                        lastMessage = $"Player {player} removed the last fighter";
                    }
                    break;
                case "deploy_done":
                    if (configured[player - 1]) break;
                    List<DemoCommand> chosen = rosters[player - 1];
                    if (chosen.Count == 0) throw new InvalidOperationException("Deploy at least one character.");
                    int[] classes = chosen.Select(c => c.Class).ToArray();
                    int[][] steps = classes.Select(c => new int[c switch { 0 => 10, 1 => 15, 2 => 20, _ => 7 }]).ToArray();
                    BattleEngine.setupPlayer((uint)player, (uint)chosen.Count, classes.Select(c => (CharacterClass)c).ToArray(),
                        steps, chosen.Select(c => new IVector2(c.Row, c.Col)).ToArray(), (SuperPerk)chosen[0].Perk);
                    configured[player - 1] = true;
                    chosenClasses[player - 1] = classes[0];
                    chosenPerks[player - 1] = chosen[0].Perk;
                    committed[player - 1] = steps.Select(a => new bool[a.Length]).ToArray();
                    lastMessage = $"Player {player} deployed {chosen.Count} fighter(s)";
                    if (lan.Mode == LanSession.SessionMode.Hotseat && player == 1) SwitchPerspective(2);
                    break;
                case "step":
                    if (!configured[player - 1] || !configured.All(x => x)) break;
                    if (lan.Mode == LanSession.SessionMode.Hotseat &&
                        (BattleEngine.getDetails().futureSightPending ?
                        chosenPerks[player - 1] != (int)SuperPerk.KingCrimson : player != planningTurn))
                        throw new InvalidOperationException("It is the other player's planning turn.");
                    BattleEngine.setStep((uint)player, data.CharacterIndex, data.Slot, data.Step, data.Direction,
                        new IVector2(data.Range, data.Range));
                    committed[player - 1][data.CharacterIndex][data.Slot] = data.Step != 0 || data.Range != 0;
                    lastMessage = $"Player {player} · fighter {data.CharacterIndex + 1} · slot {data.Slot + 1} saved";
                    break;
                case "lock":
                    if (!configured.All(x => x)) break;
                    if (lan.Mode == LanSession.SessionMode.Hotseat && player != planningTurn)
                        throw new InvalidOperationException("Not your planning turn.");
                    bool[] wasLocked = BattleEngine.getDetails().planningLocked;
                    if (wasLocked[player - 1]) throw new InvalidOperationException("Plan already locked.");
                    BattleEngine.finishPlanning((uint)player);
                    if (lan.Mode == LanSession.SessionMode.Hotseat && player == 1)
                    { planningTurn = 2; SwitchPerspective(2); }
                    if (BattleEngine.getDetails().futureSightPending)
                    {
                        futureSightSeconds = BattleEngine.getFutureSightSeconds();
                        if (lan.Mode == LanSession.SessionMode.Hotseat)
                        { planningTurn = chosenPerks[0] == (int)SuperPerk.KingCrimson ? 1 : 2; SwitchPerspective(planningTurn); }
                    }
                    lastMessage = $"Player {player} locked their plan";
                    break;
                case "foresight":
                    BattleEngine.finishFutureSight((uint)player);
                    futureSightSeconds = 0;
                    lastMessage = "Future Sight closed";
                    break;
                case "select":
                    if (!BattleEngine.selectCharacter((uint)player, data.CharacterIndex))
                        throw new InvalidOperationException("Cannot select character yet.");
                    lastMessage = $"Player {player} selected fighter {data.CharacterIndex + 1}";
                    break;
                case "start":
                    if (player != 1 || !BattleEngine.startExchange())
                        throw new InvalidOperationException("Both players must select a fighter before starting.");
                    lastMessage = "Exchange started";
                    break;
                case "tick":
                    if (player != 1 || !BattleEngine.advanceOneTick())
                        throw new InvalidOperationException("Tick unavailable.");
                    lastMessage = "Tick resolved";
                    break;
                case "skip":
                    if (!BattleEngine.passRewindDecision((uint)player))
                        throw new InvalidOperationException("Only the Defy Destiny owner can pass.");
                    lastMessage = "Rewind passed";
                    break;
                case "rewind":
                    bool success = BattleEngine.tryDefyDestinyAtTile((uint)player,
                        data.Row, data.Col, data.Step, data.Direction,
                        new IVector2(data.Range, data.Range));
                    lastMessage = success ? "DEFY DESTINY · REPLAYING THE CHANGED TIMELINE" :
                        "DEFY DESTINY FAILED · ORIGINAL EXCHANGE STANDS";
                    break;
                default: return;
            }
        }
        catch (Exception e) { lastMessage = $"Player {player}: {e.Message}"; }
        Publish();
    }

    private DemoView BuildView(int player)
    {
        MapElement[,] source = BattleEngine.getCurrentMap().map;
        int[][] cells = new int[source.GetLength(0)][];
        for (int r = 0; r < cells.Length; r++)
        {
            cells[r] = new int[source.GetLength(1)];
            for (int c = 0; c < cells[r].Length; c++) cells[r][c] = (int)source[r, c];
        }
        DemoView result = new()
        {
            Player = player, Map = cells, Configured = (bool[])configured.Clone(),
            Classes = (int[])chosenClasses.Clone(), Perks = (int[])chosenPerks.Clone(),
            DraftPerks = (int[])setupPerks.Clone(),
            TeamClasses = new[] { rosters[0].Select(c => c.Class).ToArray(), rosters[1].Select(c => c.Class).ToArray() },
            PlanningTurn = planningTurn,
            FutureSightSeconds = futureSightSeconds,
            Tick = (int)BattleEngine.getClock(), ExchangeTick = BattleEngine.getExchangeTick(),
            Exchange = BattleEngine.getExchangeIndex(), Cycle = BattleEngine.getCycleIndex(),
            Active = BattleEngine.isExchangeActive(), RewindPending = BattleEngine.needsRewindDecision(),
            Replaying = BattleEngine.isReplaying(),
            UsedTiles = BattleEngine.getExchangeTiles().Select(t => new DemoUsedTile
            { Tick = t.tick, Row = t.row, Col = t.col, Owner = t.owner, Kind = t.kind }).ToArray(),
            RewindOrigins = BattleEngine.getExchangeOrigins(),
            Outcome = BattleEngine.getOutcome(), Message = lastMessage
        };
        if (!configured.All(x => x)) return AddUnits(result, player);
        Snapshot snapshot = BattleEngine.getDetails();
        result.Locked = (bool[])snapshot.planningLocked.Clone();
        result.SelectedIndices = (int[])snapshot.selected.Clone();
        result.Selected = snapshot.selected.Select(i => i >= 0).ToArray();
        result.FutureSight = snapshot.futureSightPending;
        result.CanSelect = BattleEngine.canSelectCharacters();
        int[][] visible = BattleEngine.getVisibleOpponentSteps((uint)player);
        if (visible.Length > 0) result.Intel = "ENEMY INTEL · " + string.Join(" | ", visible.Select(a => string.Join(",", a.Take(12))));
        result.DefyOwner = chosenPerks[0] == (int)SuperPerk.DefyDestiny ? 1 :
            chosenPerks[1] == (int)SuperPerk.DefyDestiny ? 2 : 0;
        Player team = BattleEngine.getPlayer((uint)player);
        result.TeamSteps = team.getCharacters().Select(c => c.getSteps()).ToArray();
        result.TeamDirections = team.getCharacters().Select(c => c.getDirections()).ToArray();
        result.TeamRanges = team.getCharacters().Select(c => c.getLengths().Select(l => Math.Max(l.x, l.y)).ToArray()).ToArray();
        result.TeamCommitted = committed[player - 1].Select(a => (bool[])a.Clone()).ToArray();
        result.Steps = result.TeamSteps[0];
        result.Directions = result.TeamDirections[0];
        result.Ranges = result.TeamRanges[0];
        return AddUnits(result, player);
    }

    private DemoView AddUnits(DemoView result, int viewer)
    {
        List<DemoUnit> units = new();
        for (int p = 1; p <= 2; p++)
        {
            if (configured[p - 1])
            {
                Player team = BattleEngine.getPlayer((uint)p);
                bool showLive = p == viewer || result.Active || result.RewindPending || result.Outcome != 0;
                for (int i = 0; i < team.count(); i++)
                {
                    Character character = team.getCharacter(i);
                    if (showLive && !character.isAlive()) continue;
                    IVector2 pos = showLive ? character.currentPosition() : rosters[p - 1][i] is DemoCommand spawn ?
                        new IVector2(spawn.Row, spawn.Col) : new IVector2(0, 0);
                    units.Add(new DemoUnit { Player = p, Index = i, Class = rosters[p - 1][i].Class,
                        Row = pos.x, Col = pos.y, Hp = showLive ? character.currentHP() : -1,
                        MaxHp = character.maxHP(), LivePosition = showLive });
                }
            }
            else
            {
                for (int i = 0; i < rosters[p - 1].Count; i++)
                {
                    DemoCommand spawn = rosters[p - 1][i];
                    units.Add(new DemoUnit { Player = p, Index = i, Class = spawn.Class,
                        Row = spawn.Row, Col = spawn.Col, Hp = -1, MaxHp = 1, LivePosition = p == viewer });
                }
            }
        }
        result.Units = units.ToArray();
        return result;
    }

    private void SwitchPerspective(int next)
    {
        if (perspective == next) return;
        int old = perspective - 1;
        if (old >= 0 && old < 2)
            draftSlots[old][Math.Clamp(editCharacter[old], 0, 2)] = draftSlot;
        perspective = next;
        int selected = Math.Clamp(editCharacter[next - 1], 0, 2);
        draftSlot = draftSlots[next - 1][selected];
        pendingStep = int.MinValue;
        pendingRange = pendingDirection = 1;
        rewindRow = rewindCol = rewindTick = -1;
    }

    private void Publish()
    {
        if (lan.Mode == LanSession.SessionMode.Client) return;
        if (configured[0] && configured[1] && BattleEngine.getCycleIndex() != lastObservedCycle && lastObservedCycle >= 0)
            planningTurn = 1;
        if (lan.Mode == LanSession.SessionMode.Hotseat && configured[0] && configured[1])
        {
            Snapshot state = BattleEngine.getDetails();
            int next;
            if (state.futureSightPending)
                next = chosenPerks[0] == (int)SuperPerk.KingCrimson ? 1 : 2;
            else if (BattleEngine.needsRewindDecision())
                next = chosenPerks[0] == (int)SuperPerk.DefyDestiny ? 1 : 2;
            else if (!state.planningLocked[0]) next = 1;
            else if (!state.planningLocked[1]) next = 2;
            else if (!BattleEngine.isExchangeActive() && BattleEngine.canSelectCharacters())
                next = state.selected[0] < 0 ? 1 : state.selected[1] < 0 ? 2 : 1;
            else next = 1;
            SwitchPerspective(next);
        }
        view = BuildView(CurrentPlayer);
        Refresh();
        if (lan.Mode == LanSession.SessionMode.Host && lan.GuestConnected)
            lan.SendView(JsonSerializer.Serialize(BuildView(2)));
    }

    private static readonly Color Gold = new("#f3d69b");
    private static readonly Color Paper = new("#eee3cb");
    private static readonly Color Sea = new("#6bd5ba");
    private static readonly Color Rust = new("#efa478");
    private static readonly Color Dim = new("#afbaab");
    private static readonly Color Deep = new("#142332");

    private void BuildUi()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        RetroArt stars = new(); Full(stars); AddChild(stars);
        titleScreen = FullLayer(); modeScreen = FullLayer(); helpScreen = FullLayer();
        lobbyScreen = FullLayer(); arenaScreen = FullLayer();
        BuildTitle(); BuildModeMenu(); BuildHelp(); BuildLobby(); BuildArena();
        ShowScreen(Screen.Title);
    }

    private Control FullLayer()
    {
        Control c = new() { MouseFilter = MouseFilterEnum.Ignore };
        Full(c); AddChild(c);
        return c;
    }

    private static void Full(Control control) => control.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);

    private static Label Text(string value, int size = 17, Color? ink = null)
    {
        Label label = new() { Text = value, AutowrapMode = TextServer.AutowrapMode.WordSmart };
        label.AddThemeFontSizeOverride("font_size", size);
        label.AddThemeColorOverride("font_color", ink ?? Paper);
        label.AddThemeColorOverride("font_shadow_color", new Color("#090f1b"));
        label.AddThemeConstantOverride("shadow_offset_x", 2);
        label.AddThemeConstantOverride("shadow_offset_y", 2);
        return label;
    }

    private static PanelContainer Frame(Color? background = null)
    {
        PanelContainer panel = new();
        StyleBoxFlat frame = new()
        {
            BgColor = background ?? Deep,
            BorderColor = new Color("#879d90"),
            BorderWidthLeft = 3, BorderWidthRight = 3, BorderWidthTop = 3, BorderWidthBottom = 3,
            ContentMarginLeft = 16, ContentMarginRight = 16, ContentMarginTop = 14, ContentMarginBottom = 14,
            ShadowColor = new Color("#070b15"), ShadowSize = 6, ShadowOffset = new Vector2(5, 5)
        };
        panel.AddThemeStyleboxOverride("panel", frame);
        return panel;
    }

    private static Button MenuButton(string caption, Action action)
    {
        Button button = new() { Text = caption, CustomMinimumSize = new Vector2(0, 44), FocusMode = FocusModeEnum.None };
        button.Pressed += action;
        button.AddThemeFontSizeOverride("font_size", 18);
        button.AddThemeColorOverride("font_color", Paper);
        button.AddThemeColorOverride("font_hover_color", Gold);
        StyleBoxFlat normal = new()
        {
            BgColor = new Color("#273a44"), BorderColor = new Color("#647d76"),
            BorderWidthLeft = 3, BorderWidthRight = 3, BorderWidthTop = 3, BorderWidthBottom = 3,
            ContentMarginLeft = 10, ContentMarginRight = 10, ContentMarginTop = 8, ContentMarginBottom = 8
        };
        StyleBoxFlat hover = (StyleBoxFlat)normal.Duplicate();
        hover.BgColor = new Color("#476052"); hover.BorderColor = Gold;
        StyleBoxFlat pressed = (StyleBoxFlat)hover.Duplicate(); pressed.BgColor = new Color("#253b31");
        button.AddThemeStyleboxOverride("normal", normal);
        button.AddThemeStyleboxOverride("hover", hover);
        button.AddThemeStyleboxOverride("pressed", pressed);
        button.AddThemeStyleboxOverride("disabled", normal);
        return button;
    }

    private static PixelTitle Pixel(string caption, int scale, Color? ink = null)
    {
        return new PixelTitle { Caption = caption, PixelScale = scale, Ink = ink ?? Gold,
            CustomMinimumSize = new Vector2(0, 7 * scale + 14), SizeFlagsHorizontal = SizeFlags.ExpandFill };
    }

    private void BuildTitle()
    {
        CenterContainer center = new(); Full(center); titleScreen.AddChild(center);
        VBoxContainer content = new() { CustomMinimumSize = new Vector2(680, 550) };
        content.AddThemeConstantOverride("separation", 18); center.AddChild(content);
        content.AddChild(Text("✦   THE LOST CHRONICLES OF SKY ISLAND   ✦", 19, Sea));
        content.AddChild(Pixel("GRID TACTICS", 6));
        Label subtitle = Text("A TURN-BASED DUEL OF SPELLS, STEEL & DESTINY", 16, Dim);
        subtitle.HorizontalAlignment = HorizontalAlignment.Center; content.AddChild(subtitle);
        content.AddChild(new Control { CustomMinimumSize = new Vector2(0, 18) });
        PanelContainer frame = Frame(new Color("#172736")); content.AddChild(frame);
        VBoxContainer menu = new(); menu.AddThemeConstantOverride("separation", 12); frame.AddChild(menu);
        mainMenuButtons = new[]
        {
            MenuButton("START MATCH", () => ShowScreen(Screen.Modes)),
            MenuButton("HOW TO PLAY", () => ShowScreen(Screen.Help)),
            MenuButton("QUIT GAME", () => GetTree().Quit())
        };
        for (int i = 0; i < mainMenuButtons.Length; i++)
        {
            int index = i;
            mainMenuButtons[i].MouseEntered += () => { mainMenuIndex = index; UpdateMenuSelection(); };
            menu.AddChild(mainMenuButtons[i]);
        }
        Label hint = Text("↑  ↓  CHOOSE       ENTER  SELECT", 16, Gold);
        hint.HorizontalAlignment = HorizontalAlignment.Center; content.AddChild(hint);
        Label foot = Text("EST. 2026   •   INPUT + LAN FIX / PLAYTEST EDITION", 13, Dim);
        foot.HorizontalAlignment = HorizontalAlignment.Center; content.AddChild(foot);
        UpdateMenuSelection();
    }

    private void ActivateMainMenu(int index)
    {
        mainMenuIndex = index;
        UpdateMenuSelection();
        switch (index)
        {
            case 0: ShowScreen(Screen.Modes); break;
            case 1: ShowScreen(Screen.Help); break;
            case 2: GetTree().Quit(); break;
        }
    }

    private void UpdateMenuSelection()
    {
        if (mainMenuButtons == null) return;
        for (int i = 0; i < mainMenuButtons.Length; i++)
            mainMenuButtons[i].Modulate = i == mainMenuIndex ? new Color("#ffe3a4") : Colors.White;
    }

    private void BuildModeMenu()
    {
        CenterContainer center = new(); Full(center); modeScreen.AddChild(center);
        VBoxContainer content = new() { CustomMinimumSize = new Vector2(600, 570) };
        content.AddThemeConstantOverride("separation", 18); center.AddChild(content);
        content.AddChild(Pixel("START MATCH", 5));
        PanelContainer frame = Frame(); content.AddChild(frame);
        modeStack = new(); modeStack.AddThemeConstantOverride("separation", 13); frame.AddChild(modeStack);
        modeStack.AddChild(Text("CHOOSE HOW TO ENTER THE ARENA", 20, Gold));
        Button local = MenuButton("LOCAL DUEL  /  HOTSEAT", StartLocal); modeStack.AddChild(local);
        Button host = MenuButton($"HOST LAN DUEL   /  UDP {LanSession.Port}", StartHost); modeStack.AddChild(host);
        modeStack.AddChild(Text("JOIN A FRIEND ON THE SAME NETWORK", 14, Dim));
        ipField = new LineEdit { Text = "127.0.0.1", PlaceholderText = "Host IPv4 address", CustomMinimumSize = new Vector2(0, 45) };
        ipField.AddThemeFontSizeOverride("font_size", 18); modeStack.AddChild(ipField);
        ipField.TextSubmitted += _ => StartJoin();
        Button join = MenuButton("JOIN LAN DUEL", StartJoin); modeStack.AddChild(join);
        Button back = MenuButton("← RETURN TO TITLE", () => ShowScreen(Screen.Title)); modeStack.AddChild(back);
        modeMenuButtons = new[] { local, host, join, back };
        for (int i = 0; i < modeMenuButtons.Length; i++)
        {
            int index = i;
            modeMenuButtons[i].MouseEntered += () => { modeMenuIndex = index; UpdateModeSelection(); };
        }
        modeLabel = Text("2 FIGHTERS · 1 ARENA · PRESS I TO EDIT IP", 14, Dim); content.AddChild(modeLabel);
        UpdateModeSelection();
    }

    private void ActivateModeMenu(int index)
    {
        modeMenuIndex = index;
        UpdateModeSelection();
        switch (index)
        {
            case 0: StartLocal(); break;
            case 1: StartHost(); break;
            case 2: StartJoin(); break;
            case 3: ShowScreen(Screen.Title); break;
        }
    }

    private void UpdateModeSelection()
    {
        if (modeMenuButtons == null) return;
        for (int i = 0; i < modeMenuButtons.Length; i++)
            modeMenuButtons[i].Modulate = i == modeMenuIndex ? new Color("#ffe3a4") : Colors.White;
    }

    private void BuildHelp()
    {
        CenterContainer center = new(); Full(center); helpScreen.AddChild(center);
        VBoxContainer content = new() { CustomMinimumSize = new Vector2(740, 640) };
        content.AddThemeConstantOverride("separation", 15); center.AddChild(content);
        content.AddChild(Pixel("HOW TO PLAY", 5));
        PanelContainer frame = Frame(); content.AddChild(frame);
        VBoxContainer text = new(); text.AddThemeConstantOverride("separation", 12); frame.AddChild(text);
        text.AddChild(Text("01 / DEPLOY YOUR TEAM", 19, Gold));
        text.AddChild(Text("Choose 1–3 characters (classes may repeat) and a team perk with the MOUSE. Click a tile in your half to deploy. Finish your team with the button. Enemy spawns are visible.", 17));
        text.AddChild(Text("02 / WRITE YOUR ACTIONS", 19, Gold));
        text.AddChild(Text("ARROWS preview movement. NUMPAD 1–9 choose a skill, then CLICK its landing tile on the board or use ARROWS to aim. Dotted outlines show the cast range and the affected tiles. +/- adjusts variable range. T is teleport; NUMPAD 0 ends the sequence.", 17));
        text.AddChild(Text("03 / CONFIRM AND EDIT SLOTS", 19, Gold));
        text.AddChild(Text("The board previews your movement or attack BEFORE it is saved. Press ENTER to confirm the highlighted action. BACKSPACE clears a slot; ESC cancels a pending preview. During 30-second Future Sight, TAB cycles slots, including empty ones.", 17));
        text.AddChild(Text("04 / FIGHT", 19, Gold));
        text.AddChild(Text("Press F to lock your plan. Both fighters are then selected. The host starts combat. All programmed actions resolve simultaneously, one tick at a time.", 17));
        text.AddChild(Text("COUCH: players plan in turns. LAN: plan at the same time. J/K cycle teammates. FUTURE SIGHT: TAB cycles slots for 30 seconds. S picks a fighter for combat.", 15, Dim));
        content.AddChild(MenuButton("RETURN TO TITLE", () => ShowScreen(Screen.Title)));
    }

    private void BuildLobby()
    {
        CenterContainer center = new(); Full(center); lobbyScreen.AddChild(center);
        VBoxContainer content = new() { CustomMinimumSize = new Vector2(650, 420) };
        content.AddThemeConstantOverride("separation", 22);
        center.AddChild(content);
        content.AddChild(Pixel("WAITING ROOM", 5));
        PanelContainer frame = Frame(); content.AddChild(frame);
        VBoxContainer stack = new(); stack.AddThemeConstantOverride("separation", 20);
        frame.AddChild(stack);
        lobbyTitle = Text("LAN LOBBY", 26, Gold); stack.AddChild(lobbyTitle);
        lobbyStatus = Text("Waiting for connection…", 20, Paper); stack.AddChild(lobbyStatus);
        lobbyInstructions = Text("", 16, Dim); stack.AddChild(lobbyInstructions);
        content.AddChild(MenuButton("CANCEL  /  RETURN TO MATCH MENU", () =>
        {
            lan.Close();
            remoteViewReady = false;
            view = null;
            ShowScreen(Screen.Modes);
        }));
    }

    private void UpdateLobby()
    {
        if (lobbyTitle == null || screen != Screen.Lobby) return;
        bool host = lan.Mode == LanSession.SessionMode.Host;
        lobbyTitle.Text = host ? "HOSTING LOCAL NETWORK MATCH" : "CONNECTING TO LAN HOST";
        lobbyStatus.Text = lastMessage;
        lobbyInstructions.Text = host
            ? $"Waiting for a second player on UDP {LanSession.Port}.\n" +
              "The match will open automatically when Player 2 connects.\n" +
              "Both players can then deploy and plan simultaneously."
            : "The match will open when the host accepts your connection\n" +
              "and synchronizes the battlefield.";
    }

    private void BuildArena()
    {
        MarginContainer page = new(); Full(page);
        foreach (string marginSide in new[] { "left", "right", "top", "bottom" }) page.AddThemeConstantOverride("margin_" + marginSide, 20);
        arenaScreen.AddChild(page);
        VBoxContainer outer = new(); outer.AddThemeConstantOverride("separation", 12); page.AddChild(outer);
        HBoxContainer top = new(); top.AddThemeConstantOverride("separation", 14); outer.AddChild(top);
        PixelTitle logo = Pixel("GRID TACTICS", 3); logo.CustomMinimumSize = new Vector2(330, 40); logo.SizeFlagsHorizontal = SizeFlags.ShrinkBegin; top.AddChild(logo);
        headlineLabel = Text("PLAYER 1  /  DEPLOY", 18, Sea); headlineLabel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        headlineLabel.HorizontalAlignment = HorizontalAlignment.Center; top.AddChild(headlineLabel);
        top.AddChild(MenuButton("TITLE", () => { lan.Close(); view = null; ShowScreen(Screen.Title); }));
        HBoxContainer content = new() { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", 16); outer.AddChild(content);
        PanelContainer battlefield = Frame(new Color("#0d1924"));
        battlefield.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        battlefield.SizeFlagsVertical = SizeFlags.ExpandFill; content.AddChild(battlefield);
        board = new DemoBoard(); board.CellClicked += OnCellClicked;
        board.TargetClicked += OnAttackTargetClicked;
        board.ReplayTileClicked += OnReplayTileClicked;
        battlefield.AddChild(board);
        PanelContainer parchment = Frame(new Color("#1b2932"));
        parchment.CustomMinimumSize = new Vector2(355, 0); parchment.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddChild(parchment);
        ScrollContainer scroll = new() { HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled,
            SizeFlagsVertical = SizeFlags.ExpandFill };
        parchment.AddChild(scroll);
        VBoxContainer side = new(); side.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        side.AddThemeConstantOverride("separation", 11); scroll.AddChild(side);
        side.AddChild(Pixel("COMMANDS", 3));
        bannerLabel = Text("THE DUEL BEGINS", 17, Gold); side.AddChild(bannerLabel);
        inputLabel = Text("INPUT CHECK: PRESS AN ARROW KEY", 13, Sea); side.AddChild(inputLabel);
        deployHeader = Text("01  /  CHOOSE YOUR FIGHTER", 15, Sea); side.AddChild(deployHeader);
        HBoxContainer classRow = new(); classChooser = classRow; classRow.AddThemeConstantOverride("separation", 8); side.AddChild(classRow);
        GridContainer classGrid = new() { Columns = 2, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        classGrid.AddThemeConstantOverride("h_separation", 7);
        classGrid.AddThemeConstantOverride("v_separation", 7);
        classRow.AddChild(classGrid);
        classCards = new Button[4];
        string[] classCaptions = { "MAGE\n10 ACTIONS", "KNIGHT\n15 ACTIONS", "ARCHER\n20 ACTIONS", "ORC\n7 ACTIONS" };
        for (int i = 0; i < 4; i++)
        {
            int selected = i;
            Button card = MenuButton(classCaptions[i], () => SelectClass(selected));
            card.CustomMinimumSize = new Vector2(143, 60);
            card.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            classGrid.AddChild(card);
            classCards[i] = card;
        }
        classLabel = Text("SELECT A CLASS", 15, Gold); side.AddChild(classLabel);
        HBoxContainer perkRow = new(); perkChooser = perkRow; side.AddChild(perkRow);
        GridContainer perkGrid = new() { Columns = 2, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        perkGrid.AddThemeConstantOverride("h_separation", 7);
        perkGrid.AddThemeConstantOverride("v_separation", 7);
        perkRow.AddChild(perkGrid);
        perkCards = new Button[4];
        string[] perkCaptions = { "KING CRIMSON", "DEFY DESTINY", "TELEPORT", "TACTICIAN" };
        for (int i = 0; i < 4; i++)
        {
            int selected = i;
            Button card = MenuButton(perkCaptions[i], () => SelectPerk(selected));
            card.CustomMinimumSize = new Vector2(143, 52);
            card.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            perkGrid.AddChild(card);
            perkCards[i] = card;
        }
        perkLabel = Text("ONE PERK FOR THE ENTIRE TEAM", 14, Dim); side.AddChild(perkLabel);
        rosterLabel = Text("TEAM  0 / 3", 15, Sea); side.AddChild(rosterLabel);
        undoSpawnButton = MenuButton("REMOVE LAST FIGHTER", () => Send("remove_spawn")); side.AddChild(undoSpawnButton);
        deployDoneButton = MenuButton("FINISH TEAM (1–3)", FinishRoster); side.AddChild(deployDoneButton);
        hintLabel = Text("CLICK A CLASS + PERK, THEN CLICK A TILE\nIN YOUR HALF OF THE MAP TO DEPLOY", 15, Gold); side.AddChild(hintLabel);
        side.AddChild(new HSeparator());
        planHeader = Text("02  /  PLAN YOUR TURNS", 15, Sea); side.AddChild(planHeader);
        actionLabel = Text("READY TO WRITE YOUR FIRST STEP", 17, Gold); side.AddChild(actionLabel);
        HBoxContainer fighterPicker = new(); fighterPicker.AddThemeConstantOverride("separation", 6);
        side.AddChild(fighterPicker);
        fighterCards = new Button[3];
        for (int i = 0; i < fighterCards.Length; i++)
        {
            int selected = i;
            Button card = MenuButton($"FIGHTER {i + 1}", () => SelectEditCharacter(selected));
            card.CustomMinimumSize = new Vector2(88, 50);
            card.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            fighterPicker.AddChild(card);
            fighterCards[i] = card;
        }
        timerLabel = Text("", 17, Rust); side.AddChild(timerLabel);
        timeline = new ActionTimeline(); side.AddChild(timeline);
        listLabel = Text("NO ORDERS YET", 15, Paper); side.AddChild(listLabel);
        confirmButton = MenuButton("ENTER  /  CONFIRM PREVIEW", ConfirmAction); side.AddChild(confirmButton);
        side.AddChild(new HSeparator());
        fightHeader = Text("03  /  BATTLE PHASE", 15, Sea); side.AddChild(fightHeader);
        readyButton = MenuButton("F  /  LOCK PLAN", () => Send("lock")); side.AddChild(readyButton);
        fighterButton = MenuButton("SELECT THIS FIGHTER FOR BATTLE", () => Send("select", CurrentFighter())); side.AddChild(fighterButton);
        exchangeButton = MenuButton("SPACE  /  START EXCHANGE", () => Send("start")); side.AddChild(exchangeButton);
        advanceButton = MenuButton("ADVANCE ONE TICK", () => {}); side.AddChild(advanceButton);
        autoTick = new CheckButton { Text = "AUTO PLAY", ButtonPressed = true }; side.AddChild(autoTick);
        skipButton = MenuButton("P  /  ACCEPT EXCHANGE", () => Send("skip")); side.AddChild(skipButton);
        destinyButton = MenuButton("ENTER / REWRITE AT SELECTED TILE", CommitRewind); side.AddChild(destinyButton);
        foresightButton = MenuButton("FINISH FUTURE SIGHT", () => Send("foresight")); side.AddChild(foresightButton);
        handoffButton = MenuButton("HANDOFF AUTOMATIC", () => {}); side.AddChild(handoffButton);
        keyboardHelp = Text("ARROWS: WALK / AIM  •  NUMPAD 1–9: SKILLS\nCLICK FIGHTER TAB  •  +/-: RANGE  •  T: TELEPORT\nENTER: CONFIRM  •  BACKSPACE: UNDO\nTAB: CYCLE SLOTS (FUTURE SIGHT)\nNUMPAD 0: END  •  F: LOCK", 14, Dim);
        side.AddChild(keyboardHelp);
        waitingLabel = Text("", 14, Gold); side.AddChild(waitingLabel);
        PanelContainer bottom = Frame(new Color("#1b2c34")); outer.AddChild(bottom);
        Label status = Text("", 15, Gold); statusLabel = status; bottom.AddChild(status);
    }

    private void ShowScreen(Screen destination)
    {
        screen = destination;
        pressedGameplayKeys.Clear();
        if (screen != Screen.Modes && ipField != null && ipField.HasFocus()) ipField.ReleaseFocus();
        if (titleScreen == null) return;
        titleScreen.Visible = screen == Screen.Title;
        modeScreen.Visible = screen == Screen.Modes;
        helpScreen.Visible = screen == Screen.Help;
        lobbyScreen.Visible = screen == Screen.Lobby;
        arenaScreen.Visible = screen == Screen.Arena;
        if (screen == Screen.Title) UpdateMenuSelection();
        if (screen == Screen.Modes) UpdateModeSelection();
        if (screen == Screen.Lobby) UpdateLobby();
        GD.Print($"[GT navigation] screen={screen}, network={lan.Mode}, perspective={perspective}, guest={lan.GuestConnected}");
        Refresh();
    }

    private void EnterArena()
    {
        draftSlot = 0; pendingStep = int.MinValue; pendingRange = 1; pendingDirection = 1;
        lastObservedCycle = -1;
        rewindRow = rewindCol = rewindTick = -1;
        previousRewindPending = false;
        ShowScreen(Screen.Arena);
    }

    private bool OwnDeployed => view != null && view.Configured[CurrentPlayer - 1];
    private bool BothDeployed => view != null && view.Configured[0] && view.Configured[1];
    private bool EditingFutureSight => BothDeployed && view.FutureSight && view.Perks[CurrentPlayer - 1] == (int)SuperPerk.KingCrimson;
    private bool MayEdit => BothDeployed && view.Outcome == 0 && !view.Active && !view.RewindPending &&
        (lan.Mode != LanSession.SessionMode.Hotseat || EditingFutureSight || CurrentPlayer == view.PlanningTurn) &&
        (!view.Locked[CurrentPlayer - 1] || EditingFutureSight);
    private int ActiveCharacter => view == null ? 0 :
        view.RewindPending && view.SelectedIndices.Length > CurrentPlayer - 1 &&
            view.SelectedIndices[CurrentPlayer - 1] >= 0 ? view.SelectedIndices[CurrentPlayer - 1] :
        Math.Clamp(editCharacter[CurrentPlayer - 1], 0,
            Math.Max(0, view.TeamClasses[CurrentPlayer - 1].Length - 1));
    private int[] CurrentSteps => view != null && view.TeamSteps.Length > ActiveCharacter ? view.TeamSteps[ActiveCharacter] : Array.Empty<int>();
    private int[] CurrentDirections => view != null && view.TeamDirections.Length > ActiveCharacter ? view.TeamDirections[ActiveCharacter] : Array.Empty<int>();
    private int[] CurrentRanges => view != null && view.TeamRanges.Length > ActiveCharacter ? view.TeamRanges[ActiveCharacter] : Array.Empty<int>();
    private bool[] CurrentCommitted => view != null && view.TeamCommitted.Length > ActiveCharacter ? view.TeamCommitted[ActiveCharacter] : Array.Empty<bool>();
    private int CurrentClass => OwnDeployed && view.TeamClasses[CurrentPlayer - 1].Length > ActiveCharacter ?
        view.TeamClasses[CurrentPlayer - 1][ActiveCharacter] : setupClasses[CurrentPlayer - 1];

    private DemoCommand CurrentFighter() => new() { CharacterIndex = ActiveCharacter };

    private void SelectClass(int selected)
    {
        if (OwnDeployed || view == null || !CanDeployNow) return;
        setupClasses[CurrentPlayer - 1] = selected;
        Refresh();
    }

    private void SelectPerk(int selected)
    {
        if (OwnDeployed || view == null || !CanDeployNow) return;
        int rival = 2 - CurrentPlayer;
        if (view.TeamClasses[rival].Length > 0 &&
            (view.Configured[rival] ? view.Perks[rival] : view.DraftPerks[rival]) == selected)
        {
            lastMessage = "The opposing team has already reserved that perk.";
            statusLabel.Text = lastMessage;
            return;
        }
        setupPerks[CurrentPlayer - 1] = selected;
        Send("perk", new DemoCommand { Perk = selected });
        Refresh();
    }

    private bool CanDeployNow => view != null && (lan.Mode != LanSession.SessionMode.Client || remoteViewReady) &&
        (lan.Mode != LanSession.SessionMode.Hotseat || CurrentPlayer == 1 || view.Configured[0]);

    private void SelectEditCharacter(int characterIndex)
    {
        if (!OwnDeployed || view == null || characterIndex < 0 ||
            characterIndex >= view.TeamClasses[CurrentPlayer - 1].Length) return;
        int id = CurrentPlayer - 1;
        draftSlots[id][ActiveCharacter] = draftSlot;
        editCharacter[id] = characterIndex;
        draftSlot = draftSlots[id][characterIndex];
        pendingStep = int.MinValue; pendingDirection = 1; pendingRange = 1;
        Refresh();
    }

    private void ChangeCharacter(int delta)
    {
        if (!OwnDeployed || view == null) return;
        SelectEditCharacter((ActiveCharacter + delta + view.TeamClasses[CurrentPlayer - 1].Length) %
            view.TeamClasses[CurrentPlayer - 1].Length);
    }

    private void OnReplayTileClicked(int row, int col)
    {
        if (view == null || !view.RewindPending || view.DefyOwner != CurrentPlayer) return;
        int latest = -1;
        foreach (DemoUsedTile tile in view.UsedTiles)
            if (tile.Row == row && tile.Col == col) latest = Math.Max(latest, tile.Tick);
        if (latest < 0) return;
        rewindRow = row; rewindCol = col; rewindTick = latest;
        pendingStep = int.MinValue; pendingDirection = pendingRange = 1;
        lastMessage = $"REWIND ANCHOR · TICK {latest + 1} · CHOOSE A REPLACEMENT ACTION, THEN ENTER";
        Refresh();
        statusLabel.Text = lastMessage;
    }

    private void CommitRewind()
    {
        if (view == null || !view.RewindPending || view.DefyOwner != CurrentPlayer) return;
        if (rewindTick < 0) { statusLabel.Text = "Click a highlighted battle tile first."; return; }
        if (pendingStep == int.MinValue) { statusLabel.Text = "Choose a replacement with arrows or numpad, then Enter."; return; }
        DemoCommand replacement = CurrentAction();
        replacement.Row = rewindRow;
        replacement.Col = rewindCol;
        Send("rewind", replacement);
        pendingStep = int.MinValue;
        rewindRow = rewindCol = rewindTick = -1;
    }

    private void OnAttackTargetClicked(int row, int col)
    {
        if (screen != Screen.Arena || view == null || pendingStep >= 0 || pendingStep == int.MinValue ||
            !(MayEdit || (view.RewindPending && view.DefyOwner == CurrentPlayer && rewindTick >= 0))) return;
        if (board.TryAimAt(row, col, out int direction, out int distance, out string reason))
        {
            pendingDirection = direction;
            pendingRange = distance;
            lastMessage = $"TARGET SET · ROW {row + 1}, COL {col + 1} · PRESS ENTER TO SAVE";
            Refresh();
            statusLabel.Text = lastMessage;
        }
        else
        {
            statusLabel.Text = reason;
        }
    }

    private void OnCellClicked(int row, int col)
    {
        if (screen != Screen.Arena || view == null || OwnDeployed || !CanDeployNow) return;
        spawnRows[CurrentPlayer - 1] = row; spawnCols[CurrentPlayer - 1] = col;
        PlaceSpawn();
    }

    private void PlaceSpawn()
    {
        if (view == null || OwnDeployed || !CanDeployNow || view.TeamClasses[CurrentPlayer - 1].Length >= 3) return;
        int id = CurrentPlayer - 1;
        Send("spawn", new DemoCommand
        {
            Row = spawnRows[id], Col = spawnCols[id], Class = setupClasses[id], Perk = setupPerks[id]
        });
        Refresh();
    }

    private void FinishRoster()
    {
        if (view != null && !OwnDeployed && view.TeamClasses[CurrentPlayer - 1].Length > 0)
            Send("deploy_done");
    }

    private void SetPending(int step)
    {
        pendingStep = step;
        if (step >= 1 && step <= 4) pendingDirection = step;
        if (step < 0)
        {
            (int minimum, int maximum) = DemoBoard.RangeFor(CurrentClass, -step,
                view?.Map.Length ?? 15, view?.Map.Length > 0 ? view.Map[0].Length : 13);
            pendingRange = Math.Max(1, minimum);
        }
        Refresh();
    }

    private int SkillCount() => SkillNames[Math.Clamp(CurrentClass, 0, 3)].Length;
    private void AdjustPendingRange(int amount)
    {
        int minimum = 1, maximum = 20;
        if (pendingStep < 0 && pendingStep != int.MinValue)
        {
            (minimum, maximum) = DemoBoard.RangeFor(CurrentClass, -pendingStep,
                view?.Map.Length ?? 15, view?.Map.Length > 0 ? view.Map[0].Length : 13);
            minimum = Math.Max(1, minimum);
            maximum = Math.Max(minimum, maximum);
        }
        pendingRange = Math.Clamp(pendingRange + amount, minimum, maximum);
        Refresh();
    }


    private void ConfirmAction()
    {
        if (!MayEdit || pendingStep == int.MinValue || draftSlot >= CurrentSteps.Length) return;
        if (pendingStep == 5 && view.Perks[CurrentPlayer - 1] != (int)SuperPerk.Teleport)
        {
            statusLabel.Text = "Teleport requires the Teleport perk.";
            return;
        }
        int slot = draftSlot;
        Send("step", CurrentAction());
        if (EditingFutureSight) draftSlot = (slot + 1) % CurrentSteps.Length;
        else draftSlot = Math.Min(slot + 1, CurrentSteps.Length);
        draftSlots[CurrentPlayer - 1][ActiveCharacter] = draftSlot;
        pendingStep = int.MinValue;
        pendingRange = 1;
        Refresh();
    }

    private DemoCommand CurrentAction() => new()
    {
        CharacterIndex = ActiveCharacter,
        Slot = draftSlot,
        Step = pendingStep == int.MinValue ? 0 : pendingStep,
        Direction = pendingDirection,
        Range = pendingRange
    };

    private void UndoAction()
    {
        if (!MayEdit) return;
        if (!EditingFutureSight && draftSlot > 0) draftSlot--;
        if (draftSlot >= CurrentSteps.Length) draftSlot = CurrentSteps.Length - 1;
        if (draftSlot < 0) return;
        draftSlots[CurrentPlayer - 1][ActiveCharacter] = draftSlot;
        pendingStep = int.MinValue;
        Send("step", new DemoCommand { CharacterIndex = ActiveCharacter, Slot = draftSlot, Step = 0, Range = 0 });
        Refresh();
    }

    private void CycleSlot()
    {
        if (!EditingFutureSight || CurrentSteps.Length == 0) return;
        draftSlot = (draftSlot + 1) % CurrentSteps.Length;
        draftSlots[CurrentPlayer - 1][ActiveCharacter] = draftSlot;
        pendingStep = int.MinValue; pendingRange = 1;
        Refresh();
    }

    private static int Arrow(Key key) => key switch
    {
        Key.Up => 1, Key.Down => 2, Key.Left => 3, Key.Right => 4, _ => 0
    };

    private static int NumpadSkill(Key logical, Key physical)
    {
        Key key = physical is >= Key.Kp1 and <= Key.Kp9 ? physical : logical;
        return key is >= Key.Kp1 and <= Key.Kp9 ? (int)key - (int)Key.Kp1 + 1 : 0;
    }

    private static bool IsGameplayKey(Key key) => Array.IndexOf(GameplayKeys, key) >= 0;

    private static Key NormalizeKey(InputEventKey key)
    {
        Key physical = key.PhysicalKeycode;
        if (physical is >= Key.Kp0 and <= Key.Kp9 ||
            physical is Key.KpEnter or Key.KpAdd or Key.KpSubtract)
            return physical;
        return key.Keycode != Key.None ? key.Keycode : physical;
    }

    private void PollGameplayKeyboard()
    {
        if (screen != Screen.Arena || inputLabel == null) return;
        if (ipField?.HasFocus() == true) { pressedGameplayKeys.Clear(); return; }
        bool padNavigation = false;
        for (int i = 0; i <= 9; i++)
            padNavigation |= Input.IsPhysicalKeyPressed((Key)((int)Key.Kp0 + i));
        foreach (Key key in GameplayKeys)
        {
            bool down = Input.IsPhysicalKeyPressed(key) || Input.IsKeyPressed(key);
            if (key is Key.Up or Key.Down or Key.Left or Key.Right &&
                padNavigation && !Input.IsPhysicalKeyPressed(key))
                down = false;
            if (down)
            {
                if (pressedGameplayKeys.Add(key)) HandleArenaKey(key, key);
            }
            else pressedGameplayKeys.Remove(key);
        }
    }

    private void ReportArenaKey(Key key, bool accepted)
    {
        if (inputLabel == null) return;
        string state = !BothDeployed ? "DEPLOY BOTH TEAMS FIRST" :
            view.Active ? "COMBAT PLAYBACK" :
            view.RewindPending ? "REWIND DECISION" :
            MayEdit ? $"EDITING FIGHTER {ActiveCharacter + 1}, SLOT {draftSlot + 1}" :
            view.Locked[CurrentPlayer - 1] ? "PLAN LOCKED" : "WAITING FOR PLANNING TURN";
        string action = pendingStep == int.MinValue ? "NONE" : StepName(pendingStep, CurrentClass);
        inputLabel.Text = $"KEY DETECTED: {key}  /  {(accepted ? "ACCEPTED" : "NOT ACTIVE")}\n{state}  |  PENDING: {action}";
        GD.Print($"[GT input] key={key}; accepted={accepted}; phase={state}");
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventKey key) return;
        Key value = NormalizeKey(key);
        if (screen == Screen.Arena)
        {
            if (!IsGameplayKey(value)) return;
            if (!key.Pressed) pressedGameplayKeys.Remove(value);
            else if (!key.Echo && pressedGameplayKeys.Add(value)) HandleArenaKey(value, key.PhysicalKeycode);
            GetViewport().SetInputAsHandled();
            return;
        }
        if (!key.Pressed || key.Echo) return;
        bool used = false;
        if (screen == Screen.Title)
        {
            if (value is Key.Up or Key.Down)
            { mainMenuIndex = (mainMenuIndex + (value == Key.Down ? 1 : 2)) % 3; UpdateMenuSelection(); used = true; }
            else if (value is Key.Enter or Key.KpEnter)
            { ActivateMainMenu(mainMenuIndex); used = true; }
        }
        else if (screen == Screen.Help)
        {
            if (value is Key.Escape or Key.Enter or Key.KpEnter)
            { ShowScreen(Screen.Title); used = true; }
        }
        else if (screen == Screen.Modes)
        {
            if (ipField.HasFocus())
            {
                if (value == Key.Escape) { ipField.ReleaseFocus(); used = true; }
            }
            else if (value is Key.Up or Key.Down)
            {
                modeMenuIndex = (modeMenuIndex + (value == Key.Down ? 1 : 3)) % 4;
                UpdateModeSelection(); used = true;
            }
            else if (value is Key.Enter or Key.KpEnter)
            { ActivateModeMenu(modeMenuIndex); used = true; }
            else if (value == Key.I)
            { ipField.GrabFocus(); used = true; }
            else if (value == Key.Escape)
            { ShowScreen(Screen.Title); used = true; }
        }
        if (used) GetViewport().SetInputAsHandled();
    }

    private void HandleArenaKey(Key value, Key physical)
    {
        if (ipField?.HasFocus() == true || view == null) { ReportArenaKey(value, false); return; }
        bool used = false;
        if (value == Key.Tab && EditingFutureSight) { CycleSlot(); used = true; }
        else if (OwnDeployed && value == Key.J) { ChangeCharacter(-1); used = true; }
        else if (OwnDeployed && value == Key.K) { ChangeCharacter(1); used = true; }
        else if (!OwnDeployed) { used = false; }
        else if (view.RewindPending && view.DefyOwner == CurrentPlayer)
        {
            if (rewindTick < 0)
            {
                if (value == Key.P) { Send("skip"); used = true; }
                else statusLabel.Text = "Click a highlighted tile to choose which tick to rewrite.";
                ReportArenaKey(value, used);
                return;
            }
            int dir = Arrow(value);
            if (dir != 0)
            {
                if (pendingStep != int.MinValue && (pendingStep < 0 || pendingStep == 5)) pendingDirection = dir;
                else pendingStep = dir;
                used = true; Refresh();
            }
            else if (NumpadSkill(value, physical) > 0)
            {
                int skill = NumpadSkill(value, physical);
                if (skill <= SkillCount()) SetPending(-skill);
                used = true;
            }
            else if (value == Key.Kp0 || physical == Key.Kp0) { SetPending(0); used = true; }
            else if (value is Key.KpAdd or Key.Equal or Key.Plus || physical == Key.KpAdd)
            { AdjustPendingRange(1); used = true; }
            else if (value is Key.KpSubtract or Key.Minus || physical == Key.KpSubtract)
            { AdjustPendingRange(-1); used = true; }
            else if (value == Key.P) { Send("skip"); pendingStep = int.MinValue; used = true; }
            else if (value is Key.R or Key.Enter or Key.KpEnter)
            {
                CommitRewind();
                used = true;
            }
        }
        else if (MayEdit)
        {
            int dir = Arrow(value);
            if (dir != 0)
            {
                if (pendingStep != int.MinValue && (pendingStep < 0 || pendingStep == 5)) pendingDirection = dir;
                else pendingStep = dir;
                used = true; Refresh();
            }
            else if (NumpadSkill(value, physical) > 0)
            {
                int skill = NumpadSkill(value, physical);
                if (skill <= SkillCount()) SetPending(-skill);
                used = true;
            }
            else if (value == Key.Kp0 || physical == Key.Kp0) { SetPending(0); used = true; }
            else if (value == Key.T) { SetPending(5); used = true; }
            else if (value is Key.KpAdd or Key.Equal or Key.Plus || physical == Key.KpAdd)
            { AdjustPendingRange(1); used = true; }
            else if (value is Key.KpSubtract or Key.Minus || physical == Key.KpSubtract)
            { AdjustPendingRange(-1); used = true; }
            else if (value is Key.Enter or Key.KpEnter) { ConfirmAction(); used = true; }
            else if (value == Key.Backspace) { UndoAction(); used = true; }
            else if (value == Key.Escape) { pendingStep = int.MinValue; Refresh(); used = true; }
            else if (value == Key.F) { Send("lock"); used = true; }
        }
        if (!used && BothDeployed)
        {
            if (value == Key.F && MayEdit && !view.Locked[CurrentPlayer - 1]) { Send("lock"); used = true; }
            else if (value == Key.S && view.CanSelect) { Send("select", CurrentFighter()); used = true; }
            else if (value == Key.Space && CurrentPlayer == 1 && !view.Active && !view.RewindPending &&
                view.Selected[0] && view.Selected[1]) { Send("start"); used = true; }

        }
        ReportArenaKey(value, used);
    }

    private static string StepName(int step, int type)
    {
        if (step == 0) return "END";
        if (step == 5) return "TELEPORT";
        if (step > 0) return new[] { "", "UP", "DOWN", "LEFT", "RIGHT" }[Math.Clamp(step, 0, 4)];
        int skill = -step - 1;
        return skill < SkillNames[type].Length ? SkillNames[type][skill].ToUpperInvariant() : "UNKNOWN SKILL";
    }

    private void Refresh()
    {
        if (board == null || screen != Screen.Arena) return;
        int player = CurrentPlayer, id = player - 1;
        if (view != null && view.RewindPending && !previousRewindPending)
        {
            pendingStep = int.MinValue;
            rewindRow = rewindCol = rewindTick = -1;
        }
        previousRewindPending = view != null && view.RewindPending;
        if (view != null && view.Cycle != lastObservedCycle)
        {
            if (lastObservedCycle >= 0)
            {
                for (int i = 0; i < 2; i++) Array.Fill(draftSlots[i], 0);
                draftSlot = 0; pendingStep = int.MinValue; pendingRange = 1;
            }
            lastObservedCycle = view.Cycle;
        }
        bool ready = view != null, own = OwnDeployed, both = BothDeployed;
        bool locked = both && view.Locked[id];
        bool active = both && view.Active;
        int type = CurrentClass;
        if (both && view.TeamSteps.Length > 0)
        {
            view.Steps = CurrentSteps;
            view.Directions = CurrentDirections;
            view.Ranges = CurrentRanges;
        }
        classLabel.Text = $"SELECTED CLASS  /  {ClassNames[Math.Clamp(type, 0, 3)].ToUpperInvariant()}";
        perkLabel.Text = $"TEAM PERK  /  {PerkNames[Math.Clamp(own ? view.Perks[id] : setupPerks[id], 0, 3)].ToUpperInvariant()}";
        for (int i = 0; i < classCards.Length; i++)
        {
            classCards[i].Disabled = own || !ready || !CanDeployNow;
            classCards[i].Modulate = i == setupClasses[id] ? new Color(1f, .87f, .58f) : Colors.White;
        }
        for (int i = 0; i < perkCards.Length; i++)
        {
            int rival = 1 - id;
            bool rivalReserved = ready && view.TeamClasses[rival].Length > 0 &&
                (view.Configured[rival] ? view.Perks[rival] : view.DraftPerks[rival]) == i;
            perkCards[i].Disabled = own || !ready || !CanDeployNow || rivalReserved;
            perkCards[i].Modulate = i == setupPerks[id] ? new Color(1f, .87f, .58f) : Colors.White;
            perkCards[i].TooltipText = rivalReserved ? "Already reserved by the opposing team" :
                "Change your team's perk before finishing deployment";
        }
        rosterLabel.Visible = !own;
        rosterLabel.Text = ready ? $"YOUR PARTY  {view.TeamClasses[id].Length} / 3\n" +
            (view.TeamClasses[id].Length == 0 ? "No fighters yet. Pick a class, perk, then click a tile."
                : string.Join("\n", view.TeamClasses[id].Select((x, i) => $"{i + 1}. {ClassNames[x].ToUpperInvariant()}  •  DEPLOYED"))) : "CONNECTING";
        deployDoneButton.Visible = !own && ready && view.TeamClasses[id].Length > 0 && CanDeployNow;
        undoSpawnButton.Visible = !own && ready && view.TeamClasses[id].Length > 0 && CanDeployNow;
        readyButton.Visible = MayEdit && !locked;
        deployHeader.Visible = !own;
        classChooser.Visible = !own;
        perkChooser.Visible = !own;
        planHeader.Visible = own;
        listLabel.Visible = own;
        actionLabel.Visible = own;
        timeline.Visible = own;
        timerLabel.Visible = both && view.FutureSight;
        timerLabel.Text = timerLabel.Visible ? $"FUTURE SIGHT  ·  {Math.Ceiling(view.FutureSightSeconds):00}s REMAINING" : "";
        for (int i = 0; i < fighterCards.Length; i++)
        {
            bool exists = own && i < view.TeamClasses[id].Length;
            fighterCards[i].Visible = exists;
            if (!exists) continue;
            fighterCards[i].Text = $"{i + 1} / {ClassNames[view.TeamClasses[id][i]].ToUpperInvariant()}";
            fighterCards[i].Modulate = i == ActiveCharacter ? new Color(1f, .87f, .58f) : Colors.White;
        }
        confirmButton.Visible = MayEdit;
        fightHeader.Visible = both;
        fighterButton.Visible = both && view.CanSelect && !view.Selected[id] && !active && !view.RewindPending && view.Outcome == 0;
        exchangeButton.Visible = both && player == 1 && view.CanSelect && view.Selected[0] && view.Selected[1] && !active && !view.RewindPending && view.Outcome == 0;
        advanceButton.Visible = false;
        autoTick.Visible = false;
        skipButton.Visible = both && view.RewindPending && view.DefyOwner == player;
        destinyButton.Visible = skipButton.Visible;
        destinyButton.Disabled = rewindTick < 0 || pendingStep == int.MinValue;
        foresightButton.Visible = both && view.FutureSight && view.Perks[id] == (int)SuperPerk.KingCrimson;
        handoffButton.Visible = false;
        confirmButton.Disabled = !MayEdit || pendingStep == int.MinValue || draftSlot >= CurrentSteps.Length;
        headlineLabel.Text = $"PLAYER {player}  /  " + (!ready ? "CONNECTING" : !own ? "DEPLOY TEAM" :
            !both ? "AWAITING RIVAL" : view.RewindPending ? "DEFY DESTINY" :
            active ? "BATTLE" : view.FutureSight ? "FUTURE SIGHT" :
            locked ? "LOCKED" : MayEdit ? "PLANNING" : "WAITING");
        headlineLabel.AddThemeColorOverride("font_color", player == 1 ? Sea : Rust);
        bannerLabel.Text = !ready ? "WAITING FOR HOST…" :
            view.RewindPending ? "DEFY DESTINY · CHOOSE A MARKED TILE" :
            view.Outcome != 0 ? (view.Outcome == 3 ? "DRAW" : $"PLAYER {view.Outcome} WINS") :
            !own ? "DEPLOY UP TO 3 FIGHTERS" : !both ? "AWAITING RIVAL…" :
            view.Replaying ? $"REPLAYING DESTINY / TICK {view.ExchangeTick + 1}" :
            active ? $"EXCHANGE {view.Exchange + 1} / TICK {view.ExchangeTick + 1}" :
            view.FutureSight ? "REWRITE YOUR FATE" : locked ? "ORDERS SEALED" :
            MayEdit ? "WRITE YOUR BATTLE SCRIPT" :
            lan.Mode == LanSession.SessionMode.Hotseat ? $"WAITING FOR PLAYER {view.PlanningTurn}" : "WAITING FOR RIVAL";
        hintLabel.Text = !own ? "CLICK CLASS + PERK, THEN A GREEN TILE\nPERK CAN CHANGE UNTIL FINISH TEAM" :
            view.RewindPending ? (rewindTick < 0 ? "CLICK A HIGHLIGHTED TILE TO CHOOSE A PAST TICK\nP: ACCEPT THIS EXCHANGE UNCHANGED" :
                $"TICK {rewindTick + 1}: REPLACE YOUR ACTION\nARROWS / NUMPAD: CHOOSE · ENTER: REPLAY") :
            active ? "DUEL PLAYS AUTOMATICALLY · 0.42s/TICK" :
            pendingStep < 0 && pendingStep != int.MinValue ?
                "CLICK AN ATTACK TILE TO AIM · DOTTED = RANGE\nENTER: CONFIRM  ·  ARROWS: AIM TOO" :
            view.FutureSight ? "TAB: NEXT SLOT · ENTER: OVERWRITE\nCLICK A FIGHTER TAB" :
            "ARROWS: MOVE · NUMPAD: CHOOSE ABILITY\nMOUSE: AIM ATTACK · ENTER: SAVE";
        int length = CurrentSteps.Length;
        draftSlot = Math.Clamp(draftSlot, 0, EditingFutureSight ? Math.Max(0, length - 1) : length);
        actionLabel.Text = !own ? "DEPLOY TO UNLOCK ORDERS" :
            view.RewindPending && view.DefyOwner == player ?
            (rewindTick < 0 ? "DEFY DESTINY · CLICK A MARKED TILE" :
                $"REWRITE TICK {rewindTick + 1:00} · " +
                (pendingStep == int.MinValue ? "CHOOSE AN ACTION" : StepName(pendingStep, type) + " · ENTER TO REPLAY")) :
            $"FIGHTER {ActiveCharacter + 1}/{view.TeamClasses[id].Length} · {ClassNames[type].ToUpperInvariant()}\n" +
            (draftSlot >= length ? "SCRIPT FULL / PRESS F" :
            $"SLOT {draftSlot + 1:00} / {length:00}  »  " +
            (pendingStep == int.MinValue ? "AWAITING INPUT" : StepName(pendingStep, type) + $" [DIR {pendingDirection} / RNG {pendingRange}]"));
        if (own)
        {
            timeline.Steps = CurrentSteps;
            timeline.Filled = CurrentCommitted;
            timeline.CharacterClass = type;
            timeline.SelectedSlot = draftSlot;
            timeline.PendingStep = MayEdit ? pendingStep : int.MinValue;
            timeline.CustomMinimumSize = new Vector2(290, Math.Max(65, ((CurrentSteps.Length + 2) / 3) * 43 + 8));
            timeline.QueueRedraw();
            int filledCount = CurrentCommitted.Count(x => x);
            listLabel.Text = $"{filledCount} / {length} CONFIRMED SLOTS\n" +
                (EditingFutureSight ? "TAB: EDIT ANY SLOT" : "ENTER: SAVE CURRENT SLOT") +
                "\nUSE THE SELECT BUTTON TO ENTER THE DUEL";
        }
        else listLabel.Text = "NO ORDERS YET";
        board.ShowDeployment = ready && !own && CanDeployNow;
        board.View = view;
        board.ActiveCharacter = ActiveCharacter;
        board.Committed = CurrentCommitted;
        board.CursorRow = -1;
        board.CursorCol = -1;
        board.ShowPlanningPreview = (own && MayEdit) ||
            (ready && view.RewindPending && view.DefyOwner == player && rewindTick >= 0);
        board.ShowUsedTiles = ready && view.RewindPending;
        board.RewindChoiceMode = ready && view.RewindPending && view.DefyOwner == player;
        board.RewindTick = rewindTick;
        board.RewindSelectedRow = rewindRow;
        board.RewindSelectedCol = rewindCol;
        board.PendingStep = pendingStep;
        board.PendingDirection = pendingDirection;
        board.PendingRange = pendingRange;
        board.PendingSlot = draftSlot;
        board.QueueRedraw();
        keyboardHelp.Visible = own && !view.RewindPending;
        if (view.RewindPending && view.DefyOwner == player)
            listLabel.Text = rewindTick < 0 ? "MARKED TILES SHOW THEIR LATEST TICK NUMBER\nCLICK ONE TO REWRITE THAT MOMENT" :
                $"TICK {rewindTick + 1} / SELECTED TILE ({rewindRow + 1}, {rewindCol + 1})\nPRESS ENTER TO RUN THE REMAINING EXCHANGE";
        waitingLabel.Text = ready ? view.Intel : "CONNECTING TO THE HOST…";
        statusLabel.Text = (ready ? view.Message : lastMessage) +
            (ready && both ? $"     ▪     TICK {view.Tick}     ▪     EXCHANGE {view.Exchange + 1}     ▪     CYCLE {view.Cycle + 1}" : "");
    }
}
