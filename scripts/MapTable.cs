public enum MapElement : byte
{
    G = 0, // Ground
    W = 1, // Wall
    D = 2, // Damage
    K = 3, // Killzone
    A = 4 // Attack affected areas
}

public class MapTable
{
    private static readonly MapElement[,,] maps =
    {
        {
            { W, W, W, W, W, W, W, W, W, W, W, W, W, W, W },
            { W, G, G, G, G, G, G, G, G, G, G, G, G, G, W },
            { W, G, W, W, G, G, D, D, G, G, W, G, G, G, W },
            { W, G, G, W, G, G, D, G, G, G, W, G, K, G, W },
            { W, G, G, G, G, G, G, G, W, G, G, G, K, G, W },
            { W, G, D, D, G, W, W, G, W, G, G, G, G, G, W },
            { W, G, D, G, G, G, G, G, G, G, W, W, G, G, W },
            { W, G, G, G, W, G, K, K, G, G, G, G, G, G, W },
            { W, G, G, G, G, G, G, G, G, G, G, G, G, G, W },
            { W, W, W, W, W, W, W, W, W, W, W, W, W, W, W },
        },
        {
            { W, W, W, W, W, W, W, W, W, W, W, W, W, W, W },
            { W, G, G, G, W, G, G, G, G, G, G, G, G, G, W },
            { W, G, D, G, W, G, W, W, W, G, K, K, G, G, W },
            { W, G, D, G, G, G, G, G, G, W, G, K, G, G, W },
            { W, G, G, G, W, W, G, G, G, G, G, G, W, G, W },
            { W, G, W, G, G, G, G, D, D, G, W, G, W, G, W },
            { W, G, W, G, K, K, G, D, G, G, W, G, G, G, W },
            { W, G, G, G, K, G, G, G, G, G, G, G, D, G, W },
            { W, G, G, G, G, G, G, G, W, G, G, G, G, G, W },
            { W, W, W, W, W, W, W, W, W, W, W, W, W, W, W },
        },
    };

    /* This function assumes that x, y are valid. */
    public static void UpdateMapTile(int x, int y, int map,
                                     MapElement e)
    {
        if (!IsValidMap(map) || )
            return;

        maps[map, y, x] = e;
    }

    public static bool IsValidMap(int index)
    {
        return index < maps.GetLength(0);
    }

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static int[,] GetMap(int index)
    {
        int rows = maps.GetLength(1);
        int cols = maps.GetLength(2);
        int[,] result = new int[rows, cols];

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                result[r, c] = maps[index, r, c];
            }
        }

        return result;
    }
}
