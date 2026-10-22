using Cardinal = System.UInt32;
using SkillValue = System.Int32;

public enum SkillType { UNKNOWN = 0, ATTACK_SINGLE = 1, ATTACK_AREA = 2, DEFENSE = 3 }

public enum AttackRange
{
    ATTACK_UNKNOWN = -1,
    MAGE_FIREBALL = -1, MAGE_SHIELD = 0, MAGE_METEORITE = -1, MAGE_QUAD_BEAM = 4,
    WARRIOR_SLASH = 1, WARRIOR_STAB = 2, WARRIOR_PLUNGE = 3,
    WARRIOR_EDGE = 2, WARRIOR_SHIELD = 0,
    ARCHER_BASIC = 3, ARCHER_DOUBLE = 5, ARCHER_STRONG = 6, ARCHER_ULTIMATE = -1,

    MAGE_ATTACK_SINGLE = MAGE_FIREBALL, MAGE_ATTACK_DIAGONAL_QUAD = MAGE_QUAD_BEAM,
    MAGE_ATTACK_AOE = MAGE_METEORITE, MAGE_ATTACK_AOE_AREA = 9,
    MAGE_ATTACK_PILLAR_AREA = 1, WARRIOR_ATTACK_STAB = WARRIOR_STAB,
    WARRIOR_ATTACK_AOE = 9
}

public enum SkillDamage
{
    SKILL_UNKNOWN = 0,
    MAGE_FIREBALL = 15, MAGE_SHIELD = -20, MAGE_METEORITE = 30, MAGE_QUAD_BEAM = 15,
    WARRIOR_SLASH = 20, WARRIOR_STAB = 30, WARRIOR_PLUNGE = 25,
    WARRIOR_EDGE = 45, WARRIOR_SHIELD = -30,
    ARCHER_BASIC = 18, ARCHER_DOUBLE = 15, ARCHER_STRONG = 40, ARCHER_ULTIMATE = 25,
    ORC_SMASH_DAMAGE = 28, ORC_AOE_DAMAGE = 20, ORC_GUARD = -25,

    MAGE_SINGLE_DAMAGE = MAGE_FIREBALL, MAGE_DIAGONAL_QUAD_DAMAGE = MAGE_QUAD_BEAM,
    MAGE_AOE_DAMAGE = MAGE_METEORITE, MAGE_PILLAR_DAMAGE = MAGE_METEORITE,
    Barrier_DAMAGE = MAGE_SHIELD, MAGE_BARRIER_DAMAGE = MAGE_SHIELD,
    WARRIOR_STAB_DAMAGE = WARRIOR_STAB, WARRIOR_AOE_DAMAGE = WARRIOR_PLUNGE,
    WARRIOR_SHIELD_DAMAGE = WARRIOR_SHIELD,
    ARCHER_SINGLE_DAMAGE = ARCHER_BASIC, ARCHER_TRIPLE_DAMAGE = ARCHER_DOUBLE,
    ARCHER_AOE_DAMAGE = ARCHER_ULTIMATE, ARCHER_GUARD = -12
}

public static class SkillTable
{

    public delegate int SkillPattern(IVector2 character, IVector2 length, Cardinal axes,
        ref SkillValue[,] skillGrid);

    private static bool Inside(IVector2 p, int[,] grid) =>
        p.x >= 0 && p.y >= 0 && p.x < grid.GetLength(0) && p.y < grid.GetLength(1);

    private static IVector2 Direction(Cardinal axes)
    {
        int x = 0, y = 0;
        if ((axes & (uint)Axis2.PX) != 0) x++;
        if ((axes & (uint)Axis2.NX) != 0) x--;
        if ((axes & (uint)Axis2.PY) != 0) y++;
        if ((axes & (uint)Axis2.NY) != 0) y--;
        return new IVector2(x, y);
    }

    private static int RequestedDistance(IVector2 length, IVector2 direction)
    {
        int value = direction.x != 0 ? length.x : length.y;
        return value > 0 ? value : 1;
    }

    private static IVector2 At(IVector2 origin, IVector2 direction, int distance) =>
        new IVector2(origin.x + direction.x * distance, origin.y + direction.y * distance);

    private static void Mark(IVector2 p, int value, ref int[,] grid)
    {
        if (grid != null && Inside(p, grid)) grid[p.x, p.y] += value;
    }

    private static void Square(IVector2 center, int size, int value, ref int[,] grid)
    {

        int radius = size / 2;
        for (int dx = -radius; dx <= radius; dx++)
            for (int dy = -radius; dy <= radius; dy++)
                Mark(new IVector2(center.x + dx, center.y + dy), value, ref grid);
    }

    private static void Ray(IVector2 origin, IVector2 direction, int distance,
        int value, ref int[,] grid)
    {
        if (direction.x == 0 && direction.y == 0) return;
        for (int i = 1; i <= distance; i++)
        {
            IVector2 p = At(origin, direction, i);
            if (!Inside(p, grid)) break;
            Mark(p, value, ref grid);
        }
    }

    private static int MageFireball(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        IVector2 d = Direction(a);
        Mark(At(p, d, RequestedDistance(l, d)), (int)SkillDamage.MAGE_FIREBALL, ref g);
        return 1;
    }
    private static int MageShield(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(p, (int)SkillDamage.MAGE_SHIELD, ref g);
        return 1;
    }
    private static int MageMeteorite(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        IVector2 d = Direction(a);
        Square(At(p, d, RequestedDistance(l, d)), 3, (int)SkillDamage.MAGE_METEORITE, ref g);
        return 4;
    }
    private static int MageQuadBeam(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {

        for (int dx = -1; dx <= 1; dx += 2)
            for (int dy = -1; dy <= 1; dy += 2)
                Ray(p, new IVector2(dx, dy), 4, (int)SkillDamage.MAGE_QUAD_BEAM, ref g);
        return 3;
    }

    private static int KnightSlash(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(At(p, Direction(a), 1), (int)SkillDamage.WARRIOR_SLASH, ref g);
        return 0;
    }
    private static int KnightStab(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(At(p, Direction(a), 2), (int)SkillDamage.WARRIOR_STAB, ref g);
        return 2;
    }
    private static int KnightPlunge(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        IVector2 d = Direction(a);
        int distance = RequestedDistance(l, d) >= 3 ? 3 : 2;
        Square(At(p, d, distance), 3, (int)SkillDamage.WARRIOR_PLUNGE, ref g);
        return 4;
    }
    private static int KnightEdge(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(At(p, Direction(a), 2), (int)SkillDamage.WARRIOR_EDGE, ref g);
        return 2;
    }
    private static int KnightShield(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(p, (int)SkillDamage.WARRIOR_SHIELD, ref g);
        return 2;
    }

    private static int ArcherBasic(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(At(p, Direction(a), 3), (int)SkillDamage.ARCHER_BASIC, ref g);
        return 1;
    }
    private static int ArcherDouble(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {

        IVector2 d = Direction(a);
        Mark(At(p, d, 4), (int)SkillDamage.ARCHER_DOUBLE, ref g);
        Mark(At(p, d, 5), (int)SkillDamage.ARCHER_DOUBLE, ref g);
        return 3;
    }
    private static int ArcherStrong(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(At(p, Direction(a), 6), (int)SkillDamage.ARCHER_STRONG, ref g);
        return 3;
    }
    private static int ArcherUltimate(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {

        Ray(p, Direction(a), g.GetLength(0) + g.GetLength(1),
            (int)SkillDamage.ARCHER_ULTIMATE, ref g);
        return 4;
    }

    private static int OrcSmash(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        IVector2 d = Direction(a);
        Mark(At(p, d, RequestedDistance(l, d)), (int)SkillDamage.ORC_SMASH_DAMAGE, ref g);
        return 1;
    }
    private static int OrcArea(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        IVector2 d = Direction(a);
        Square(At(p, d, RequestedDistance(l, d)), 3, (int)SkillDamage.ORC_AOE_DAMAGE, ref g);
        return 3;
    }
    private static int OrcGuard(IVector2 p, IVector2 l, Cardinal a, ref int[,] g)
    {
        Mark(p, (int)SkillDamage.ORC_GUARD, ref g);
        return 2;
    }

    public static readonly SkillPattern[][] skills =
    {
        new SkillPattern[] { MageFireball, MageShield, MageMeteorite, MageQuadBeam },
        new SkillPattern[] { KnightSlash, KnightStab, KnightPlunge, KnightEdge, KnightShield },
        new SkillPattern[] { ArcherBasic, ArcherDouble, ArcherStrong, ArcherUltimate },
        new SkillPattern[] { OrcSmash, OrcArea, OrcGuard }
    };
}
