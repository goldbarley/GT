using System;

public enum CharacterClass { MAGE = 0, WARRIOR = 1, ARCHER = 2, ORC = 3 }

public class Character
{
    CharacterClass cc;
    int[] stepOrder;
    int[] directions;
    IVector2[] lengths;
    SkillTable.SkillPattern[] skills;
    int[,] skillGrid;
    int HP;
    IVector2 position;
    MapElement[,] map;
    int[] cooldowns;
    int teleportCooldown;

    public Character(CharacterClass cc, int[] stepOrder, IVector2 charPosition,
        MapElement[,] map, int[,] skillGrid, int[] directions = null, IVector2[] lengths = null)
    {
        if (!Enum.IsDefined(typeof(CharacterClass), cc))
            throw new ArgumentException("Invalid character class.");
        int expected = cc switch { CharacterClass.MAGE => 10, CharacterClass.WARRIOR => 15,
            CharacterClass.ARCHER => 20, CharacterClass.ORC => 7, _ => 0 };
        if (stepOrder == null || (stepOrder.Length != expected && (stepOrder.Length < 1 || stepOrder.Length > 10)))
            throw new ArgumentException("Invalid Character and StepSet combination.");
        expected = stepOrder.Length;
        if (directions != null && directions.Length != expected || lengths != null && lengths.Length != expected)
            throw new ArgumentException("Parameter arrays must match stepOrder length.");
        this.cc = cc;
        this.stepOrder = (int[])stepOrder.Clone();
        this.directions = directions == null ? new int[expected] : (int[])directions.Clone();
        this.lengths = lengths == null ? new IVector2[expected] : (IVector2[])lengths.Clone();
        for (int i = 0; i < expected; i++)
        {
            if (this.directions[i] == 0) this.directions[i] = 1;
            if (this.lengths[i].x == 0 && this.lengths[i].y == 0) this.lengths[i] = new IVector2(1, 1);
        }
        skills = SkillTable.skills[(int)cc];
        cooldowns = new int[skills.Length];
        foreach (int step in stepOrder)
            if (step > 5 || (step < 0 && -(long)step - 1 >= skills.Length))
                throw new ArgumentException("Step references an invalid action or skill.");
        this.map = map;
        this.skillGrid = skillGrid;
        HP = maxHP();
        position = charPosition;
    }

    public CharacterClass characterClass() => cc;
    public int maxHP() => cc switch { CharacterClass.MAGE => 75, CharacterClass.WARRIOR => 120,
        CharacterClass.ARCHER => 100, CharacterClass.ORC => 200, _ => 0 };
    public bool isAlive() => HP > 0;
    public int currentHP() => HP;
    public IVector2 currentPosition() => position;
    public int[] currentCooldown() => (int[])cooldowns.Clone();
    public int currentTeleportCooldown() => teleportCooldown;
    public int[] getSteps() => (int[])stepOrder.Clone();
    public int[] getDirections() => (int[])directions.Clone();
    public IVector2[] getLengths() => (IVector2[])lengths.Clone();
    public int stepCount() => stepOrder.Length;
    public int getStep(int index) => stepOrder[index];
    public int getDirection(int index) => directions[index];
    public IVector2 getLength(int index) => lengths[index];

    public void setStep(int index, int step, int direction = 1, IVector2 length = default)
    {
        if (index < 0 || index >= stepOrder.Length) throw new ArgumentOutOfRangeException(nameof(index));
        if (step < 0 && (-(long)step - 1 >= skills.Length)) throw new ArgumentException("Invalid skill index.");
        if (step > 5) throw new ArgumentException("Invalid step.");
        if (direction < 1 || direction > 4) throw new ArgumentException("Direction must be 1..4.");
        if (step == 5 && length.x <= 0) throw new ArgumentException("Teleport distance must be positive.");
        stepOrder[index] = step;
        directions[index] = direction;
        lengths[index] = length.x == 0 && length.y == 0 ? new IVector2(1, 1) : length;
    }

    public void setPosition(IVector2 p) => position = p;
    public void setHP(int hp) => HP = Math.Clamp(hp, 0, maxHP());
    public void setCooldowns(int[] values, int teleport)
    {
        if (values.Length != cooldowns.Length) throw new ArgumentException("Wrong cooldown count.");
        cooldowns = (int[])values.Clone();
        teleportCooldown = teleport;
    }
    public void setPlan(int[] steps, int[] dirs, IVector2[] lens)
    {
        if (steps.Length != dirs.Length || steps.Length != lens.Length)
            throw new ArgumentException("Wrong plan length.");
        stepOrder = (int[])steps.Clone(); directions = (int[])dirs.Clone(); lengths = (IVector2[])lens.Clone();
    }
    public void resizeSteps(int length)
    {
        if (length < 1) throw new ArgumentOutOfRangeException(nameof(length));
        Array.Resize(ref stepOrder, length);
        Array.Resize(ref directions, length);
        Array.Resize(ref lengths, length);
    }
    public void dealDamage(int x) { if (x > 0) HP = Math.Max(0, HP - x); }
    public void heal(int x) { if (x > 0 && isAlive()) HP = Math.Min(maxHP(), HP + x); }
    public bool moveUp() => moveTo(new IVector2(position.x - 1, position.y));
    public bool moveDown() => moveTo(new IVector2(position.x + 1, position.y));
    public bool moveLeft() => moveTo(new IVector2(position.x, position.y - 1));
    public bool moveRight() => moveTo(new IVector2(position.x, position.y + 1));
    private bool moveTo(IVector2 p)
    {
        if (!isAlive() || !MapTable.IsValidIndex(p.x, p.y, map) || map[p.x, p.y] == MapElement.W)
            return false;
        position = p;
        if (map[p.x, p.y] == MapElement.K) HP = 0;
        return true;
    }
    public bool teleport(IVector2 p)
    {
        if (!isAlive() || !(p.x == position.x || p.y == position.y)) return false;
        position = p;
        if (!MapTable.IsValidIndex(p.x, p.y, map) || map[p.x, p.y] == MapElement.W || map[p.x, p.y] == MapElement.K)
            HP = 0;
        return true;
    }
    public bool teleportReady() => teleportCooldown <= 0;
    public void useTeleport() => teleportCooldown = 2;

    public bool tryExecuteSkill(int skill, uint direction, IVector2 length, out int[,] effect)
    {
        effect = null;
        if (!isAlive() || skill < 0 || skill >= skills.Length || cooldowns[skill] > 0) return false;
        effect = new int[skillGrid.GetLength(0), skillGrid.GetLength(1)];
        int cooldown = skills[skill](position, length, direction, ref effect);
        cooldowns[skill] = Math.Max(0, cooldown) + 1;
        for (int x = 0; x < effect.GetLength(0); x++)
            for (int y = 0; y < effect.GetLength(1); y++)
                skillGrid[x, y] += effect[x, y];
        return true;
    }
    public void executeSkill(int skill, uint direction, IVector2 length) =>
        tryExecuteSkill(skill, direction, length, out _);
    public int[] Cooldowndown()
    {
        for (int i = 0; i < cooldowns.Length; i++) cooldowns[i]--;
        teleportCooldown--;
        return currentCooldown();
    }
    public void resetCooldown() { Array.Fill(cooldowns, 0); teleportCooldown = 0; }
}
