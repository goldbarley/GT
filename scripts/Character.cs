//Change to csharp syntax. the entire code.
public class Character {
  private int characterType;
  private int[] moveorder;

  // Turn these comments in XML documentation.
  // characterType is a defines which character this character object will act as.
  // 0 for Warrior. 1 for Mage. 2 For Archer. 3 for Tank.
  public Character(int characterType, int[] moveorder) {
    if (!isValidMoveTypeAndMovesetLength(characterType, moveorder.length)) {
      throw new IllegalArgumentException("Invalid move type and moveorder length combination");
    }
    this.characterType = characterType;
    this.moveorder = moveorder;
  }

  private boolean isValidMoveTypeAndMovesetLength(int characterType, int moveorderLength) {
    return (characterType == 0 && moveorderLength == 15) ||
        (characterType == 1 && moveorderLength == 10) ||
        (characterType == 2 && moveorderLength == 20) ||
        (characterType == 3 && moveorderLength == 7);
  }
}
