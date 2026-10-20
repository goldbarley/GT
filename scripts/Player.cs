using System;

public class Player
{
    private Character[] characters;
    int[,] skillGrid;

    public Player(Character[] characters, uint row, uint col)
    {
        if (characters != null && characters.Length < 4)
            throw new ArgumentException("Number of characters should be between 1-3");
        for (int i = 0; i < characters.Length; i++)
            if (characters[i] == null)
                throw new ArgumentException("Characters should not be NULL");
        skillGrid = new int[row, col];
    }
}
