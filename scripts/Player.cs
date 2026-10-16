using System;

public class Player
{
    private Character[] characters;

    public Player(Character[] characters)
    {
        if (characters == null || characters.Length != 2)
            throw new ArgumentException("Number of characters can only be 2");
        this.characters = characters;
    }
}
