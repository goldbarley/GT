using Godot;
using System.Collections.Generic;

/// <summary>
/// Plays one-shot sound effects from assets/sounds with a small voice pool.
/// Missing files are optional: a hint is printed once and playback is skipped.
/// </summary>
public partial class SoundEffects : Node
{
    public const string BusName = "SFX";
    public const string Folder = "res://assets/sounds/";
    const int VoiceCount = 6;

    static readonly string[] Extensions = { "wav", "ogg", "mp3" };

    readonly AudioStreamPlayer[] voices = new AudioStreamPlayer[VoiceCount];
    readonly Dictionary<string, AudioStream> cache = new();
    readonly HashSet<string> reported = new();
    int next;

    public float Volume { get; private set; } = 0.8f;
    public bool Muted { get; private set; }

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        EnsureBus();
        for (int i = 0; i < voices.Length; i++)
        {
            voices[i] = new AudioStreamPlayer { Name = $"Voice{i}", Bus = BusName };
            AddChild(voices[i]);
        }
        Volume = AudioSettings.Float("sfx_volume", Volume);
        Muted = AudioSettings.Bool("sfx_muted", Muted);
        ApplyVolume();
    }

    public override void _ExitTree()
    {
        foreach (var voice in voices)
        {
            if (voice == null) continue;
            voice.Stop();
            voice.Stream = null;
        }
        cache.Clear();
    }

    public void Play(string sound, float pitchVariation = 0f, float volumeDb = 0f)
    {
        var stream = Load(sound);
        if (stream == null) return;

        var voice = voices[next];
        next = (next + 1) % voices.Length;
        voice.Stream = stream;
        voice.PitchScale = 1f + (float)GD.RandRange(-pitchVariation, pitchVariation);
        voice.VolumeDb = volumeDb;
        voice.Play();
    }

    public void SetVolume(float value)
    {
        Volume = Mathf.Clamp(value, 0f, 1f);
        ApplyVolume();
        AudioSettings.Save("sfx_volume", Volume);
    }

    public void SetMuted(bool muted)
    {
        Muted = muted;
        ApplyVolume();
        AudioSettings.Save("sfx_muted", Muted);
    }

    AudioStream Load(string sound)
    {
        if (cache.TryGetValue(sound, out var cached)) return cached;

        foreach (string extension in Extensions)
        {
            string path = $"{Folder}{sound}.{extension}";
            if (!ResourceLoader.Exists(path)) continue;

            var stream = GD.Load<AudioStream>(path);
            if (stream == null) continue;

            cache[sound] = stream;
            return stream;
        }

        cache[sound] = null;
        if (reported.Add(sound))
            GD.Print($"[SFX] No '{sound}' sound. Add {Folder}{sound}.wav (or .ogg / .mp3) to hear it.");
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
}
