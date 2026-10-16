public class Character {
  private int moveType;
  private int[] moveset;

  public Character(int moveType, int[] moveset) {
    if (!isValidMoveTypeAndMovesetLength(moveType, moveset.length)) {
      throw new IllegalArgumentException("Invalid move type and moveset length combination");
    }
    this.moveType = moveType;
    this.moveset = moveset;
  }

  private boolean isValidMoveTypeAndMovesetLength(int moveType, int movesetLength) {
    return (moveType == 0 && movesetLength == 15) ||
        (moveType == 1 && movesetLength == 10) ||
        (moveType == 2 && movesetLength == 20) ||
        (moveType == 3 && movesetLength == 7);
  }
}
