using Godot;
using System.Collections.Generic;

/// <summary>
/// Plays looping background music from assets/music and remembers the player's volume.
/// Tracks are optional: a missing file is reported once and the game stays silent.
/// </summary>
public partial class MusicPlayer : Node
{
    public const string BusName = "Music";
    public const string Folder = "res://assets/music/";
    const float FadeSeconds = 0.9f;

    static readonly string[] Extensions = { "ogg", "wav", "mp3" };

    readonly AudioStreamPlayer[] players = new AudioStreamPlayer[2];
    readonly Dictionary<string, AudioStream> cache = new();
    readonly HashSet<string> reported = new();
    Tween fade;
    int active;
    string current = "";

    public float Volume { get; private set; } = 0.7f;
    public bool Muted { get; private set; }
    public string CurrentTrack => current;

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        EnsureBus();
        for (int i = 0; i < players.Length; i++)
        {
            players[i] = new AudioStreamPlayer { Name = $"Track{i}", Bus = BusName, VolumeDb = -80f };
            AddChild(players[i]);
        }
        LoadSettings();
        ApplyVolume();
    }

    public void Play(string track)
    {
        if (track == current) return;
        current = track;

        var stream = Load(track);
        var from = players[active];
        int next = 1 - active;
        var to = players[next];
        active = next;

        fade?.Kill();
        fade = null;
        if (stream == null)
        {
            from.Stop();
            to.Stop();
            return;
        }

        to.Stream = stream;
        to.VolumeDb = -80f;
        to.Play();
        fade = CreateTween().SetPauseMode(Tween.TweenPauseMode.Process);
        fade.TweenProperty(from, "volume_db", -80f, FadeSeconds);
        fade.Parallel().TweenProperty(to, "volume_db", 0f, FadeSeconds);
        fade.Chain().TweenCallback(Callable.From(from.Stop));
    }

    public void Stop()
    {
        current = "";
        fade?.Kill();
        fade = null;
        foreach (var player in players) player.Stop();
    }

    public void SetVolume(float value)
    {
        Volume = Mathf.Clamp(value, 0f, 1f);
        ApplyVolume();
        AudioSettings.Save("music_volume", Volume);
    }

    public void SetMuted(bool muted)
    {
        Muted = muted;
        ApplyVolume();
        AudioSettings.Save("music_muted", Muted);
    }

    AudioStream Load(string track)
    {
        if (cache.TryGetValue(track, out var cached)) return cached;

        foreach (string extension in Extensions)
        {
            string path = $"{Folder}{track}.{extension}";
            if (!ResourceLoader.Exists(path)) continue;

            var stream = GD.Load<AudioStream>(path);
            if (stream == null) continue;

            if (stream is AudioStreamOggVorbis ogg) ogg.Loop = true;
            else if (stream is AudioStreamWav wav) wav.LoopMode = AudioStreamWav.LoopModeEnum.Forward;
            else if (stream is AudioStreamMP3 mp3) mp3.Loop = true;

            cache[track] = stream;
            return stream;
        }

        cache[track] = null;
        if (reported.Add(track))
            GD.Print($"[Music] No '{track}' track. Add {Folder}{track}.ogg (or .wav / .mp3) to hear it.");
        return null;
    }

    static void EnsureBus()
    {
        if (AudioServer.GetBusIndex(BusName) >= 0) return;
        AudioServer.AddBus();
        int index = AudioServer.BusCount - 1;
        AudioServer.SetBusName(index, BusName);
        AudioServer.SetBusSend(index, "Master");
    }

    void ApplyVolume()
    {
        int index = AudioServer.GetBusIndex(BusName);
        if (index < 0) return;
        AudioServer.SetBusMute(index, Muted || Volume <= 0.001f);
        AudioServer.SetBusVolumeDb(index, Mathf.LinearToDb(Mathf.Max(Volume, 0.001f)));
    }

    void LoadSettings()
    {
        Volume = AudioSettings.Float("music_volume", Volume);
        Muted = AudioSettings.Bool("music_muted", Muted);
    }
}
