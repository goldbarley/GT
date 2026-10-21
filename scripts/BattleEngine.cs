using System;

public enum SuperPerk
{
    KingCrimson = 0,
    DefyDestiny = 1,
    Teleport = 2,
    Tactician = 3,
}

public record Snapshot(
    int[,] occupancyGrid,
    uint clock,
    int[,] player1SkillGrid,
    int[,] player2SkillGrid,
    IVector2[] player1CharacterPositions,
    IVector2[] player2CharacterPositions,
    int[] player1CharacterHPs,
    int[] player2CharacterHPs,
    Snapshot next,
    Snapshot prev
);

public static class BattleEngine
{
    static uint clock = 0;
    static Snapshot matchStart;
    static Snapshot currState;
    static Player[] players = new Player[2];
    static bool[] availablePerk = { true, true, true, true };
    static MapContainer map;

    //Positive for Player 1, Negative for Player 2
    static int[,] occupancyGrid;

    public static void setupPlayer(
        uint player,
        uint charCount,
        CharacterClass[] charTypes,
        int[][] charSteps,
        IVector2[] charPositions,
        SuperPerk perk
    )
    {
        if (player > 2 || player < 1)
            throw new ArgumentException($"Player can only be 1 or 2. Wtf is {player}");

        if (!availablePerk[(int)perk])
            throw new ArgumentException($"{perk.ToString()} is not available.");
        if (map == null)
            throw new ArgumentException("Please run setupEngine before setting up Players.");

        players[player - 1] = new Player(
            charCount,
            map.map,
            charTypes,
            charSteps,
            charPositions,
            perk
        );
    }

    public static void setupEngine(uint mapIndex)
    {
        MapTable.IsValidMap(mapIndex);
        map = MapTable.getMap(mapIndex);
        occupancyGrid = new int[map.map.GetLength(0), map.map.GetLength(1)];
    }

    public static MapContainer getCurrentMap() => map;

    public static void resetClock()
    {
        clock = 0;
    }

    public static Snapshot getDetails()
    {
        if (currState != null)
            return currState;
        return generateSnapshot();
    }

    private static Snapshot generateSnapshot()
    {
        return new Snapshot(
            occupancyGrid,
            clock,
            players[0].getCurrentSkillGrid(),
            players[1].getCurrentSkillGrid(),
            players[0].getCharacterPositions(),
            players[1].getCharacterPositions(),
            players[0].getCharacterHPs(),
            players[1].getCharacterHPs(),
            null,
            null
        );
    }
}
