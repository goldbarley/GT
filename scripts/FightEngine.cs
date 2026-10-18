public class FightEngine
{
    //Clock Represents Step Number
    private int clock;
    MapElement[,] map;

    public FightEngine(int index)
    {
        clock = -1;
        map = MapTable.GetMap(index);
    }

    public int GetClock() => clock + 1;
}
