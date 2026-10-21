using System;

public class Player
{
    private Character[] characters;
    int[,] skillGrid;
    SuperPerk perk;

    public Player(
        uint charCount,
        MapElement[,] map,
        CharacterClass[] charTypes,
        int[][] charSteps,
        IVector2[] charPosition,
        SuperPerk perk
    )
    {
        if (0 < charCount && charCount < 4)
            throw new ArgumentException("Number of characters should be between 1-3");
        characters = new Character[charCount];
        skillGrid = new int[map.GetLength(0), map.GetLength(1)];
        for (int i = 0; i < charCount; i++)
            characters[i] = new Character(
                charTypes[i],
                charSteps[i],
                charPosition[i],
                map,
                skillGrid
            );
        this.perk = perk;
    }
}
