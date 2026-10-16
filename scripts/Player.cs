import java.lang.IllegalArgumentException;
//Change everything to csharp syntax.

public class Player {
  private int[] characters;

  public Player(int[] characters) {
    if (characters == null || characters.length != 2)
      throw new IllegalArgumentException("Number of characters can only be 2");
    this.characters = characters;
  }

}
