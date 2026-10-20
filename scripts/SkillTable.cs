using SkillQueue = FIFOQueue<Skill>;
using Direction = uint;
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

    WARRIOR_ATTACK_SLASH = 0,
    WARRIOR_ATTACK_AOE = 3,
    WARRIOR_DEFENSE_SHIELD = 1
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
    MAGE_TELEPORT_DAMAGE = -SkillCooldown.MAGE_DEFENSE_TELEPORT,

    WARRIOR_STAB_DAMAGE = 30,
    WARRIOR_AOE_DAMAGE = 15,
    WARRIOR_SHIELD_DAMAGE = -SkillCooldown.WARRIOR_DEFENSE_SHIELD
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

/*
 * This is only to conform the BattleEngine API contract.
 * Otherwise it can be safely removed.
 */
public enum Cardinal
{
    UN = Axis2.UNKOWN,
    RS = Axis2.PX,
    BS = Axis2.NY,
    LS = Axis2.NX,
    TS = Axis2.PY,
    BR = Axis2.PXNY,
    BL = Axis2.NXNY,
    TR = Axis2.PXPY,
    TL = Axis2.NXPY,
};

public static class SkillTable
{
    public IVector2 skillGridMax;

    public delegate void SkillPattern(IVector2 player, IVector2 length,
                                      Direction axes,
                                      ref SkillValue[,] skillGrid);

    /* Why is this public? */
    public static bool IsValidIndex(IVector2 v)
    {
        return v.x >= 0 && v.x < skillGridMax.x && v.y >= 0 && v.y < skillGridMax.y;
    }

    private static void _AttackSingle(IVector2 player, IVector2 length,
                                      Direction axes, SkillDamage dmg,
                                      ref SkillValue[,] skillGrid)
    {
        if (skillGrid == null)
            return;

        player.ScaleOnAxis(axes, length);
        skillGrid[player.y, player.x] = dmg;
    }

    private static void _AttackAOE(IVector2 player, IVector2 length,
                                   Direction axes, SkillDamage dmg,
                                   ref SkillValue[,] skillGrid)
    {
        if (skillGrid == null)
            return;

        player.ScaleOnAxis(axes, length);

        if (!IsValidIndex(player))
            return;

        skillGrid[player.y, player.x] = dmg;

        IVector2[] neburs = new IVector2[] {
            new IVector2(-1, -1),
            new IVector2(0, -1),
            new IVector2(1, -1),
            new IVector2(-1, 0),
            new IVector2(1, 0),
            new IVector2(-1, 1),
            new IVector2(0, 1),
            new IVector2(1, 1),
        };

        IVector2 affReg = player;
        for (int i = 0; i < 8; ++i)
        {
            affReg = src;
            if(!IsValidIndex(affReg.Add(neburs[i])))
                continue;
            skillGrid[affReg.y, affReg.x] = dmg;
        }
    }

    private static void _Defense(IVector2 player, IVector2 length,
                                 Direction axes, SkillDamage dmg,
                                 ref SkillGrid[,] skillGrid)
    {
        if (skillGrid == null)
            return;

        skillGrid[player.x, player.y] = dmg;
    }

    private static void MageAttackSingle(IVector2 player, IVector2 length,
                                         Direction axes,
                                         ref SkillValue[,] skillGrid)
    {
        _AttackSingle(player, length, axes, SkillDamage.MAGE_SINGLE_DAMAGE,
                      skillGrid);
    }

    private static void MageAttackAOE(IVector2 player, IVector2 length,
                                      Direction axes,
                                      ref SkillValue[,] skillGrid)
    {
        _AttackAOE(player, length, axes, SkillDamage.MAGE_AOE_DAMAGE,
                   skillGrid);
    }

    private static void MageDefenseInvincibility(IVector2 player, IVector2 length,
                                                 Direction axes,
                                                 ref SkillValue[,] skillGrid)
    {
        _Defense(player, length, axes, SkillDamage.MAGE_INVINCIBILITY_DAMAGE,
                 skillGrid);
    }

    private static void WarriorAttackSingle(IVector2 player, IVector2 length,
                                            Direction axes,
                                            ref SkillValue[,] skillGrid)
    {
        _AttackSingle(player, length, axes, SkillDamage,WARRIOR_STAB_DAMAGE,
                      skillGrid);
    }

    private static void WarriorAttackAOE(IVector2 player, IVector2 length,
                                         Direction axes,
                                         ref SkillValue[,] skillGrid)
    {
        _AttackAOE(player, length, axes, SkillDamage.WARRIOR_AOE_DAMAGE,
                   skillGrid);
    }

    private static void WarriorDefenseShield(IVector2 player, IVector2 length,
                                             Direction axes,
                                             ref SkillValue[,] skillGrid)
    {
        _Defense(player, length, axes, SkillDamage.WARRIOR_SHIELD_DAMAGE,
                 skillGrid);
    }

    static SkillPattern[][] skills =
    {
        /* 0 - Mage */
        new SkillPattern[] {
            MageAttackSingle, // Implemented.
            MageAttackDiagonalQuad, // Not implemented.
            MageAttackAOE, // Implemented.
            MageAttackPillar, // Not implemented.
            MageDefenseInvincibility, // Not implemented.
            MageDefenseBarrier, // Not implemented.
            MageDefenseTeleport, // Not implemented.
        },

        /* 1 - Warrior */
        new SkillPattern[] {
            WarriorAttackSingle, // Implemented.
            WarriorAttackAOE, // Implemented.
            WarriorDefenseShield // Not implemented.
        },

        /* 2 - Archer */
        new SkillPattern[] {
            ArcherAttackSingle, // Not implemented.
            ArcherAttackTriple, // Not implemented.
            ArcherAttackAOE, // Not implemented.
            ArcherAttackPoison, // Not implemented.
            ArcherDefenseCounter, // Not implemented.
            ArcherDefenseSpeed, // Not implemented.
        },

        /* 3 - Orc */
        new SkillPattern[] { },
    };
}
