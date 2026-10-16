using System;

public class Player {  
  private int[] characters;

  public Player(int[] characters) {
    if (characters == null || characters.Length != 2)
      throw new ArgumentException("Number of characters can only be 2");
    this.characters = characters;
  }
}
