using Godot;
using System;
using System.Linq;
using System.Threading.Tasks;

/// Drives a whole LAN match from one machine's point of view, so the networked
/// flow can be checked without a second person. Run one instance with
/// --lan-test-host and another with --lan-test-join.
public partial class LanBot : Node
{
    public MatchSession Session;
    public NetworkMatch Network;
    public string Role = "host";
    bool planned, selected, rewound, deployed;

    public async void Run(string role)
    {
        Role = role;
        bool threeFighter = OS.GetCmdlineUserArgs().Contains("--lan-test-three");
        string mapArgument = OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--lan-test-map="));
        int mapIndex = mapArgument != null && int.TryParse(mapArgument["--lan-test-map=".Length..], out int requestedMap)
            ? requestedMap
            : 0;
        string[] maps = MapTable.getMaps();
        if (mapIndex < 0 || mapIndex >= maps.Length)
        {
            GD.Print($"LAN FAIL: invalid map index {mapIndex}");
            GetTree().Quit(1);
            return;
        }
        Network.Address = "127.0.0.1";
        if (role == "host") GD.Print("LAN HOST: " + Network.Host());
        else GD.Print("LAN JOIN: " + Network.Join());
        int waited = 0;
        while (!Network.Ready && waited < 600) { await Frame(); waited++; }
        if (!Network.Ready) { GD.Print("LAN FAIL: no connection"); GetTree().Quit(1); return; }
        GD.Print("LAN " + role.ToUpperInvariant() + ": connected as player " + Network.LocalPlayer);

        if (role == "host") { Session.Start(false, threeFighter ? 3 : 1, mapIndex); }
        while (Session.Phase == MatchPhase.Menu) await Frame();
        if (Session.MapIndex != mapIndex || Session.MapName != maps[mapIndex])
        {
            GD.Print($"LAN FAIL: expected map {maps[mapIndex]}, got {Session.MapName} ({Session.MapIndex})");
            GetTree().Quit(1);
            return;
        }
        GD.Print($"LAN {role.ToUpperInvariant()}: selected map {Session.MapName}");

        while (Session.Phase == MatchPhase.Deploy)
        {
            await Frame();
            if (!deployed && Session.MyTurn)
            {
                deployed = true;
                for (int i = 0; i < Session.TeamSize; i++)
                {
                    var spot = Enumerable.Range(0, Session.Map.GetLength(0))
                        .SelectMany(row => Enumerable.Range(0, Session.Map.GetLength(1))
                            .Select(col => (row, col)))
                        .First(tile => Session.CanPlace(tile.row, tile.col));
                    Session.Deploy(CharacterClass.WARRIOR, spot.row, spot.col);
                    while (Session.Rosters[Session.Local - 1].Count <= i) await Frame();
                }
                Session.SetPerk(Session.Local == 1 ? (int)SuperPerk.DefyDestiny : (int)SuperPerk.Tactician);
                Session.ConfirmDeployment();
            }
        }

        Session.TickSeconds = 0.25;
        MatchPhase last = MatchPhase.Deploy;
        bool connected = true;
        bool sawRewind = false;
        bool sawThirdPlan = false;
        bool sawSelection = false;
        bool sawFullSelectionCycle = false;
        int selectionsThisCycle = 0;
        var selectedFightersThisCycle = new System.Collections.Generic.HashSet<int>();
        int frames = 0;
        while (Session.Phase != MatchPhase.Finished && connected)
        {
            await Frame();
            frames++;
            if (threeFighter && frames > 1200) break;
            sawThirdPlan |= threeFighter
                && Enumerable.Range(0, 3).All(fighter =>
                    BattleEngine.getPlayer(1).getCharacter(fighter).getStep(0) == 2
                    && BattleEngine.getPlayer(2).getCharacter(fighter).getStep(0) == 2);
            if (Session.Phase == MatchPhase.Menu && last != MatchPhase.Menu) { connected = false; break; }
            sawRewind |= Session.Phase == MatchPhase.Rewind;
            if (Session.Phase != last)
            {
                if (Session.Phase == MatchPhase.Planning && selectionsThisCycle == Session.TeamSize)
                {
                    sawFullSelectionCycle = true;
                    selectionsThisCycle = 0;
                    selectedFightersThisCycle.Clear();
                }
                last = Session.Phase;
                planned = selected = rewound = false;
            }
            if (Session.Phase == MatchPhase.Planning && Session.MyTurn && !planned)
            {
                planned = true;
                for (int fighter = 0; fighter < Session.TeamSize; fighter++)
                {
                    Session.Fighter = fighter;
                    Session.Slot = 0;
                    Session.Edit(2);
                    while (BattleEngine.getPlayer((uint)Session.Local).getCharacter(fighter).getStep(0) != 2)
                        await Frame();
                }
                sawThirdPlan |= Session.TeamSize == 3
                    && Enumerable.Range(0, 3).All(fighter =>
                        BattleEngine.getPlayer(1).getCharacter(fighter).getStep(0) == 2
                        && BattleEngine.getPlayer(2).getCharacter(fighter).getStep(0) == 2);
                Session.Fighter = 0;
                Session.Slot = 0;
                Session.LockPlan();
            }
            else if (Session.Phase == MatchPhase.Foresight && !selected) { selected = true; Session.FinishFutureSight(); }
            else if (Session.Phase == MatchPhase.Selection && Session.MyTurn && !selected)
            {
                selected = true;
                sawSelection = true;
                if (BattleEngine.getDetails().selected[Session.Local - 1] >= 0)
                {
                    GD.Print($"LAN {role.ToUpperInvariant()} FAIL: fighter was selected before player confirmation");
                    GetTree().Quit(1);
                    return;
                }
                int fighter = Session.Available(Session.Local).Last();
                if (!selectedFightersThisCycle.Add(fighter))
                {
                    GD.Print($"LAN {role.ToUpperInvariant()} FAIL: fighter {fighter} selected twice in one cycle");
                    GetTree().Quit(1);
                    return;
                }
                selectionsThisCycle++;
                Session.Fighter = fighter;
                Session.ConfirmFighter();
            }
            else if (Session.Phase == MatchPhase.Rewind && !rewound) { rewound = true; Session.Rewind(false); }
            if (threeFighter && sawThirdPlan && sawFullSelectionCycle &&
                Session.Phase == MatchPhase.Combat && BattleEngine.getClock() > 0)
            {
                bool threeFighterPassed = Session.TeamSize == 3 && sawSelection &&
                    Session.MapName == maps[mapIndex];
                GD.Print($"LAN {role.ToUpperInvariant()}: {(threeFighterPassed ? "three-fighter sync passed" : "failed")} map={Session.MapName} fullSelectionCycle={sawFullSelectionCycle} phase={Session.Phase} clock={BattleEngine.getClock()}");
                GetTree().Quit(threeFighterPassed ? 0 : 1);
                return;
            }
        }

        for (int i = 0; i < 180 && connected; i++) await Frame();
        bool passed = connected && sawRewind && sawSelection && BattleEngine.getClock() > 1;
        GD.Print($"LAN {role.ToUpperInvariant()}: {(passed ? "finished" : "failed")} rewind={sawRewind} outcome={BattleEngine.getOutcome()} clock={BattleEngine.getClock()} hp={BattleEngine.getPlayer(1).getCharacter(0).currentHP()}/{BattleEngine.getPlayer(2).getCharacter(0).currentHP()}");
        GetTree().Quit(passed ? 0 : 1);
    }

    async Task Frame() => await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
}
