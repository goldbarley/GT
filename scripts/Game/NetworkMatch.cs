using Godot;
using System;
using System.Text.Json;

public partial class NetworkMatch : Node
{
    public MatchSession Session;
    public string Address = "";
    public event Action<string> StatusChanged;
    public event Action ConnectionLost;
    LanSession transport;
    bool applying;
    double elapsed;
    public bool Active => transport != null && transport.Mode != LanSession.SessionMode.Hotseat;
    public bool CanStart => transport.Mode == LanSession.SessionMode.Host && transport.GuestConnected;
    public int LocalPlayer => transport.Mode == LanSession.SessionMode.Client ? 2 : 1;
    public bool Ready => transport.Mode == LanSession.SessionMode.Host
        ? transport.GuestConnected
        : Multiplayer.MultiplayerPeer.GetConnectionStatus() == MultiplayerPeer.ConnectionStatus.Connected;

    public sealed class Command
    {
        public string Name { get; set; }
        public int[] Arguments { get; set; } = Array.Empty<int>();
        public int Viewer { get; set; }
        public int Fighter { get; set; }
        public int Slot { get; set; }
        public int Direction { get; set; }
        public int Range { get; set; }
        public int Action { get; set; }
        public int Phase { get; set; }
        public double Delta { get; set; }
        public bool AnimationHold { get; set; }
        public long Sequence { get; set; }
    }

    long sequence;

    public override void _Ready()
    {
        transport = new LanSession { Name = "Transport" }; AddChild(transport);
        Session.Intercept = Intercept;
        transport.StatusChanged += status => StatusChanged?.Invoke(status);
        transport.ConnectionLost += () => ConnectionLost?.Invoke();
        transport.GuestLeft += () => ConnectionLost?.Invoke();
        transport.GuestJoined += () => StatusChanged?.Invoke("Player two joined. Choose a map to begin.");
        transport.CommandReceived += (player, rpcName, json) => {
            if (player != 2) return;
            try
            {
                var command = JsonSerializer.Deserialize<Command>(json);
                if (command == null || command.Name != rpcName || command.Name is "Start" or "Update" || command.Viewer != player
                    || !Valid(command))
                {
                    GD.PushWarning($"Rejected LAN command from player {player}.");
                    return;
                }
                command.Sequence = ++sequence;
                Apply(command);
                transport.SendView(JsonSerializer.Serialize(command));
            }
            catch (JsonException error) { GD.PushWarning($"Rejected malformed LAN command: {error.Message}"); }
        };
        transport.ViewReceived += json => {
            try
            {
                var command = JsonSerializer.Deserialize<Command>(json);
                if (command == null) { GD.PushWarning("Received an empty LAN update."); return; }
                if (command.Name != "Update")
                {
                    if (command.Name == "Start") sequence = 0;
                    if (command.Sequence <= sequence) return;
                    if (command.Sequence != sequence + 1)
                        GD.PushWarning($"LAN command sequence jumped from {sequence} to {command.Sequence}.");
                    sequence = command.Sequence;
                }
                Apply(command);
            }
            catch (JsonException error) { GD.PushWarning($"Rejected malformed host update: {error.Message}"); }
        };
    }

    bool Valid(Command c)
    {
        if (c.Arguments == null || c.Phase != (int)Session.Phase) return false;
        if (c.Viewer < 1 || c.Viewer > 2 || !Session.CanAct(c.Viewer)) return false;
        if (c.Direction < 1 || c.Direction > 4 || c.Range < 1 || c.Range > 15 || c.Fighter < 0 || c.Fighter >= Session.TeamSize || c.Slot < 0 || c.Slot >= Session.CharacterMoveLimit(c.Viewer, c.Fighter) || c.Action < -5 || c.Action > 5) return false;
        return c.Name switch {
            "Start" => c.Arguments.Length == 6,
            "RemoveFighter" => c.Arguments.Length == 2,
            "Deploy" => c.Arguments.Length == 4,
            "SetPerk" => c.Arguments.Length == 2 && c.Arguments[1] >= 0 && c.Arguments[1] <= 3,
            "UndoDeployment" or "ConfirmDeployment" or "ContinueHandoff" or "ClearPlan" or "LockPlan" or "FinishFutureSight" or "ConfirmFighter" => c.Arguments.Length == 1,
            "Edit" => c.Arguments.Length == 2 && c.Arguments[1] >= -5 && c.Arguments[1] <= 5,
            "Rewind" => c.Arguments.Length == 2,
            _ => false
        };
    }

    public Error Host() => transport.Host();
    public Error Join() => transport.Join(Address);
    public void Close() { transport?.Close(); elapsed = 0; }

    bool Intercept(string name, int[] arguments)
    {
        if (!Active || applying) return false;
        EnsureLocal();
        var editor = Session.Mine;
        var command = new Command { Name = name, Arguments = arguments, Viewer = Session.Viewer, Phase = (int)Session.Phase,
            Fighter = editor.Fighter, Slot = editor.Slot, Direction = editor.Direction, Range = editor.Range, Action = editor.Action };
        if (name == "Start" && !CanStart) return true;
        if (name != "Start" && !Session.MyTurn) return true;
        if (name == "Start") sequence = 0;
        command.Sequence = transport.Mode == LanSession.SessionMode.Host ? ++sequence : 0;
        string json = JsonSerializer.Serialize(command);
        if (transport.Mode == LanSession.SessionMode.Client) transport.SendCommand(name, json);
        else { Apply(command); transport.SendView(json); }
        return true;
    }

    void EnsureLocal()
    {
        if (Session.Lan) return;
        Session.Lan = true; Session.Local = LocalPlayer; Session.Viewer = Session.Local;
    }

    void Apply(Command c)
    {
        applying = true;
        try
        {
            EnsureLocal();
            if (c.Name != "Update")
            {
                var editor = Session.Editors[c.Viewer - 1];
                editor.Fighter = c.Fighter; editor.Slot = c.Slot; editor.Direction = c.Direction; editor.Range = c.Range; editor.Action = c.Action;
            }
            switch (c.Name)
            {
                case "Start": Session.Start(false, c.Arguments[2], c.Arguments[3], c.Arguments[4], c.Arguments[5]); break;
                case "Deploy": Session.DeployAs(c.Viewer, (CharacterClass)c.Arguments[1], c.Arguments[2], c.Arguments[3]); break;
                case "SetPerk": Session.SetPerkAs(c.Viewer, c.Arguments[1]); break;
                case "RemoveFighter": Session.RemoveFighterAs(c.Viewer, c.Arguments[1]); break;
                case "UndoDeployment": Session.UndoDeploymentAs(c.Viewer); break;
                case "ConfirmDeployment": Session.ConfirmDeploymentAs(c.Viewer); break;
                case "ContinueHandoff": Session.ContinueHandoffAs(c.Viewer); break;
                case "Edit": Session.EditAs(c.Viewer, c.Arguments[1]); break;
                case "ClearPlan": Session.ClearPlanAs(c.Viewer); break;
                case "LockPlan": Session.LockPlanAs(c.Viewer); break;
                case "FinishFutureSight": Session.FinishFutureSightAs(c.Viewer); break;
                case "ConfirmFighter": Session.ConfirmFighterAs(c.Viewer); break;
                case "Rewind": Session.RewindAs(c.Viewer, c.Arguments[1] != 0); break;
                case "Update":
                    Session.Update(c.Delta, transport.Mode == LanSession.SessionMode.Client ? c.AnimationHold : null);
                    break;
            }
        }
        finally { applying = false; }
    }

    public void Advance(double delta)
    {
        if (!Active) { Session.Update(delta); return; }
        if (transport.Mode != LanSession.SessionMode.Host || !transport.GuestConnected || Session.Phase == MatchPhase.Menu) return;
        elapsed += delta;
        if (elapsed < 0.05) return;
        var c = new Command {
            Name = "Update",
            Delta = elapsed,
            AnimationHold = Session.Phase == MatchPhase.Combat && Session.IsWaitingForAnimations
        };
        elapsed = 0;
        transport.SendView(JsonSerializer.Serialize(c)); Apply(c);
    }
}
