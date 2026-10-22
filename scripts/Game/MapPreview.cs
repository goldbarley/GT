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
        CustomMinimumSize = new Vector2(680, 380);
    }

    public override void _Ready()
    {
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
        var maps = new[] { "Grassland_1", "Grassland_2", "Grassland_3", "Volcanic_Ruins_1", "Volcanic_Ruins_2", "Volcanic_Ruins_3" };
        if (MapIndex < 0 || MapIndex >= maps.Length) return;

        var path = $"res://data/{maps[MapIndex]}.json";
        if (!FileAccess.FileExists(path)) return;

        string jsonText = FileAccess.GetFileAsString(path);
        var json = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(jsonText);
        if (!json.TryGetValue("matrix", out var matrixElement)) return;
        var matrix = matrixElement.Deserialize<int[][]>();
        if (matrix == null) return;

        // Load theme-specific tiles
        string theme = "Grasslands";
        if (json.TryGetValue("theme", out var themeElement))
            theme = themeElement.GetString() ?? "Grasslands";

        // Use theme-specific tile textures
        var tileTextures = GetTileTexturesForTheme(theme);

        int tileSize = 24;
        int cols = 13, rows = 15;
        int mapWidth = cols * 24;
        int mapHeight = rows * 24;

        // Center the map in the control
        float scale = Math.Min(Size.X / mapWidth, Size.Y / mapHeight);
        if (scale < 1f) scale = 1f;
        int scaledTileSize = (int)(24 * scale);
        int scaledWidth = cols * scaledTileSize;
        int scaledHeight = rows * scaledTileSize;
        int offsetX = (int)((Size.X - scaledWidth) / 2);
        int offsetY = (int)((Size.Y - scaledHeight) / 2);

        for (int r = 0; r < rows; r++)
        {
            var row = matrix[r];
            for (int c = 0; c < cols; c++)
            {
                int tileId = row[c];
                MapElement t = MatToMapElement(tileId);

                int x = offsetX + c * scaledTileSize;
                int y = offsetY + r * scaledTileSize;
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