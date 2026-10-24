using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using Godot;

public partial class LanSession : Node
{
    public const int Port = 28461;
    public const int DiscoveryPort = 28462;
    const int MulticastPort = 4445;
    const string MulticastGroup = "224.0.2.60";
    const int ProtocolVersion = 1;
    const double HeartbeatInterval = 1.0;
    const double HeartbeatTimeout = 8.0;
    const double DiscoveryInterval = 1.5;
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
    public event Action DiscoveryChanged;
    readonly Dictionary<string, double> discoveredHosts = new();
    PacketPeerUdp discoverySocket;
    UdpClient multicastListener, multicastAnnouncer;
    bool discoveryEnabled;
    double heartbeatElapsed, hostHeartbeatElapsed, discoveryElapsed, announcementElapsed;
    ulong lastGuestHeartbeat;
    public IReadOnlyList<string> DiscoveredHosts => discoveredHosts.Keys.OrderBy(address => address).ToArray();

    public override void _Ready()
    {
        Multiplayer.PeerConnected += OnPeerConnected;
        Multiplayer.PeerDisconnected += OnPeerDisconnected;
        Multiplayer.ConnectedToServer += OnConnected;
        Multiplayer.ConnectionFailed += OnConnectionFailed;
        Multiplayer.ServerDisconnected += OnServerDisconnected;
    }

    public override void _Process(double delta)
    {
        if (Mode == SessionMode.Host && GuestConnected)
        {
            if (Time.GetTicksMsec() - lastGuestHeartbeat > (ulong)(HeartbeatTimeout * 1000))
                DropGuest("Player 2 connection timed out.");
        }
        else if (Mode == SessionMode.Client && Multiplayer.MultiplayerPeer.GetConnectionStatus() == MultiplayerPeer.ConnectionStatus.Connected)
        {
            heartbeatElapsed += delta;
            hostHeartbeatElapsed += delta;
            if (heartbeatElapsed >= HeartbeatInterval)
            {
                heartbeatElapsed = 0;
                RpcId(1, MethodName.RemoteHeartbeat);
            }
            if (hostHeartbeatElapsed > HeartbeatTimeout)
            {
                Close();
                StatusChanged?.Invoke("Host heartbeat timed out.");
                ConnectionLost?.Invoke();
                return;
            }
        }

        PollDiscovery(delta);
    }

    public void BeginDiscovery()
    {
        if (Mode == SessionMode.Client) return;
        discoveryEnabled = true;
        discoveredHosts.Clear();
        discoveryElapsed = DiscoveryInterval;
        if (Mode == SessionMode.Host) StartDiscoveryListener();
        else StartDiscoveryScanner();
        DiscoveryChanged?.Invoke();
    }

    public Error Host()
    {
        Close();
        ENetMultiplayerPeer peer = new();
        Error result = peer.CreateServer(Port, 1);
        if (result != Error.Ok) { peer.Dispose(); return result; }
        Multiplayer.MultiplayerPeer = peer;
        Mode = SessionMode.Host;
        discoveryEnabled = true;
        StartDiscoveryListener();
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
        heartbeatElapsed = hostHeartbeatElapsed = 0;
        StatusChanged?.Invoke($"Connecting to {address.Trim()}:{Port}…");
        return Error.Ok;
    }

    public void Close()
    {
        discoveryEnabled = false;
        discoverySocket?.Close();
        discoverySocket = null;
        multicastListener?.Close(); multicastListener = null;
        multicastAnnouncer?.Close(); multicastAnnouncer = null;
        discoveredHosts.Clear();
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

    [Rpc(MultiplayerApi.RpcMode.AnyPeer, CallLocal = false, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RemoteHeartbeat()
    {
        int sender = Multiplayer.GetRemoteSenderId();
        if (Mode != SessionMode.Host || !GuestConnected || sender != guestPeerId) return;
        lastGuestHeartbeat = Time.GetTicksMsec();
        RpcId(sender, MethodName.RemoteHeartbeatAck);
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, CallLocal = false, TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    private void RemoteHeartbeatAck()
    {
        if (Mode == SessionMode.Client) hostHeartbeatElapsed = 0;
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
        lastGuestHeartbeat = Time.GetTicksMsec();
        SetPeerTimeout(guestPeerId);
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
        SetPeerTimeout(1);
        heartbeatElapsed = hostHeartbeatElapsed = 0;
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

    void SetPeerTimeout(int peerId)
    {
        if (Multiplayer.MultiplayerPeer is ENetMultiplayerPeer enet)
            enet.GetPeer(peerId)?.SetTimeout(8, 5000, 12000);
    }

    void DropGuest(string reason)
    {
        int lostPeer = guestPeerId;
        if (lostPeer == 0 || !GuestConnected) return;
        guestPeerId = 0;
        GuestConnected = false;
        if (Multiplayer.MultiplayerPeer is ENetMultiplayerPeer enet)
            enet.GetPeer(lostPeer)?.PeerDisconnectNow(0);
        StatusChanged?.Invoke(reason);
        GuestLeft?.Invoke();
    }

    void StartDiscoveryListener()
    {
        discoverySocket?.Close();
        discoverySocket = new PacketPeerUdp();
        Error result = discoverySocket.Bind(DiscoveryPort, "0.0.0.0");
        if (result != Error.Ok)
        {
            discoverySocket = null;
            StatusChanged?.Invoke("LAN discovery unavailable; manual IP entry still works.");
        }
        StartMulticastAnnouncer();
    }

    void StartDiscoveryScanner()
    {
        discoverySocket?.Close();
        discoverySocket = new PacketPeerUdp();
        Error result = discoverySocket.Bind(0, "0.0.0.0");
        if (result != Error.Ok)
        {
            discoverySocket = null;
            StatusChanged?.Invoke("LAN discovery unavailable; manual IP entry still works.");
            StartMulticastListener();
            return;
        }
        discoverySocket.SetBroadcastEnabled(true);
        StartMulticastListener();
    }

    void PollDiscovery(double delta)
    {
        if (!discoveryEnabled) return;
        PollMulticastDiscovery();
        if (Mode == SessionMode.Host)
        {
            announcementElapsed += delta;
            if (announcementElapsed >= DiscoveryInterval)
            {
                announcementElapsed = 0;
                AnnounceHost();
            }
            if (discoverySocket == null) return;
            while (discoverySocket.GetAvailablePacketCount() > 0)
            {
                string request = Encoding.UTF8.GetString(discoverySocket.GetPacket());
                string address = discoverySocket.GetPacketIP();
                int sourcePort = discoverySocket.GetPacketPort();
                if (request != $"PREMOVE_DISCOVER|{ProtocolVersion}" || GuestConnected) continue;
                discoverySocket.SetDestAddress(address, sourcePort);
                discoverySocket.PutPacket(Encoding.UTF8.GetBytes($"PREMOVE_HOST|{ProtocolVersion}|{Port}|Premove"));
            }
            return;
        }

        if (discoverySocket == null) return;
        discoveryElapsed += delta;
        if (discoveryElapsed >= DiscoveryInterval)
        {
            discoveryElapsed = 0;
            byte[] request = Encoding.UTF8.GetBytes($"PREMOVE_DISCOVER|{ProtocolVersion}");
            foreach (string address in GetBroadcastAddresses())
            {
                if (discoverySocket.SetDestAddress(address, DiscoveryPort) != Error.Ok) continue;
                discoverySocket.PutPacket(request);
            }
        }
        bool changed = false;
        while (discoverySocket.GetAvailablePacketCount() > 0)
        {
            string response = Encoding.UTF8.GetString(discoverySocket.GetPacket());
            string address = discoverySocket.GetPacketIP();
            string[] fields = response.Split('|');
            if (fields.Length != 4 || fields[0] != "PREMOVE_HOST" || fields[1] != ProtocolVersion.ToString() || fields[2] != Port.ToString()) continue;
            if (!discoveredHosts.ContainsKey(address)) changed = true;
            discoveredHosts[address] = Time.GetTicksMsec() / 1000.0;
        }
        double now = Time.GetTicksMsec() / 1000.0;
        foreach (string address in discoveredHosts.Where(entry => now - entry.Value > 6).Select(entry => entry.Key).ToArray())
        { discoveredHosts.Remove(address); changed = true; }
        if (changed) DiscoveryChanged?.Invoke();
    }

    void StartMulticastListener()
    {
        try
        {
            multicastListener?.Close();
            multicastListener = new UdpClient(AddressFamily.InterNetwork);
            multicastListener.ExclusiveAddressUse = false;
            multicastListener.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            multicastListener.Client.Bind(new IPEndPoint(IPAddress.Any, MulticastPort));
            multicastListener.Client.Blocking = false;
            IPAddress group = IPAddress.Parse(MulticastGroup);
            bool joined = false;
            foreach (IPAddress address in GetLocalIPv4Addresses())
            {
                try
                {
                    multicastListener.JoinMulticastGroup(group, address);
                    joined = true;
                }
                catch (SocketException) { }
            }
            if (!joined) multicastListener.JoinMulticastGroup(group);
        }
        catch (SocketException error)
        {
            multicastListener?.Close(); multicastListener = null;
            GD.PushWarning($"LAN multicast listener unavailable: {error.Message}");
        }
    }

    void StartMulticastAnnouncer()
    {
        try
        {
            multicastAnnouncer?.Close();
            multicastAnnouncer = new UdpClient(AddressFamily.InterNetwork);
            multicastAnnouncer.Client.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastTimeToLive, 1);
            announcementElapsed = DiscoveryInterval;
        }
        catch (SocketException error)
        {
            multicastAnnouncer?.Close(); multicastAnnouncer = null;
            GD.PushWarning($"LAN multicast announcements unavailable: {error.Message}");
        }
    }

    void AnnounceHost()
    {
        if (multicastAnnouncer == null) return;
        byte[] packet = Encoding.UTF8.GetBytes($"[MOTD]Premove[/MOTD][AD]{Port}[/AD][APP]PREMOVE[/APP][V]{ProtocolVersion}[/V]");
        try { multicastAnnouncer.Send(packet, packet.Length, new IPEndPoint(IPAddress.Parse(MulticastGroup), MulticastPort)); }
        catch (SocketException error) { GD.PushWarning($"LAN multicast announcement failed: {error.Message}"); }
    }

    void PollMulticastDiscovery()
    {
        if (multicastListener == null) return;
        bool changed = false;
        try
        {
            while (multicastListener.Available > 0)
            {
                IPEndPoint sender = new(IPAddress.Any, 0);
                string packet = Encoding.UTF8.GetString(multicastListener.Receive(ref sender));
                if (!packet.Contains("[APP]PREMOVE[/APP]", StringComparison.Ordinal)
                    || !packet.Contains($"[V]{ProtocolVersion}[/V]", StringComparison.Ordinal)) continue;
                int start = packet.IndexOf("[AD]", StringComparison.Ordinal) + 4;
                int end = packet.IndexOf("[/AD]", start, StringComparison.Ordinal);
                if (start < 4 || end <= start || !int.TryParse(packet[start..end], out int port) || port != Port) continue;
                string address = sender.Address.ToString();
                if (!discoveredHosts.ContainsKey(address)) changed = true;
                discoveredHosts[address] = Time.GetTicksMsec() / 1000.0;
            }
        }
        catch (SocketException error)
        {
            GD.PushWarning($"LAN multicast receive stopped: {error.Message}");
            multicastListener.Close(); multicastListener = null;
        }
        if (changed) DiscoveryChanged?.Invoke();
    }

    static IEnumerable<IPAddress> GetLocalIPv4Addresses()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(adapter => adapter.OperationalStatus == OperationalStatus.Up && adapter.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .SelectMany(adapter => adapter.GetIPProperties().UnicastAddresses)
                .Select(address => address.Address)
                .Where(address => address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(address))
                .Distinct()
                .ToArray();
        }
        catch (NetworkInformationException) { return Array.Empty<IPAddress>(); }
    }

    static IEnumerable<string> GetBroadcastAddresses()
    {
        var addresses = new HashSet<string> { "255.255.255.255" };
        try
        {
            foreach (NetworkInterface adapter in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (adapter.OperationalStatus != OperationalStatus.Up || adapter.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                    continue;
                foreach (UnicastIPAddressInformation unicast in adapter.GetIPProperties().UnicastAddresses)
                {
                    if (unicast.Address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork || unicast.IPv4Mask == null)
                        continue;
                    byte[] ip = unicast.Address.GetAddressBytes();
                    byte[] mask = unicast.IPv4Mask.GetAddressBytes();
                    byte[] broadcast = new byte[4];
                    for (int i = 0; i < broadcast.Length; i++) broadcast[i] = (byte)(ip[i] | ~mask[i]);
                    addresses.Add(new IPAddress(broadcast).ToString());
                }
            }
        }
        catch (NetworkInformationException) { }
        return addresses;
    }
}
