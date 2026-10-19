/// <summary>
/// charClass is a defines which character this character object will act as.
/// 0 for Warrior. 1 for Mage. 2 For Archer. 3 for Tank.
/// </summary>
/// <param name="charClass">The type of the character.</param>
/// <param name="moveorder">The move order for the character.</param>
using System;

public enum CharacterClass
{
    MAGE = 0,
    WARRIOR = 1,
    ARCHER = 2,
    ORC = 3
}

public class SkillSet<CharacterType>
{

}

public class Character
{
    private CharacterClass _class;
    private int[] _moveorder;
    private SkillTable.PTF_UpdateSkill[] _skills;

    public Character(int charClass, int[] moveorder)
    {
        if (!isValidMoveTypeAndMovesetLength(charClass, moveorder.Length))
        {
            throw new ArgumentException("Invalid move type and moveorder length combination");
        }
        this._class = charClass;
        this._moveorder = moveorder;
        this._skills = SkillTable.PTF_UpdateSkill[charClass];
    }

    private bool isValidMoveTypeAndMovesetLength(int charClass, int moveorderLength)
    {
        return (charClass == 0 && moveorderLength == 15)
            || (charClass == 1 && moveorderLength == 10)
            || (charClass == 2 && moveorderLength == 20)
            || (charClass == 3 && moveorderLength == 7);
    }
}
