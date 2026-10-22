using System;
using System.Linq;
using Godot;
using static System.StringComparison;

public enum MapElement : byte
{
    G = 0, // Ground
    W = 1, // Wall
    D = 2, // Damage
    K = 3, // Killzone
    S = 4, // Stairs
}

public record MapContainer(string name, MapElement[,] map);

public static class MapTable
{
    private static Variant[] mapFiles;
    private static readonly MapElement[][,] maps;
    private static string[] mapNames;

    static MapTable()
    {
        mapNames = DirAccess
            .GetFilesAt("res://data/")
            .Where(path => path.EndsWith(".json", OrdinalIgnoreCase))
            .Order()
            .ToArray();
        mapFiles = mapNames
            .Select(path =>
                NotNil(Json.ParseString(FileAccess.GetFileAsString($"res://data/{path}")), path)
            )
            .ToArray();

        mapNames = mapNames.Select(System.IO.Path.GetFileNameWithoutExtension).ToArray();

        maps = new MapElement[mapFiles.Length][,];

        for (byte i = 0; i < mapFiles.Length; i++)
        {
            var matrix = mapFiles[i].AsGodotDictionary()["matrix"].AsGodotArray();
            int rows = matrix.Count;
            int cols = matrix[0].AsGodotArray().Count;
            MapElement[,] map = new MapElement[rows, cols];

            for (int j = 0; j < rows; j++)
            {
                var row = matrix[j].AsGodotArray();
                for (int k = 0; k < cols; k++)
                    map[j, k] = MatToMapElement(row[k].AsUInt16());
            }

            maps[i] = map;
        }
    }

    public static MapElement MatToMapElement(int i)
    {
        switch (i)
        {
            case 0:
                return MapElement.G;
            case 1:
                return MapElement.W;
            case 2:
                return MapElement.K;
            case 3:
                return MapElement.W;
            case 4:
                return MapElement.G;
            case 5:
                    return MapElement.D;
            default:
                throw new ArgumentException($"{i} is not a valid tile element.");
        }
    }

    public static Variant NotNil(Variant x, string path)
    {
        if (x.VariantType == Variant.Type.Nil)
            throw new ArgumentException($"One or More maps are invalid. Current invalid {path}");
        return x;
    }

    public static void IsValidMap(uint index)
    {
        if (!(index < maps.GetLength(0) && index >= 0))
            throw new ArgumentException("Please select a valid map");
    }

    public static bool IsValidIndex(int x, int y, MapElement[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static string[] getMaps() => mapNames;

    public static MapContainer getMap(uint index)
    {
        IsValidMap(index);
        return new MapContainer(mapNames[index], ((MapElement[,])maps[index].Clone()));
    }
}
