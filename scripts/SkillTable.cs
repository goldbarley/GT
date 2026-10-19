using SkillQueue = FIFOQueue<Skill>;

public enum SkillType
{
    UNKNOWN = 0,
    ATTACK_SINGLE = 1,
    ATTACK_AREA = 2,
    DEFENSE = 3,
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

public enum SkillCooldown
{
    SKILL_UNKNOWN = -1,
    MAGE_ATTACK_SINGLE = 0,
    MAGE_ATTACK_DIAGONAL_QUAD = 2,
    MAGE_ATTACK_AOE = 3,
    MAGE_ATTACK_PILLAR = 3,
    MAGE_DEFENSE_INVINCIBILITY = 4,
    MAGE_DEFENSE_BARRIER = 2,
    MAGE_DEFENSE_TELEPORT = 3,
}

public enum SkillDamage
{
    SKILL_UNKNOWN = 0,
    MAGE_SINGLE_DAMAGE = 15,
    MAGE_DIAGONAL_QUAD_DAMAGE = 10,
    MAGE_AOE_DAMAGE = 20,
    MAGE_PILLAR_DAMAGE = 20,
    MAGE_INVINCIBILITY_DAMAGE = -SkillCooldown.MAGE_DEFENSE_INVINCIBILITY,
    MAGE_BARRIER_DAMAGE = -SkillCooldown.MAGE_DEFENSE_BARRIER,
    MAGE_TELEPORT_DAMAGE = -SkillCooldown.MAGE_DEFENSE_TELEPORT
}

public class Skill
{
    public SkillType type;
    public AttackRange range;
    public DefenseCooldown cooldown;

    public Skill()
    {
        this.type = SkillType.NOTHING;
        this.range = AttackRange.ATTACK_UNKNOWN;
        this.cooldown = DefenseCooldown.DEFENSE_UNKNOWN;
    }

    public Skill(SkillType type, AttackRange range, DefenseCooldown cooldown)
    {
        this.type = type;
        this.range = range;
        this.cooldown = cooldown;
    }
}

public class SkillInfo
{
    CharacterClass charClass;
    SkillType type;
    SkillDamage damage;
    AttackRange range;
}

public static class SkillTable
{
    public delegate SkillCooldown PTF_Skill(in IVector2 rAffected,
                                            float angle, int map);

    public static bool IsValidIndex(int x, int y, int[,] map)
    {
        return x >= 0 && x < map.GetLength(0) && y >= 0 && y < map.GetLength(1);
    }

    public static void GetMageAttackSingle(in IVector2 src, float angle, out IVector2 dst)
    {
        dst = new IVector2(src.y, src.x);
        dst.RotateAcl(angle).Scale(AttackRange.MAGE_ATTACK_SINGLE);
    }

    public static MapElement[,] UpdateMageAttackSingle(in IVector2 v,
                                                       float angle, int map)
    {
        if (!MapTable.IsValidMap(map) || !IsValidIndex(x, y, map))
            goto exit;

        MapTable.UpdateMapTile(v.x, v.y, map, MapElement.A);

        exit:
        return MapTable.GetMap(map);
    }

    private static GetSkill(in SkillInfo info, float angle, in IVector2 src,
                            out IVector2[] dst, out int count)
    {
        dst = new IVector2(src.x, src.y);

        switch (info.type)
        {
            case SkillType.ATTACK_SINGLE:
                count = 1;
                int singleRange;
                switch (info.charClass)
                {
                    case CharacterClass.MAGE:
                        singleRange = AttackRange.MAGE_ATTACK_SINGLE;
                        break;

                    /* TODO: Implement. */
                    case CharacterClass.WARRIOR:
                        break;
                    case CharacterClass.ARCHER:
                        break;
                    case CharacterClass.ORC:
                        break;
                }
                dst.Scale(singleRange).RotateAcl(angle);

                break;

                case SkillType.ATTACK_AREA:
                    int area = 0;
                    switch (info.charClass)
                    {
                        case CharacterClass.MAGE:
                            area = AttackRange.MAGE_ATTACK_AOE_AREA;
                            break;

                        /* TODO: Implement. */
                        case CharacterClass.WARRIOR:
                            break;
                        case CharacterClass.ARCHER:
                            break;
                        case CharacterClass.ORC:
                            break;
                    }
                    break;

        }
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
    static PTF_Skill[][] skills =
    {
        /* 0 - Mage */
        new Skill[] {
            MageAttackSingle,
            MageAttackDiagonalQuad,
            MageAttackAOE,
            MageAttackPillar,
            MageDefenseInvincibility,
            MageDefenseBarrier,
            MageDefenseTeleport,
        },

        /* 1 - Archer */
        new Skill[] {
            ArcherAttackSingle,
            ArcherAttackTriple,
            ArcherAttackAOE,
            ArcherAttackPoison,
            ArcherDefenseCounter,
            ArcherDefenseSpeed,
        },
        new Skill[] { },
        new Skill[] { },
    };
}
