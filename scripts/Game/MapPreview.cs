using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;

/// Renders a constructed map preview from tile textures based on the map JSON.
public partial class MapPreview : Control
{
    public int MapIndex = 0;
    readonly System.Collections.Generic.Dictionary<MapElement, Texture2D> tileTextures = new();

    public MapPreview()
    {
        TextureFilter = TextureFilterEnum.Nearest;
        MouseFilter = MouseFilterEnum.Ignore;
    }

    public override void _Ready()
    {
        Resized += QueueRedraw;
        LoadTileTextures();
    }

    void LoadTileTextures()
    {
        // Grasslands
        tileTextures[MapElement.G] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Grass_Terrain_Tile.png");
        tileTextures[MapElement.W] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Boulder_on_Grass.png");
        tileTextures[MapElement.K] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Grassy_Pit_Tile.png");
        tileTextures[MapElement.D] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel-Art_Thorny_Grass_Tile.png");
        // Volcanic Ruins
        tileTextures[MapElement.S] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Pixelated_Slate_Dungeon_Floor_Tile.png");
        tileTextures[MapElement.W] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Top_Down_Pixel_Art_Stone_Pillar_Tile.png");  // Override W for volcanic
        tileTextures[MapElement.D] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Pixel_Art_Magma_Flow_Tile.png");
        tileTextures[MapElement.K] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Cracked_Lava_Stone_Tile.png");
    }

    public override void _Draw()
    {
        var maps = MapTable.getMaps();
        if (MapIndex < 0 || MapIndex >= maps.Length) return;

        var path = $"res://data/{maps[MapIndex]}.json";
        if (!FileAccess.FileExists(path)) return;

        string jsonText = FileAccess.GetFileAsString(path);
        var json = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(jsonText);
        if (json == null || !json.TryGetValue("matrix", out var matrixElement)) return;
        var matrix = matrixElement.Deserialize<int[][]>();
        if (matrix == null || matrix.Length == 0 || matrix[0] == null || matrix[0].Length == 0) return;

        // Load theme-specific tiles
        string theme = "Grasslands";
        if (json.TryGetValue("theme", out var themeElement))
            theme = themeElement.GetString() ?? "Grasslands";

        // Use theme-specific tile textures
        var tileTextures = GetTileTexturesForTheme(theme);

        int rows = matrix.Length;
        int cols = matrix[0].Length;
        float padding = 12f;
        float mapWidth = cols * 24f;
        float mapHeight = rows * 24f;

        float scale = Math.Min((Size.X - padding * 2) / mapWidth, (Size.Y - padding * 2) / mapHeight);
        if (scale <= 0f) return;
        float scaledTileSize = 24f * scale;
        float scaledWidth = cols * scaledTileSize;
        float scaledHeight = rows * scaledTileSize;
        float offsetX = (Size.X - scaledWidth) / 2f;
        float offsetY = (Size.Y - scaledHeight) / 2f;

        for (int r = 0; r < rows; r++)
        {
            var row = matrix[r];
            if (row == null) continue;
            for (int c = 0; c < cols; c++)
            {
                if (c >= row.Length) continue;
                int tileId = row[c];
                MapElement t = MatToMapElement(tileId);

                float x = offsetX + c * scaledTileSize;
                float y = offsetY + r * scaledTileSize;
                Rect2 rect = new Rect2(x, y, scaledTileSize, scaledTileSize);

                if (tileTextures.TryGetValue(t, out Texture2D tex) && tex != null)
                {
                    DrawTextureRect(tex, rect, false);
                }
                else
                {
                    DrawRect(rect, Colors.Gray);
                }
            }
        }
    }

    public static System.Collections.Generic.Dictionary<MapElement, Texture2D> GetTileTexturesForTheme(string theme)
    {
        var textures = new System.Collections.Generic.Dictionary<MapElement, Texture2D>();
        if (theme == "Volcanic Ruins")
        {
            textures[MapElement.G] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Pixelated_Slate_Dungeon_Floor_Tile.png");
            textures[MapElement.W] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Top_Down_Pixel_Art_Stone_Pillar_Tile.png");
            textures[MapElement.K] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Cracked_Lava_Stone_Tile.png");
            textures[MapElement.D] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Pixel_Art_Magma_Flow_Tile.png");
            textures[MapElement.S] = GD.Load<Texture2D>("res://assets/tiles/Volcanic Ruins/Pixelated_Slate_Dungeon_Floor_Tile.png");
        }
        else // Grasslands (default)
        {
            textures[MapElement.G] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Grass_Terrain_Tile.png");
            textures[MapElement.W] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Boulder_on_Grass.png");
            textures[MapElement.K] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Grassy_Pit_Tile.png");
            textures[MapElement.D] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel-Art_Thorny_Grass_Tile.png");
            textures[MapElement.S] = GD.Load<Texture2D>("res://assets/tiles/Grasslands/Pixel_Art_Grass_Terrain_Tile.png");
        }
        return textures;
    }

    // Copy of MapTable.MatToMapElement for local use
    MapElement MatToMapElement(int i)
    {
        switch (i)
        {
            case 0: return MapElement.G;
            case 1: return MapElement.W;
            case 2: return MapElement.K;
            case 3: return MapElement.W;
            case 4: return MapElement.S;
            case 5: return MapElement.D;
            default: return MapElement.G;
        }
    }
}