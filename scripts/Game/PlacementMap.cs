using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

/// The little map that opens when a fighter has to be placed. Only the tiles
/// the fighter may stand on are offered, so a placement cannot land on a wall,
/// a chasm or the other half of the island.
public partial class PlacementMap : Control
{
    public MatchSession Session;
    public event System.Action<int, int> TilePicked;
    public event System.Action<int, int> TileHovered;
    public int CursorRow = 6, CursorCol = 5;
    public int MapIndex = 0;
    int hoverRow = -1, hoverCol = -1;
    int[][] _placementMapMatrix;
    
    Vector2 origin;
    float zoom, tile;

    public PlacementMap()
    {
        MouseFilter = MouseFilterEnum.Stop;
        TextureFilter = TextureFilterEnum.Nearest;
        CustomMinimumSize = new Vector2(620, 540);
    }

    public override void _Ready()
    {
        Resized += Layout;
        Layout();
    }

    void Layout()
    {
        float zoom = Math.Min((Size.X - 12) / 456f, (Size.Y - 12) / 432f);
        var picture = new Rect2((Size - new Vector2(456, 432) * zoom) / 2, new Vector2(456, 432) * zoom);
        origin = picture.Position + new Vector2(47.6f, 47.4f) * zoom;
        tile = 23.9f * zoom;
        // Load the map data for the selected map
        LoadMapData();
    }

    void LoadMapData()
    {
        var maps = new[] { "Grassland_1", "Grassland_2", "Grassland_3", "Volcanic_Ruins_1", "Volcanic_Ruins_2", "Volcanic_Ruins_3" };
        if (MapIndex < 0 || MapIndex >= maps.Length) return;
        var path = $"res://data/{maps[MapIndex]}.json";
        if (!FileAccess.FileExists(path)) return;
        string jsonText = FileAccess.GetFileAsString(path);
        var json = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(jsonText);
        if (!json.TryGetValue("matrix", out var matrixElement)) return;
        _placementMapMatrix = matrixElement.Deserialize<int[][]>();
    }

    public Vector2 Center(int row, int col) => origin + new Vector2(col + 0.5f, row + 0.5f) * tile;
    Rect2 TileRect(int row, int col) => new(origin + new Vector2(col, row) * tile, Vector2.One * tile);

    public override void _GuiInput(InputEvent input)
    {
        if (input is InputEventMouseMotion motion)
        {
            Vector2 local = GetLocalMousePosition() - origin;
            int row = (int)Math.Floor(local.Y / tile), col = (int)Math.Floor(local.X / tile);
            if (row >= 0 && row < 15 && col >= 0 && col < 13)
            {
                hoverRow = row; hoverCol = col;
                TileHovered?.Invoke(row, col);
                QueueRedraw();
            }
            else
            {
                hoverRow = hoverCol = -1;
                TileHovered?.Invoke(-1, -1);
            }
        }
        if (input is InputEventMouseButton mouse && mouse.Pressed && mouse.ButtonIndex == MouseButton.Left)
        {
            Vector2 local = GetLocalMousePosition() - origin;
            int row = (int)Math.Floor(local.Y / tile), col = (int)Math.Floor(local.X / tile);
            if (row >= 0 && row < 15 && col >= 0 && col < 13)
                TilePicked?.Invoke(row, col);
        }
    }

    public override void _Draw()
    {
        if (_placementMapMatrix == null || tile <= 0) return;
        
        // Draw tile colors - use Session.Map for accurate tile types (already converted)
        for (int row = 0; row < 15; row++)
            for (int col = 0; col < 13; col++)
            {
                MapElement t = Session.Map[row, col];
                
                // Base color by tile type (ALWAYS show tile type)
                Color baseColor;
                if (t == MapElement.K)
                    baseColor = new Color("e74c3c", 0.95f);      // Kill zones - RED
                else if (t == MapElement.D)
                    baseColor = new Color("f0d264", 0.95f);       // Damage - YELLOW
                else if (t == MapElement.W)
                    baseColor = new Color("2d1f1a", 0.95f);       // Walls - DARK
                else if (t == MapElement.S)
                    baseColor = new Color("a8dfb2", 0.95f);       // Stairs - GREEN
                else // G (Ground/Grass/Slab)
                    baseColor = new Color("a8dfb2", 0.95f);       // Ground - GREEN
                
                // Dim invalid tiles (walls, kill zones, opponent half, occupied)
                bool canPlace = Session.CanPlace(row, col);
                if (!Session.CanPlace(row, col))
                {
                    // Dim invalid tiles to 35% brightness
                    baseColor = new Color(
                        baseColor.R * 0.35f, 
                        baseColor.G * 0.35f, 
                        baseColor.B * 0.35f, 
                        baseColor.A * 0.85f);
                }
                
                // Opponent's half: very dark overlay
                bool isOpponentHalf = (Session.Viewer == 1 && row >= 8) || (Session.Viewer == 2 && row < 8);
                if (isOpponentHalf)
                {
                    baseColor = new Color("101010", 0.98f);
                }
                
                DrawRect(TileRect(row, col).Grow(-1), baseColor);
                DrawRect(TileRect(row, col), new Color("3a2a1b", 0.20f), false, 1);
            }

        // Draw hover highlight
        if (hoverRow >= 0 && hoverCol >= 0)
        {
            Rect2 hoverRect = TileRect(hoverRow, hoverCol);
            DrawRect(hoverRect.Grow(-2), new Color("f0d264", 0.60f), false, 2);
        }

        // Draw cursor (selected position) - thin white outline
        Rect2 cursorRect = TileRect(CursorRow, CursorCol);
        DrawRect(cursorRect.Grow(-2), new Color("f3eee9"), false, 2);
    }

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

