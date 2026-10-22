using System;
using Godot;

public partial class LanSession : Node
{
    public const int Port = 28461;
    public enum SessionMode { Hotseat, Host, Client }
    public SessionMode Mode { get; private set; } = SessionMode.Hotseat;
    public int LocalPlayer => Mode == SessionMode.Client ? 2 : 1;
    public bool GuestConnected { get; private set; }
    private int guestPeerId;
    public event Action<int, string, string> CommandReceived;
    public event Action<string> ViewReceived;
    public event Action<string> StatusChanged;
    public event Action GuestJoined;
    public event Action GuestLeft;
    public event Action ConnectionLost;
    public event Action ConnectedToHost;

    public override void _Ready()
    {
        Multiplayer.PeerConnected += OnPeerConnected;
        Multiplayer.PeerDisconnected += OnPeerDisconnected;
        Multiplayer.ConnectedToServer += OnConnected;
        Multiplayer.ConnectionFailed += OnConnectionFailed;
        Multiplayer.ServerDisconnected += OnServerDisconnected;
    }

    public Error Host()
    {
        Close();
        ENetMultiplayerPeer peer = new();
        Error result = peer.CreateServer(Port, 1);
        if (result != Error.Ok) { peer.Dispose(); return result; }
        Multiplayer.MultiplayerPeer = peer;
        Mode = SessionMode.Host;
        StatusChanged?.Invoke($"Hosting LAN match · UDP {Port}");
        return Error.Ok;
    }

    public Error Join(string address)
    {
        Close();
        if (string.IsNullOrWhiteSpace(address)) return Error.InvalidParameter;
        ENetMultiplayerPeer peer = new();
        Error result = peer.CreateClient(address.Trim(), Port);
        if (result != Error.Ok) { peer.Dispose(); return result; }
        Multiplayer.MultiplayerPeer = peer;
        Mode = SessionMode.Client;
        StatusChanged?.Invoke($"Connecting to {address.Trim()}:{Port}…");
        return Error.Ok;
    }

    public void Close()
    {
        if (Multiplayer.MultiplayerPeer is ENetMultiplayerPeer enet) enet.Close();
        Multiplayer.MultiplayerPeer = new OfflineMultiplayerPeer();
        Mode = SessionMode.Hotseat;
        guestPeerId = 0;
        GuestConnected = false;
    }

    public void SendCommand(string command, string json)
    {
        if (Mode == SessionMode.Client) RpcId(1, MethodName.RemoteCommand, command, json);
        else CommandReceived?.Invoke(1, command, json);
    }

    public void SendView(string json)
    {
        if (Mode == SessionMode.Host && GuestConnected && guestPeerId > 0)
            RpcId(guestPeerId, MethodName.RemoteView, json);
    }

    public void RequestView()
    {
        if (Mode == SessionMode.Client) RpcId(1, MethodName.RemoteSyncRequest);
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, CallLocal = false, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RemoteCommand(string command, string json)
    {
        int sender = Multiplayer.GetRemoteSenderId();
        if (Mode != SessionMode.Host || !GuestConnected || sender != guestPeerId) return;
        CommandReceived?.Invoke(2, command, json);
    }

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, CallLocal = false, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RemoteSyncRequest()
    {
        if (Mode == SessionMode.Host && Multiplayer.GetRemoteSenderId() == guestPeerId)
            GuestJoined?.Invoke();
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, CallLocal = false, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RemoteView(string json)
    {
        if (Mode == SessionMode.Client) ViewReceived?.Invoke(json);
    }

    private void OnPeerConnected(long id)
    {
        if (Mode != SessionMode.Host) return;
        guestPeerId = checked((int)id);
        GuestConnected = true;
        StatusChanged?.Invoke("Player 2 connected · sending map");
        GuestJoined?.Invoke();
    }

    private void OnPeerDisconnected(long id)
    {
        if (Mode != SessionMode.Host || id != guestPeerId) return;
        guestPeerId = 0;
        GuestConnected = false;
        StatusChanged?.Invoke("Player 2 disconnected");
        GuestLeft?.Invoke();
    }

    private void OnConnected()
    {
        StatusChanged?.Invoke("Connected · requesting battlefield");
        ConnectedToHost?.Invoke();
    }
    private void OnConnectionFailed()
    {
        Close();
        StatusChanged?.Invoke("Connection failed. Check host IP and UDP firewall.");
        ConnectionLost?.Invoke();
    }
    private void OnServerDisconnected()
    {
        Close();
        StatusChanged?.Invoke("Host disconnected.");
        ConnectionLost?.Invoke();
    }
}
