using Godot;

/// <summary>
/// Shared audio preferences in user://audio.cfg. Each save reloads the file so
/// music and effects settings do not overwrite each other.
/// </summary>
public static class AudioSettings
{
    const string Path = "user://audio.cfg";

    public static float Float(string key, float fallback)
    {
        var config = new ConfigFile();
        return config.Load(Path) == Error.Ok
            ? Mathf.Clamp((float)config.GetValue("audio", key, fallback), 0f, 1f)
            : fallback;
    }

    public static bool Bool(string key, bool fallback)
    {
        var config = new ConfigFile();
        return config.Load(Path) == Error.Ok ? (bool)config.GetValue("audio", key, fallback) : fallback;
    }

    public static void Save(string key, Variant value)
    {
        var config = new ConfigFile();
        config.Load(Path);
        config.SetValue("audio", key, value);
        config.Save(Path);
    }
}
