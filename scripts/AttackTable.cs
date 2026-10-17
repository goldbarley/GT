using System.Collections.Generic;

public static class AttackTable
{
    public delegate int[,] Attack(int x, int y, int map);

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static int[,]

    /*
     * MageAttackSingle:
     * x - current x position of the player
     * y - current y position of the player
     * angle - angle of attack (+x-axis is 0 rad)
     * map - map ID
     */
    public static IVector2 MageAttackSingle(int x, int y, float angle, int map)
    {
        IVector2 dst = new IVector2(x, y);

        if (!MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        MapElement [,] mat = MapTable.GetMap(map);

        /* Number of tiles. */
        const int range = 5;

        dst = dst.RotateAcl(angle).Scale(range);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        exit:
        return dst;
    }

    public static IVector2[] MageAttackMultiple(int x, int y, float angle, int map)
    {
        const int natk = 3;
        IVector2[] dst = new IVector2[natk] {
            new IVector2(x, y),
            new IVector2(x, y),
            new IVector2(x, y)
        };

        if (MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        const int range = 4;

        dst[0] = dst[0].RotateAcl(angle).Scale(range);
        dst[1] = dst[1].RotateAcl(angle + 60).Scale(range);
        dst[2] = dst[2].RotateAcl(angle - 120).Scale(range);

        MapTable.UpdateMapTile(dst[0].x, dst[0].y, MapElement.A);
        MapTable.UpdateMapTile(dst[1].x, dst[1].y, MapElement.A);
        MapTable.UpdateMapTile(dst[2].x, dst[2].y, MapElement.A);

        exit:
        return dst;
    }

    //Test Attacks. Replace with specific attacks for characters as needed.
    public static int[,] Attack1(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 3;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 4;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack2(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 5;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 6;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack3(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 7;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 8;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack4(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 9;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 10;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack5(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 3;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 4;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack6(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 5;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 6;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack7(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 7;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 8;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack8(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 9;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 10;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack9(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 3;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 4;
                }
            }
        }

        return matrix;
    }

    public static int[,] Attack10(int x, int y, int map)
    {
        int[,] matrix = MapTable.GetMap(map);
        int rows = matrix.GetLength(0);
        int cols = matrix.GetLength(1);

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                if (r == x && c == y)
                {
                    matrix[r, c] = 5;
                }
                else if (r == x || c == y)
                {
                    matrix[r, c] = 6;
                }
            }
        }

        return matrix;
    }

    //Actual Attacktable. Each index corresponds to a character's attack set.
    public static LinkedList<Attack>[] Attacks =
    {
        new LinkedList<Attack>(new Attack[] { Attack1, Attack2, Attack3, Attack4 }),
        new LinkedList<Attack>(new Attack[] { Attack5, Attack6, Attack7, Attack8 }),
        new LinkedList<Attack>(new Attack[] { Attack9, Attack10, Attack1, Attack2 }),
        new LinkedList<Attack>(new Attack[] { Attack3, Attack4, Attack5, Attack6 }),
    };
}
