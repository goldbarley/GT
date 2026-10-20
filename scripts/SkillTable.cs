using Cardinal = uint;
using SkillValue = int;

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

    WARRIOR_ATTACK_STAB = 2, /* 3x1 */
    WARRIOR_ATTACK_AOE = 9, /* 3x3 */
}

public enum SkillDamage
{
    SKILL_UNKNOWN = 0,
    MAGE_SINGLE_DAMAGE = 15,
    MAGE_DIAGONAL_QUAD_DAMAGE = 10,
    MAGE_AOE_DAMAGE = 20,
    MAGE_PILLAR_DAMAGE = 20,
    Barrier_DAMAGE = -20,
    MAGE_BARRIER_DAMAGE = -20,

    WARRIOR_STAB_DAMAGE = 30,
    WARRIOR_AOE_DAMAGE = 15,
    WARRIOR_SHIELD_DAMAGE = -30,
}

// public class Skill
// {
//     public SkillType type;
//     public AttackRange range;
//     public int cooldown;
//
//     public Skill()
//     {
//         this.type = SkillType.UNKNOWN;
//         this.range = AttackRange.ATTACK_UNKNOWN;
//         this.cooldown = int.SKILL_UNKNOWN;
//     }
//
//     public Skill(SkillType type, AttackRange range, int cooldown)
//     {
//         this.type = type;
//         this.range = range;
//         this.cooldown = cooldown;
//     }
// }

// public class SkillInfo
// {
//     CharacterClass charClass;
//     SkillType type;
//     SkillDamage damage;
//     AttackRange range;
// }
//
public static class SkillTable
{
    public static IVector2 skillGridMax;

    public delegate int SkillPattern(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    );

    /* Why is this public? */
    public static bool IsValidIndex(IVector2 v)
    {
        return v.x >= 0 && v.x < skillGridMax.x && v.y >= 0 && v.y < skillGridMax.y;
    }

    private static void _AttackSingle(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        SkillDamage dmg,
        ref SkillValue[,] skillGrid
    )
    {
        if (skillGrid == null)
            return;

        character.ScaleOnAxis(axes, length);
        skillGrid[character.y, character.x] = (int)dmg;
    }

    private static void _AttackAOE(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        SkillDamage dmg,
        ref SkillValue[,] skillGrid
    )
    {
        if (skillGrid == null)
            return;

        character.ScaleOnAxis(axes, length);

        if (!IsValidIndex(character))
            return;

        skillGrid[character.y, character.x] = (int)dmg;

        IVector2[] neburs = new IVector2[]
        {
            new IVector2(-1, -1),
            new IVector2(0, -1),
            new IVector2(1, -1),
            new IVector2(-1, 0),
            new IVector2(1, 0),
            new IVector2(-1, 1),
            new IVector2(0, 1),
            new IVector2(1, 1),
        };

        IVector2 affReg = character;
        for (int i = 0; i < 8; ++i)
        {
            affReg = character;
            affReg.Add(neburs[i]);
            if (!IsValidIndex(affReg))
                continue;
            skillGrid[affReg.y, affReg.x] = (int)dmg;
        }
    }

    private static void _Defense(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        SkillDamage dmg,
        ref SkillValue[,] skillGrid
    )
    {
        if (skillGrid == null)
            return;

        skillGrid[character.x, character.y] = (int)dmg;
    }

    private static int MageAttackSingle(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _AttackSingle(character, length, axes, SkillDamage.MAGE_SINGLE_DAMAGE, ref skillGrid);
        return 1;
    }

    private static int MageAttackAOE(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _AttackAOE(character, length, axes, SkillDamage.MAGE_AOE_DAMAGE, ref skillGrid);
        return 3;
    }

    private static int MageDefenseBarrier(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _Defense(character, length, axes, SkillDamage.Barrier_DAMAGE, ref skillGrid);
        return 1;
    }

    private static int WarriorAttackSingle(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _AttackSingle(character, length, axes, SkillDamage.WARRIOR_STAB_DAMAGE, ref skillGrid);
        return 0;
    }

    private static int WarriorAttackAOE(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _AttackAOE(character, length, axes, SkillDamage.WARRIOR_AOE_DAMAGE, ref skillGrid);
        return 2;
    }

    private static int WarriorDefenseShield(
        IVector2 character,
        IVector2 length,
        Cardinal axes,
        ref SkillValue[,] skillGrid
    )
    {
        _Defense(character, length, axes, SkillDamage.WARRIOR_SHIELD_DAMAGE, ref skillGrid);
        return 1;
    }

    public static SkillPattern[][] skills =
    {
        /* 0 - Mage */
        new SkillPattern[]
        {
            MageAttackSingle, // Implemented.
            // MageAttackDiagonalQuad, // Not implemented.
            MageAttackAOE, // Implemented.
            // MageAttackPillar, // Not implemented.
            MageDefenseBarrier, // Not implemented.
            // MageDefenseBarrier, // Not implemented.
            // MageDefenseTeleport, // Not implemented.
        },
        /* 1 - Warrior */
        new SkillPattern[]
        {
            WarriorAttackSingle, // Implemented.
            WarriorAttackAOE, // Implemented.
            // WarriorDefenseShield, // Not implemented.
        },
        /* 2 - Archer */
        new SkillPattern[]
        {
            // ArcherAttackSingle, // Not implemented.
            // ArcherAttackTriple, // Not implemented.
            // ArcherAttackAOE, // Not implemented.
            // ArcherAttackPoison, // Not implemented.
            // ArcherDefenseCounter, // Not implemented.
            // ArcherDefenseSpeed, // Not implemented.
        },
        /* 3 - Orc */
        new SkillPattern[] { },
    };
}
