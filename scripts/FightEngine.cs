public class FightEngine
{
    int[,] map;

    public FightEngine(int map)
    {
        this.map = MapTable.GetMap(map);
    }
    //TODO Clock
}
