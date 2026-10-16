/// <summary>
/// characterType is a defines which character this character object will act as.
/// 0 for Warrior. 1 for Mage. 2 For Archer. 3 for Tank.
/// </summary>
/// <param name="characterType">The type of the character.</param>
/// <param name="moveorder">The move order for the character.</param>
using System;

public class Character
{
    private int characterType;
    private int[] moveorder;

    public Character(int characterType, int[] moveorder)
    {
        if (!isValidMoveTypeAndMovesetLength(characterType, moveorder.Length))
        {
            throw new ArgumentException("Invalid move type and moveorder length combination");
        }
        this.characterType = characterType;
        this.moveorder = moveorder;
    }

    private bool isValidMoveTypeAndMovesetLength(int characterType, int moveorderLength)
    {
        return (characterType == 0 && moveorderLength == 15)
            || (characterType == 1 && moveorderLength == 10)
            || (characterType == 2 && moveorderLength == 20)
            || (characterType == 3 && moveorderLength == 7);
    }
}
