using Godot;
using System;
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
        Network.Address = "127.0.0.1";
        if (role == "host") GD.Print("LAN HOST: " + Network.Host());
        else GD.Print("LAN JOIN: " + Network.Join());
        int waited = 0;
        while (!Network.Ready && waited < 600) { await Frame(); waited++; }
        if (!Network.Ready) { GD.Print("LAN FAIL: no connection"); GetTree().Quit(1); return; }
        GD.Print("LAN " + role.ToUpperInvariant() + ": connected as player " + Network.LocalPlayer);

        if (role == "host") { Session.Start(false, 1); }
        while (Session.Phase == MatchPhase.Menu) await Frame();

        while (Session.Phase == MatchPhase.Deploy)
        {
            await Frame();
            if (!deployed && Session.MyTurn)
            {
                deployed = true;
                int row = Session.Local == 1 ? 6 : 9;
                Session.Deploy(CharacterClass.WARRIOR, row, 5);
                Session.SetPerk(Session.Local == 1 ? (int)SuperPerk.DefyDestiny : (int)SuperPerk.Tactician);
                Session.ConfirmDeployment();
            }
        }

        Session.TickSeconds = 0.25;
        MatchPhase last = MatchPhase.Deploy;
        bool connected = true;
        bool sawRewind = false;
        while (Session.Phase != MatchPhase.Finished && connected)
        {
            await Frame();
            if (Session.Phase == MatchPhase.Menu && last != MatchPhase.Menu) { connected = false; break; }
            sawRewind |= Session.Phase == MatchPhase.Rewind;
            if (Session.Phase != last) { last = Session.Phase; planned = selected = rewound = false; }
            if (Session.Phase == MatchPhase.Planning && Session.MyTurn && !planned)
            {
                planned = true;
                Session.Edit(2);
                Session.LockPlan();
            }
            else if (Session.Phase == MatchPhase.Foresight && !selected) { selected = true; Session.FinishFutureSight(); }
            else if (Session.Phase == MatchPhase.Selection && Session.MyTurn && !selected)
            {
                selected = true;
                Session.ConfirmFighter();
            }
            else if (Session.Phase == MatchPhase.Rewind && !rewound) { rewound = true; Session.Rewind(false); }
        }

        for (int i = 0; i < 180 && connected; i++) await Frame();
        bool passed = connected && sawRewind && BattleEngine.getClock() > 1;
        GD.Print($"LAN {role.ToUpperInvariant()}: {(passed ? "finished" : "failed")} rewind={sawRewind} outcome={BattleEngine.getOutcome()} clock={BattleEngine.getClock()} hp={BattleEngine.getPlayer(1).getCharacter(0).currentHP()}/{BattleEngine.getPlayer(2).getCharacter(0).currentHP()}");
        GetTree().Quit(passed ? 0 : 1);
    }

    async Task Frame() => await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
}
