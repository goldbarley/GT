using System;

public enum CharacterClass
{
    MAGE = 0,
    WARRIOR = 1,
    ARCHER = 2,
    ORC = 3,
}

public class Character
{
    CharacterClass cc;
    int[] stepOrder;
    SkillTable.SkillPattern[] skills;
    int[,] skillGrid;
    int HP;
    IVector2 position;
    MapElement[,] map;
    int[] cooldowns;

    public Character(
        CharacterClass cc,
        int[] stepOrder,
        IVector2 charPosition,
        MapElement[,] map,
        int[,] skillGrid
    )
    {
        this.cc = cc;
        if (!isValidMoveTypeAndMovesetLength((int)cc, stepOrder.Length))
            throw new ArgumentException("Invalid Character and StepSet combination.");
        this.stepOrder = stepOrder;
        skills = SkillTable.skills[(int)cc];
        cooldowns = new int[skills.Length];
        this.map = map;
        this.skillGrid = skillGrid;
        HP = charHP((cc));
        position = charPosition;
    }

    public int charHP(CharacterClass i) =>
        i switch
        {
            CharacterClass.MAGE => 75,
            CharacterClass.WARRIOR => 120,
            CharacterClass.ARCHER => 100,
            CharacterClass.ORC => 200,
            _ => throw new ArgumentException($"not a valid Character ID {i}"),
        };

    public bool isAlive() => HP > 0;

    public bool moveUp()
    {
        if (!MapTable.IsValidIndex(position.x - 1, position.y, map))
            return false;
        if (map[position.x - 1, position.y] == MapElement.W)
            return false;
        position.x--;
        return true;
    }

    public bool moveDown()
    {
        if (!MapTable.IsValidIndex(position.x + 1, position.y, map))
            return false;
        if (map[position.x + 1, position.y] == MapElement.W)
            return false;
        position.x++;
        return true;
    }

    public bool moveLeft()
    {
        if (!MapTable.IsValidIndex(position.x, position.y - 1, map))
            return false;

        if (map[position.x, position.y - 1] == MapElement.W)
            return false;
        position.y--;
        return true;
    }

    public bool moveRight()
    {
        if (!MapTable.IsValidIndex(position.x, position.y + 1, map))
            return false;
        if (map[position.x, position.y + 1] == MapElement.W)
            return false;
        position.y++;
        return true;
    }

    public bool teleport(IVector2 position)
    {
        if (!(position.x == this.position.x || position.y == this.position.y))
            return false;

        this.position = position;
        if (
            !MapTable.IsValidIndex(this.position.x, this.position.y, map)
            || map[position.x, position.y] == MapElement.W
            || map[position.x, position.y] == MapElement.K
        )
            HP = 0;
        return true;
    }

    public void executeSkill(int skill, uint direction, IVector2 length)
    {
        if (cooldowns[skill] <= 0)
            cooldowns[skill] = skills[skill](position, length, direction, ref skillGrid);
    }

    public int[] currentCooldown => (int[])cooldowns.Clone();
    public IVector2 currentPosition => position;
    public int currentHP => HP;

    public void dealDamage(int x)
    {
        HP -= x;
    }

    //Might be needed in the future, who knows, can be useful.
    public void heal(int x)
    {
        HP += x;
    }

    public int[] Cooldowndown()
    {
        for (int i = 0; i < cooldowns.Length; i++)
            cooldowns[i]--;
        return cooldowns;
    }

    public void resetCooldown()
    {
        Array.Fill(cooldowns, 0);
    }

    private bool isValidMoveTypeAndMovesetLength(int charClass, int stepOrderLength)
    {
        return (charClass == 0 && stepOrderLength == 10)
            || (charClass == 1 && stepOrderLength == 15)
            || (charClass == 2 && stepOrderLength == 20)
            || (charClass == 3 && stepOrderLength == 7);
    }
}
