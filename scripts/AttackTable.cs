using System.Collections.Generic;

public static class AttackTable
{
    public delegate int[,] Attack(int x, int y, int map);

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
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
