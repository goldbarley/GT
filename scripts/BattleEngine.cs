using System;
using System.Collections.Generic;

public enum SuperPerk { KingCrimson = 0, DefyDestiny = 1, Teleport = 2, Tactician = 3 }

public class Snapshot
{
    public int[,] occupancyGrid;
    public uint clock;
    public int[,] player1SkillGrid, player2SkillGrid;
    public IVector2[] player1CharacterPositions, player2CharacterPositions;
    public int[] player1CharacterHPs, player2CharacterHPs;
    public int[][][] steps, directions;
    public IVector2[][][] lengths;
    public int[][][] cooldowns;
    public int[][] teleportCooldowns;
    public int[] selected;
    public int exchangeTick, exchangeIndex, cycleIndex;
    public bool exchangeActive;
    public bool[] planningLocked;
    public bool futureSightPending;
    public int tacticianReveal;
    public uint rngState;
    public Snapshot next, prev;
}

public static class BattleEngine
{
    const int CollisionDamage = 5;
    const int TerrainDamage = 8;
    static uint clock;
    static Snapshot matchStart, lastHistory, currState;
    static readonly Player[] players = new Player[2];
    static readonly IVector2[][] spawnPositions = new IVector2[2][];
    static readonly bool[] availablePerk = new bool[4];
    static MapContainer map;

    static int[,] occupancyGrid;
    static uint rngState = 0xA341316Cu;
    static int firstPerkPicker;
    static int exchangeTick, exchangeIndex, cycleIndex;
    static bool exchangeActive, rewindPending, defyUsed, futureSightPending;
    static readonly bool[] planningLocked = new bool[2];
    static int tacticianReveal = -1;
    static readonly List<int[,]> lastAttackEffects = new List<int[,]>();

    public static void setupEngine(uint mapIndex, uint seed = 0xA341316Cu)
    {
        map = MapTable.getMap(mapIndex);
        occupancyGrid = new int[map.map.GetLength(0), map.map.GetLength(1)];
        players[0] = players[1] = null;
        spawnPositions[0] = spawnPositions[1] = null;
        Array.Fill(availablePerk, true);
        clock = 0; exchangeTick = exchangeIndex = cycleIndex = 0;
        exchangeActive = rewindPending = defyUsed = futureSightPending = false;
        Array.Fill(planningLocked, false);
        matchStart = lastHistory = currState = null;
        rngState = seed == 0 ? 0xA341316Cu : seed;
        firstPerkPicker = (int)(NextRandom() % 2);
        tacticianReveal = -1;
        lastAttackEffects.Clear();
    }

    public static void setupPlayer(uint player, uint charCount, CharacterClass[] charTypes,
        int[][] charSteps, IVector2[] charPositions, SuperPerk perk,
        int[][] charDirections = null, IVector2[][] charLengths = null)
    {
        if (player < 1 || player > 2) throw new ArgumentException("Player must be 1 or 2.");
        if (map == null) throw new InvalidOperationException("Call setupEngine first.");
        if (!Enum.IsDefined(typeof(SuperPerk), perk)) throw new ArgumentException("Invalid perk.");
        int index = (int)player - 1;
        if (players[index] != null) throw new InvalidOperationException("Player already configured.");
        if (!availablePerk[(int)perk]) throw new ArgumentException("Perk already selected.");
        if (charPositions == null || charPositions.Length != (int)charCount)
            throw new ArgumentException("Character positions must match charCount.");
        int middle = (map.map.GetLength(0) + 1) / 2;
        foreach (IVector2 position in charPositions)
        {
            if (index == 0 ? position.x < 0 || position.x >= middle :
                position.x < middle || position.x >= map.map.GetLength(0))
                throw new ArgumentException($"Player {player} must spawn in their half of the map.");
        }
        Player candidate = new Player(charCount, map.map, charTypes, charSteps,
            charPositions, perk, charDirections, charLengths);
        players[index] = candidate;
        spawnPositions[index] = (IVector2[])charPositions.Clone();
        availablePerk[(int)perk] = false;
        RebuildOccupancy();
        UpdateCurrent();
        if (Ready()) ChooseTacticianReveal();
    }

    public static MapContainer getCurrentMap() => map == null ? null :
        new MapContainer(map.name, (MapElement[,])map.map.Clone());
    public static Player getPlayer(uint player) => GetPlayer(player);
    public static IVector2[] getOpponentSpawnPositions(uint player)
    {
        GetPlayer(player);
        int opponent = 2 - (int)player;
        return spawnPositions[opponent] == null ? Array.Empty<IVector2>() :
            (IVector2[])spawnPositions[opponent].Clone();
    }
    public static uint getClock() => clock;
    public static int getExchangeTick() => exchangeTick;
    public static int getExchangeIndex() => exchangeIndex;
    public static int getCycleIndex() => cycleIndex;
    public static int getFirstPerkPicker() => firstPerkPicker + 1;
    public static bool isExchangeActive() => exchangeActive;
    public static bool needsRewindDecision() => rewindPending;
    public static int getFutureSightSeconds() => 90;

    public static int getOutcome()
    {
        if (!Ready()) return 0;
        bool a = players[0].isDefeated(), b = players[1].isDefeated();
        if (a && b) return 3;
        return a ? 2 : b ? 1 : 0;
    }

    public static void resetClock() { clock = 0; UpdateCurrent(); }
    public static Snapshot getDetails() => Ready() ? Capture() : null;
    public static Snapshot getMatchStart() => matchStart;
    public static Snapshot getCurrentSnapshot() => currState;
    public static int[,] getOccupancyGrid() => occupancyGrid == null ? null : (int[,])occupancyGrid.Clone();

    public static void finishPlanning(uint player)
    {
        if (exchangeActive || rewindPending) throw new InvalidOperationException("Cannot finish planning during combat.");
        int index = (int)player - 1;
        GetPlayer(player);
        if (planningLocked[index]) throw new InvalidOperationException("Planning already locked.");
        planningLocked[index] = true;
        if (planningLocked[0] && planningLocked[1])
            futureSightPending = players[0].getPerk() == SuperPerk.KingCrimson ||
                players[1].getPerk() == SuperPerk.KingCrimson;
        UpdateCurrent();
    }
    public static void finishFutureSight(uint player)
    {
        if (GetPlayer(player).getPerk() != SuperPerk.KingCrimson || !futureSightPending)
            throw new InvalidOperationException("No Future Sight window is open.");
        futureSightPending = false;
        UpdateCurrent();
    }
    public static bool canSelectCharacters() => Ready() && planningLocked[0] && planningLocked[1] && !futureSightPending;

    public static IVector2 previewPosition(uint player, int characterIndex, int throughSlot)
    {
        Character c = GetPlayer(player).getCharacter(characterIndex);
        IVector2 p = c.currentPosition();
        for (int i = 0; i <= throughSlot && i < c.stepCount(); i++)
        {
            int step = c.getStep(i);
            if (step == 0) break;
            if (step < 1 || step > 5) continue;
            if (step == 5 && GetPlayer(player).getPerk() != SuperPerk.Teleport) continue;
            int distance = step == 5 ? c.getLength(i).x : 1;
            if (distance <= 0) continue;
            IVector2 to = Destination(p, step == 5 ? c.getDirection(i) : step, distance);
            if (step == 5)
            {
                if (!Inside(to) || map.map[to.x, to.y] == MapElement.W || map.map[to.x, to.y] == MapElement.K)
                {
                    if (Inside(to)) p = to;
                    break;
                }
                p = to;
            }
            else if (Inside(to) && map.map[to.x, to.y] != MapElement.W)
            {
                p = to;
                if (map.map[p.x, p.y] == MapElement.K) break;
            }
        }
        return p;
    }
    public static void setStep(uint player, int characterIndex, int slot, int step,
        int direction = 1, IVector2 length = default)
    {
        if (exchangeActive || rewindPending) throw new InvalidOperationException("Cannot edit during playback.");
        Player p = GetPlayer(player);
        int owner = (int)player - 1;
        if (planningLocked[owner] && !(futureSightPending && p.getPerk() == SuperPerk.KingCrimson))
            throw new InvalidOperationException("This player's plan is locked.");
        if (step == 5 && p.getPerk() != SuperPerk.Teleport)
            throw new InvalidOperationException("Teleport requires the Teleport perk.");
        p.getCharacter(characterIndex).setStep(slot, step, direction, length);
        UpdateCurrent();
    }
    public static bool selectCharacter(uint player, int characterIndex)
    {
        if (exchangeActive || rewindPending || getOutcome() != 0 || !canSelectCharacters()) return false;
        bool ok = GetPlayer(player).selectCharacter(characterIndex);
        if (ok) UpdateCurrent();
        return ok;
    }
    public static bool startExchange()
    {
        if (!Ready() || exchangeActive || rewindPending || getOutcome() != 0 || !canSelectCharacters()) return false;
        if (players[0].getSelectedCharacter() == null || players[1].getSelectedCharacter() == null)
            return false;
        exchangeTick = 0;
        defyUsed = false;
        exchangeActive = true;
        UpdateCurrent();
        return true;
    }
    public static bool advanceOneTick()
    {
        if (!exchangeActive || rewindPending) return false;
        ResolveTick(-1, 0, 1, new IVector2(1, 1));

        rewindPending = ExchangeComplete() && !defyUsed &&
            (players[0].getPerk() == SuperPerk.DefyDestiny ||
             players[1].getPerk() == SuperPerk.DefyDestiny);
        if (!rewindPending) FinalizeTick();
        UpdateCurrent();
        return true;
    }
    public static bool passRewindDecision(uint player)
    {
        if (!rewindPending || GetPlayer(player).getPerk() != SuperPerk.DefyDestiny) return false;
        rewindPending = false;
        FinalizeTick(); UpdateCurrent();
        return true;
    }
    public static bool tryDefyDestiny(uint player, int replacementStep,
        int direction = 1, IVector2 length = default)
    {
        if (!rewindPending || defyUsed || GetPlayer(player).getPerk() != SuperPerk.DefyDestiny)
            return false;
        int owner = (int)player - 1;
        Character actor = players[owner].getSelectedCharacter();
        if (actor == null) return false;
        if (replacementStep == 5 && players[owner].getPerk() != SuperPerk.Teleport)
            return false;
        if (direction < 1 || direction > 4 || replacementStep > 5 ||
            (replacementStep < 0 && -(long)replacementStep - 1 >= SkillTable.skills[(int)actor.characterClass()].Length))
            return false;

        defyUsed = true;
        rewindPending = false;
        bool success = NextRandom() % 100 < 70;
        if (success)
        {
            uint rngAfterAttempt = rngState;
            Snapshot before = lastHistory;
            if (before == null) throw new InvalidOperationException("No pre-tick snapshot.");
            Snapshot previous = before.prev;
            loadSnapshot(before);

            if (previous == null) matchStart = null;
            else previous.next = null;
            lastHistory = previous;
            rngState = rngAfterAttempt;
            ResolveTick(owner, replacementStep, direction, length);
        }
        FinalizeTick(); UpdateCurrent();
        return success;
    }

    public static void loadSnapshot(Snapshot state)
    {
        if (state == null || !Ready()) throw new ArgumentException("Invalid snapshot.");
        clock = state.clock;
        exchangeTick = state.exchangeTick;
        exchangeIndex = state.exchangeIndex;
        cycleIndex = state.cycleIndex;
        exchangeActive = state.exchangeActive;
        planningLocked[0] = state.planningLocked[0];
        planningLocked[1] = state.planningLocked[1];
        futureSightPending = state.futureSightPending;
        tacticianReveal = state.tacticianReveal;
        rngState = state.rngState;
        for (int p = 0; p < 2; p++)
        {
            Player team = players[p];
            team.restoreSelection(state.selected[p]);
            team.restoreSkillGrid(p == 0 ? state.player1SkillGrid : state.player2SkillGrid);
            for (int i = 0; i < team.count(); i++)
            {
                Character c = team.getCharacter(i);
                c.setPosition(p == 0 ? state.player1CharacterPositions[i] : state.player2CharacterPositions[i]);
                c.setHP(p == 0 ? state.player1CharacterHPs[i] : state.player2CharacterHPs[i]);
                c.setPlan(state.steps[p][i], state.directions[p][i], state.lengths[p][i]);
                c.setCooldowns(state.cooldowns[p][i], state.teleportCooldowns[p][i]);
            }
        }
        RebuildOccupancy();
        rewindPending = false;
        UpdateCurrent();
    }

    public static int[][] getVisibleOpponentSteps(uint player)
    {
        Player viewer = GetPlayer(player);
        Player opponent = players[2 - (int)player];
        if (opponent == null) return Array.Empty<int[]>();
        if (viewer.getPerk() == SuperPerk.KingCrimson && futureSightPending)
        {
            int[][] plans = new int[opponent.count()][];
            for (int i = 0; i < plans.Length; i++) plans[i] = opponent.getCharacter(i).getSteps();
            return plans;
        }
        if (viewer.getPerk() == SuperPerk.Tactician && planningLocked[0] && planningLocked[1] && tacticianReveal >= 0)
            return new int[][] { opponent.getCharacter(tacticianReveal).getSteps() };
        return Array.Empty<int[]>();
    }
    public static int getTacticianRevealedCharacter(uint player) =>
        GetPlayer(player).getPerk() == SuperPerk.Tactician ? tacticianReveal : -1;

    private static void ResolveTick(int overrideOwner, int overrideStep, int overrideDirection, IVector2 overrideLength)
    {
        AppendHistory(Capture());
        lastAttackEffects.Clear();
        players[0].clearSkillGrid(); players[1].clearSkillGrid();
        Character[] active = { players[0].getSelectedCharacter(), players[1].getSelectedCharacter() };
        int[] actions = new int[2];
        int[] dirs = new int[2];
        IVector2[] lengths = new IVector2[2];
        IVector2[] from = new IVector2[2], target = new IVector2[2];
        bool[] moving = new bool[2], fatal = new bool[2];
        int[][] incoming = { new int[players[0].count()], new int[players[1].count()] };
        bool[][] kill = { new bool[players[0].count()], new bool[players[1].count()] };

        for (int p = 0; p < 2; p++)
            foreach (Character c in players[p].getCharacters()) if (c.isAlive()) c.Cooldowndown();

        for (int p = 0; p < 2; p++)
        {
            Character c = active[p];
            from[p] = c.currentPosition(); target[p] = from[p];
            if (!c.isAlive() || exchangeTick >= c.stepCount()) continue;
            actions[p] = c.getStep(exchangeTick);
            dirs[p] = c.getDirection(exchangeTick);
            lengths[p] = c.getLength(exchangeTick);
            if (overrideOwner == p)
            { actions[p] = overrideStep; dirs[p] = overrideDirection; lengths[p] = overrideLength; }
            int a = actions[p];
            if (a < 1 || a > 5) continue;
            if (a == 5 && (players[p].getPerk() != SuperPerk.Teleport || !c.teleportReady())) continue;
            int distance = a == 5 ? lengths[p].x : 1;
            if (distance <= 0) continue;
            target[p] = Destination(from[p], a == 5 ? dirs[p] : a, distance);
            if (a == 5)
            {
                c.useTeleport();
                if (!Inside(target[p]) || map.map[target[p].x, target[p].y] == MapElement.W ||
                    map.map[target[p].x, target[p].y] == MapElement.K)
                { fatal[p] = true; moving[p] = true; continue; }
            }
            else if (!Inside(target[p]) || map.map[target[p].x, target[p].y] == MapElement.W)
                continue;
            moving[p] = true;
        }

        bool swap = moving[0] && moving[1] && !fatal[0] && !fatal[1] &&
            Same(target[0], from[1]) && Same(target[1], from[0]);
        if (!swap && moving[0] && moving[1] && !fatal[0] && !fatal[1] && Same(target[0], target[1]))
        {
            moving[0] = moving[1] = false;
            incoming[0][players[0].getSelectedIndex()] += CollisionDamage;
            incoming[1][players[1].getSelectedIndex()] += CollisionDamage;
        }
        if (!swap)
        {
            for (int p = 0; p < 2; p++)
            {
                if (!moving[p] || fatal[p]) continue;
                int opponent = 1 - p;
                List<int> blockers = new List<int>();
                for (int i = 0; i < players[opponent].count(); i++)
                {
                    Character enemy = players[opponent].getCharacter(i);
                    if (!enemy.isAlive() || !Same(enemy.currentPosition(), target[p])) continue;
                    if (enemy == active[opponent] && moving[opponent] && !fatal[opponent] &&
                        !Same(target[opponent], from[opponent])) continue;
                    blockers.Add(i);
                }
                if (blockers.Count == 0) continue;
                moving[p] = false;
                incoming[p][players[p].getSelectedIndex()] += blockers.Count * CollisionDamage;
                foreach (int i in blockers)
                    incoming[opponent][i] += CollisionDamage / blockers.Count;
            }
        }
        for (int p = 0; p < 2; p++)
        {
            if (!moving[p]) continue;
            active[p].setPosition(target[p]);
            if (fatal[p]) kill[p][players[p].getSelectedIndex()] = true;
            else if (map.map[target[p].x, target[p].y] == MapElement.K)
                kill[p][players[p].getSelectedIndex()] = true;
        }
        RebuildOccupancy();

        List<(int owner, int[,] grid)> casts = new List<(int, int[,])>();
        for (int p = 0; p < 2; p++)
        {
            int action = actions[p];
            if (action >= 0 || !active[p].isAlive() || kill[p][players[p].getSelectedIndex()]) continue;
            int skill = -(action + 1);
            uint axes = DirectionAxis(dirs[p]);
            if (active[p].tryExecuteSkill(skill, axes, lengths[p], out int[,] effect))
            { casts.Add((p, effect)); lastAttackEffects.Add((int[,])effect.Clone()); }
        }
        foreach (var cast in casts)
        {
            int enemyOwner = 1 - cast.owner;
            for (int x = 0; x < cast.grid.GetLength(0); x++)
                for (int y = 0; y < cast.grid.GetLength(1); y++)
                {
                    int damage = cast.grid[x, y];
                    if (damage <= 0) continue;
                    int count = 0;
                    for (int i = 0; i < players[enemyOwner].count(); i++)
                    {
                        Character c = players[enemyOwner].getCharacter(i);
                        if (c.isAlive() && !kill[enemyOwner][i] && Same(c.currentPosition(), new IVector2(x, y))) count++;
                    }
                    if (count == 0) continue;
                    for (int i = 0; i < players[enemyOwner].count(); i++)
                    {
                        Character c = players[enemyOwner].getCharacter(i);
                        if (c.isAlive() && !kill[enemyOwner][i] && Same(c.currentPosition(), new IVector2(x, y)))
                            incoming[enemyOwner][i] += damage / count;
                    }
                }
        }
        for (int p = 0; p < 2; p++)
        {
            for (int i = 0; i < players[p].count(); i++)
            {
                Character c = players[p].getCharacter(i);
                if (!c.isAlive()) continue;
                IVector2 pos = c.currentPosition();
                if (Inside(pos))
                {
                    if (map.map[pos.x, pos.y] == MapElement.D) incoming[p][i] += TerrainDamage;
                    if (map.map[pos.x, pos.y] == MapElement.K) kill[p][i] = true;
                }
                if (kill[p][i]) { c.setHP(0); continue; }

                int blocked = 0;
                if (Inside(pos))
                    foreach (var cast in casts)
                        if (cast.owner == p && cast.grid[pos.x, pos.y] < 0)
                            blocked -= cast.grid[pos.x, pos.y];
                c.dealDamage(Math.Max(0, incoming[p][i] - blocked));
            }
        }
        RebuildOccupancy();
        clock++;
        exchangeTick++;
        UpdateCurrent();
    }

    private static void FinalizeTick()
    {
        if (getOutcome() != 0) { exchangeActive = false; return; }
        if (!ExchangeComplete()) return;
        exchangeActive = false;
        exchangeTick = 0;
        exchangeIndex++;
        players[0].restoreSelection(-1); players[1].restoreSelection(-1);
        defyUsed = false;
        if (exchangeIndex >= players[0].count())
        {
            exchangeIndex = 0; cycleIndex++;
            Array.Fill(planningLocked, false); futureSightPending = false;
            ChooseTacticianReveal();
        }
    }

    private static bool ExchangeComplete()
    {
        if (getOutcome() != 0) return true;
        for (int p = 0; p < 2; p++)
        {
            Character c = players[p].getSelectedCharacter();
            if (c != null && c.isAlive() && exchangeTick < c.stepCount() && c.getStep(exchangeTick) != 0)
                return false;
        }
        return true;
    }

    private static Snapshot Capture()
    {
        if (!Ready()) return null;
        Snapshot s = new Snapshot
        {
            occupancyGrid = (int[,])occupancyGrid.Clone(), clock = clock,
            player1SkillGrid = players[0].getCurrentSkillGrid(),
            player2SkillGrid = players[1].getCurrentSkillGrid(),
            player1CharacterPositions = players[0].getCharacterPositions(),
            player2CharacterPositions = players[1].getCharacterPositions(),
            player1CharacterHPs = players[0].getCharacterHPs(),
            player2CharacterHPs = players[1].getCharacterHPs(),
            steps = new int[2][][], directions = new int[2][][],
            lengths = new IVector2[2][][], cooldowns = new int[2][][],
            teleportCooldowns = new int[2][], selected = new int[2],
            exchangeTick = exchangeTick, exchangeIndex = exchangeIndex,
            cycleIndex = cycleIndex, exchangeActive = exchangeActive, rngState = rngState,
            planningLocked = (bool[])planningLocked.Clone(),
            futureSightPending = futureSightPending, tacticianReveal = tacticianReveal
        };
        for (int p = 0; p < 2; p++)
        {
            int n = players[p].count();
            s.steps[p] = new int[n][]; s.directions[p] = new int[n][];
            s.lengths[p] = new IVector2[n][]; s.cooldowns[p] = new int[n][];
            s.teleportCooldowns[p] = new int[n];
            s.selected[p] = players[p].getSelectedIndex();
            for (int i = 0; i < n; i++)
            {
                Character c = players[p].getCharacter(i);
                s.steps[p][i] = c.getSteps(); s.directions[p][i] = c.getDirections();
                s.lengths[p][i] = c.getLengths(); s.cooldowns[p][i] = c.currentCooldown();
                s.teleportCooldowns[p][i] = c.currentTeleportCooldown();
            }
        }
        return s;
    }
    private static void AppendHistory(Snapshot s)
    {
        if (matchStart == null) matchStart = s;
        if (lastHistory != null) { lastHistory.next = s; s.prev = lastHistory; }
        lastHistory = s;
    }
    private static void UpdateCurrent() { if (Ready()) currState = Capture(); }
    private static bool Ready() => map != null && players[0] != null && players[1] != null;
    private static Player GetPlayer(uint p)
    {
        if (p < 1 || p > 2 || players[p - 1] == null) throw new ArgumentException("Player not configured.");
        return players[p - 1];
    }
    private static bool Same(IVector2 a, IVector2 b) => a.x == b.x && a.y == b.y;
    private static bool Inside(IVector2 p) => MapTable.IsValidIndex(p.x, p.y, map.map);
    private static IVector2 Destination(IVector2 from, int direction, int distance) => direction switch
    {
        1 => new IVector2(from.x - distance, from.y),
        2 => new IVector2(from.x + distance, from.y),
        3 => new IVector2(from.x, from.y - distance),
        4 => new IVector2(from.x, from.y + distance),
        _ => from
    };
    private static uint DirectionAxis(int direction) => direction switch
    {
        1 => (uint)Axis2.NX, 2 => (uint)Axis2.PX,
        3 => (uint)Axis2.NY, 4 => (uint)Axis2.PY, _ => (uint)Axis2.UNKNOWN
    };
    private static void RebuildOccupancy()
    {
        Array.Clear(occupancyGrid, 0, occupancyGrid.Length);
        for (int p = 0; p < 2; p++)
        {
            if (players[p] == null) continue;
            foreach (Character c in players[p].getCharacters())
            {
                IVector2 at = c.currentPosition();
                if (c.isAlive() && Inside(at)) occupancyGrid[at.x, at.y] += p == 0 ? 1 : -1;
            }
        }
    }
    private static uint NextRandom()
    {
        rngState ^= rngState << 13; rngState ^= rngState >> 17; rngState ^= rngState << 5;
        return rngState;
    }
    private static void ChooseTacticianReveal()
    {
        tacticianReveal = -1;
        if (!Ready()) return;
        for (int p = 0; p < 2; p++)
            if (players[p].getPerk() == SuperPerk.Tactician)
            {
                int opponent = 1 - p;
                tacticianReveal = (int)(NextRandom() % (uint)players[opponent].count());
                break;
            }
    }
}
