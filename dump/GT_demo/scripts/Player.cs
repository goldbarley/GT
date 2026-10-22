using System;

public class Player
{
    private Character[] characters;
    int[,] skillGrid;
    SuperPerk perk;
    int selectedCharacter = -1;

    public Player(uint charCount, MapElement[,] map, CharacterClass[] charTypes,
        int[][] charSteps, IVector2[] charPosition, SuperPerk perk,
        int[][] directions = null, IVector2[][] lengths = null)
    {
        if (charCount < 1 || charCount > 3) throw new ArgumentException("Number of characters should be between 1-3.");
        int n = (int)charCount;
        if (charTypes == null || charSteps == null || charPosition == null ||
            charTypes.Length != n || charSteps.Length != n || charPosition.Length != n ||
            (directions != null && directions.Length != n) || (lengths != null && lengths.Length != n))
            throw new ArgumentException("Character array lengths must match charCount.");
        characters = new Character[n];
        skillGrid = new int[map.GetLength(0), map.GetLength(1)];
        for (int i = 0; i < n; i++)
        {
            if (charSteps[i] == null) throw new ArgumentException("Missing step array.");
            foreach (int step in charSteps[i])
                if (step == 5 && perk != SuperPerk.Teleport)
                    throw new ArgumentException("Only a player with Teleport may use step 5.");
            IVector2 p = charPosition[i];
            if (!MapTable.IsValidIndex(p.x, p.y, map) || map[p.x, p.y] == MapElement.W || map[p.x, p.y] == MapElement.K)
                throw new ArgumentException("Character must spawn on safe terrain.");
            characters[i] = new Character(charTypes[i], charSteps[i], p, map, skillGrid,
                directions == null ? null : directions[i], lengths == null ? null : lengths[i]);
        }
        this.perk = perk;
    }

    public SuperPerk getPerk() => perk;
    public int count() => characters.Length;
    public Character getCharacter(int index) => characters[index];
    public Character[] getCharacters() => (Character[])characters.Clone();
    public bool isDefeated()
    {
        foreach (Character c in characters) if (c.isAlive()) return false;
        return true;
    }
    public bool selectCharacter(int index)
    {
        if (index < 0 || index >= characters.Length || !characters[index].isAlive()) return false;
        selectedCharacter = index;
        return true;
    }
    public int getSelectedIndex() => selectedCharacter;
    public Character getSelectedCharacter() => selectedCharacter < 0 ? null : characters[selectedCharacter];
    public void restoreSelection(int index) => selectedCharacter = index;
    public int[,] getCurrentSkillGrid() => (int[,])skillGrid.Clone();
    public void restoreSkillGrid(int[,] values)
    {
        if (values.GetLength(0) != skillGrid.GetLength(0) || values.GetLength(1) != skillGrid.GetLength(1))
            throw new ArgumentException("Wrong skill grid dimensions.");
        Array.Copy(values, skillGrid, values.Length);
    }
    public void clearSkillGrid() => Array.Clear(skillGrid, 0, skillGrid.Length);
    public IVector2[] getCharacterPositions()
    {
        IVector2[] a = new IVector2[characters.Length];
        for (int i = 0; i < a.Length; i++) a[i] = characters[i].currentPosition();
        return a;
    }
    public int[] getCharacterHPs()
    {
        int[] a = new int[characters.Length];
        for (int i = 0; i < a.Length; i++) a[i] = characters[i].currentHP();
        return a;
    }
}
