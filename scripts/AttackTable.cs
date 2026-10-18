using StepQueue = FIFOQueue<Step>;

public enum StepType
{
    NOTHING = 0,
    ATTACK = 1,
    DEFENSE = 2,
}

/*
 * Covers number of tiles.
 * *_AREA attacks are always square.
 */
public enum AttackRange
{
    ATTACK_UNKNOWN = -1,
    MAGE_ATTACK_SINGLE = 5,
    MAGE_ATTACK_DIAGONAL_QUAD = 4,
    MAGE_ATTACK_AOE = 7,
    MAGE_ATTACK_AOE_AREA = 9, /* 3x3 */
    MAGE_ATTACK_PILLAR_AREA = 1, /* 1x1 */
}

//Updated comment.
/* Duration is measured in steps */
public enum DefenseRoundCooldown
{
    DEFENSE_UNKNOWN = -1,
    MAGE_DEFENSE_INVINCIBILITY = 4,
    MAGE_DEFENSE_BARRIER = 2,
    MAGE_DEFENSE_TELEPORT = 3,
}

public class Step
{
    public StepType type;
    public AttackRange range;
    public DefenseRoundCooldown cooldown;

    public Step()
    {
        this.type = StepType.NOTHING;
        this.range = AttackRange.ATTACK_UNKNOWN;
        this.cooldown = DefenseRoundCooldown.DEFENSE_UNKNOWN;
    }

    public Step(StepType type, AttackRange range, DefenseRoundCooldown cooldown)
    {
        this.type = type;
        this.range = range;
        this.cooldown = cooldown;
    }
}

/*
 * Functions should pull from the attack queue.
 * That has not been implemented yet.
 *
 * DO NOT modify this class.
 * This is completely broken but I have things planned.
 * Ask me (Nilabhro) before modifying.
 */
public static class AttackTable
{
    public delegate int[,] Attack(int x, int y, int map);

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static void GetMageAttackSingle(int x, int y, float angle, out IVector2 dst)
    {
        const int range = 5;
        dst.Set(x, y);
        dst.RotateAcl(angle).Scale(range);
    }

    public static MapElement[,] UpdateMageAttackSingle(int x, int y, float angle, int map)
    {
        if (!MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        /* Number of tiles. */
        const int range = 5;

        IVector2 dst = new IVector2(x, y);
        dst.RotateAcl(angle).Scale(range);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        exit:
        return MapTable.GetMap(map);
    }

    public static MapElement[,] UpdateMageAttackMultiple(int x, int y, float angle, int map)
    {
        const int natk = 3;

        if (MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        const int range = 4;

        IVector2 dst = new IVector2(x, y);

        dst.RotateAcl(angle).Scale(range);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        /* 30 degrees */
        dst.RotateAcl(0.5235987755982988);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        /* 60 degrees */
        dst.RotateCl(1.0471975511965976);
        MapTable.UpdateMapTile(dst.x, dst.y, map, MapElement.A);

        exit:
        return MapTable.GetMap(map);
    }

    //Add Attacks here. Each Array for a Character.
    public static Attack[][] Attacks =
    {
        new Attack[] { },
        new Attack[] { },
        new Attack[] { },
        new Attack[] { },
    };
}
