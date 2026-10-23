using System;
using System.Collections.Generic;
using System.Linq;

public enum MatchPhase { Menu, Deploy, Handoff, Planning, Foresight, Selection, Combat, Rewind, Finished }

public sealed class Editor
{
    public int Fighter, Slot, Direction = 2, Range = 1, Action;
}

public sealed class MatchSession
{
    public MatchPhase Phase = MatchPhase.Menu;
    public int Viewer = 1, Local = 1, TeamSize = 1, PremoveLimit = 8;
    Random deploymentRandom = new();
    public bool DeploymentReady(int player) => confirmed[player - 1];
    public bool Solo = true, Paused, Lan;
    public double Seconds, TickSeconds = 1.3;
    public string Message = "", HandoffText = "";
    public readonly List<CharacterClass>[] Rosters = { new(), new() };
    public readonly List<IVector2>[] Spawns = { new(), new() };
    public readonly SuperPerk[] Perks = { SuperPerk.Teleport, SuperPerk.Tactician };
    public readonly List<Snapshot> Replay = new();
    public int ReplayExchangeStart { get; private set; }
    public readonly HashSet<int>[] Used = { new(), new() };
    public readonly Editor[] Editors = { new(), new() };
    readonly int[][] characterMoveLimits = { Array.Empty<int>(), Array.Empty<int>() };
    public MapElement[,] Map;
    public string MapName = "";
    public int MapIndex;
    public event System.Action Changed;
    public event System.Action<Snapshot, Snapshot> TickPlayed;
    System.Action afterHandoff;
    double tickClock;
    bool tickPending;
    bool tickAnimationPending;
    bool configured;
    readonly bool[] confirmed = { false, false };
    bool futureSightUsed;
    public int PerkOrder = 1;
    public int SelectedClass = 0;
    public int CursorRow = 6, CursorCol = 5;
    public int CharacterMoveLimit(int player, int fighter) =>
        player >= 1 && player <= 2 && fighter >= 0 && fighter < characterMoveLimits[player - 1].Length
            ? characterMoveLimits[player - 1][fighter]
            : PremoveLimit;
    public static int MoveLimit(CharacterClass characterClass, int maximum) =>
        characterClass == CharacterClass.MAGE ? Math.Max(1, maximum - 1) : maximum;

    public Func<string, int[], bool> Intercept;
    public bool IsWaitingForAnimations => tickPending && tickAnimationPending;
    bool Route(string name, params int[] arguments) => Intercept?.Invoke(name, arguments) ?? false;

    public Editor Mine => Editors[Viewer - 1];
    public int Fighter { get => Mine.Fighter; set => Mine.Fighter = value; }
    public int Slot { get => Mine.Slot; set => Mine.Slot = value; }
    public int Direction { get => Mine.Direction; set => Mine.Direction = value; }
    public int Range { get => Mine.Range; set => Mine.Range = value; }
    public int Action { get => Mine.Action; set => Mine.Action = value; }

    public Character Current => configured ? BattleEngine.getPlayer((uint)Viewer).getCharacter(Fighter) : null;
    public bool PerkTurn => !Lan || !confirmed[Local - 1];

    public static string ClassName(CharacterClass c) => c == CharacterClass.WARRIOR ? "Knight" : c.ToString()[0] + c.ToString().Substring(1).ToLowerInvariant();
    public static string[] SkillNames(CharacterClass c) => c == CharacterClass.MAGE
        ? new[] { "Cinderbolt", "Ember Aegis", "Starfall", "Prism Barrage" }
        : c == CharacterClass.ARCHER
            ? new[] { "Trueflight", "Twinstring", "Piercing Draw", "Godray" }
            : c == CharacterClass.ORC
                ? new[] { "Skullsplitter", "Quakebreaker", "Stonehide" }
                : new[] { "Crosscut", "Lance Thrust", "Skybreaker", "Knight's Edge", "Iron Vow" };
    public static int[] Cooldowns(CharacterClass c) => c switch
    {
        CharacterClass.MAGE => new[] { 1, 1, 4, 3 },
        CharacterClass.ARCHER => new[] { 1, 3, 3, 4 },
        CharacterClass.ORC => new[] { 1, 3, 2 },
        _ => new[] { 0, 2, 4, 2, 2 }
    };
    public static string[] SkillDetails(CharacterClass c) => c == CharacterClass.MAGE
        ? new[] { "15 damage · cardinal target · cooldown 1", "Block 20 damage · self · cooldown 1", "30 damage · 3 × 3 area · range 1–9 · cooldown 4", "15 damage · four diagonal rays · cooldown 3" }
        : c == CharacterClass.ARCHER
            ? new[] { "18 damage · one cardinal target at 2 or 3 tiles · cooldown 1", "15 damage · locks onto tiles 2–3 or 3–4 · cooldown 3", "40 damage · pierces all targets along 5 tiles · cooldown 3", "25 damage along the full cardinal line · cooldown 4" }
            : c == CharacterClass.ORC
                ? new[] { "28 damage · cardinal target", "20 damage · 3 × 3 area", "Block 25 damage · self" }
                : new[] { "20 damage · 1 tile · cooldown 0", "30 damage · cardinal target at 1–2 tiles · cooldown 2", "25 damage · 3 × 3 · range 2–3 · cooldown 4", "45 damage · 2 tiles · cooldown 2", "Block 30 damage · self · cooldown 2" };
    public static string[] PerkNames = { "King Crimson", "Defy Destiny", "Teleport", "Tactician" };
    public static string[] PerkDetails = {
        "See enemy plans for 90 seconds after both sides lock. Edit your own plan in that window.",
        "Once per exchange, attempt to replace the last action. Success chance: 70%.",
        "Program a cardinal teleport. Landing on a wall or chasm is fatal.",
        "One enemy fighter's sequence is revealed before selection."
    };
    public static string ActionName(int action, CharacterClass c) => action switch
    {
        0 => "End", 1 => "↑", 2 => "↓", 3 => "←", 4 => "→", 5 => "Blink",
        _ => SkillNames(c)[-action - 1]
    };

    public bool MyTurn => CanAct(Local);

    public bool CanAct(int player)
    {
        if (!Lan) return true;
        var details = BattleEngine.getDetails();
        return Phase switch
        {
            MatchPhase.Deploy => !confirmed[player - 1],
            MatchPhase.Planning => details != null && !details.planningLocked[player - 1],
            MatchPhase.Foresight => Perks[player - 1] == SuperPerk.KingCrimson,
            MatchPhase.Rewind => Perks[player - 1] == SuperPerk.DefyDestiny,
            MatchPhase.Selection => details == null || details.selected[player - 1] < 0,
            _ => true
        };
    }

    public void Start(bool solo, int size, int mapIndex = 0, int premoves = 8, int seed = 0)
    {
        if (seed == 0) seed = Random.Shared.Next(1, int.MaxValue);
        if (Route(nameof(Start), Local, solo ? 1 : 0, size, mapIndex, premoves, seed)) return;
        PremoveLimit = Math.Clamp(premoves, 5, 10);
        MapIndex = mapIndex;
        deploymentRandom = new Random(seed);
        Solo = solo; TeamSize = size; Viewer = Lan ? Local : 1;
        configured = false; Paused = false; tickPending = tickAnimationPending = false; Replay.Clear(); ReplayExchangeStart = 0;
        characterMoveLimits[0] = characterMoveLimits[1] = Array.Empty<int>();
        for (int p = 0; p < 2; p++) { Rosters[p].Clear(); Spawns[p].Clear(); Used[p].Clear(); Editors[p] = new Editor(); }
        confirmed[0] = confirmed[1] = false;
        futureSightUsed = false;
        Perks[0] = SuperPerk.Teleport;
        Perks[1] = SuperPerk.Tactician;
        BattleEngine.setupEngine((uint)mapIndex, (uint)seed);
        Map = BattleEngine.getCurrentMap().map;
        MapName = BattleEngine.getCurrentMap().name;
        PerkOrder = Lan ? BattleEngine.getFirstPerkPicker() : 1;
        SelectedClass = 0;
        Phase = MatchPhase.Deploy;
        Seconds = 60;
        Message = "Choose your fighters.";
        Notify();
    }

    public void Deploy(CharacterClass type, int row, int col) => DeployAs(Viewer, type, row, col);

    public void DeployAs(int viewer, CharacterClass type, int row, int col)
    {
        if (Route(nameof(Deploy), viewer, (int)type, row, col)) return;
        if (Phase != MatchPhase.Deploy || !CanAct(viewer)) return;
        if (type != CharacterClass.MAGE && type != CharacterClass.WARRIOR && type != CharacterClass.ARCHER) return;
        int p = viewer - 1;
        if (Rosters[p].Count >= TeamSize) { Message = "Your team is full. Remove a fighter to change it."; Notify(); return; }

        if (!Safe(row, col) || (viewer == 1 ? row >= 8 : row < 8)) { Message = "Deploy on a safe tile in your highlighted half."; Notify(); return; }
        if (Spawns[p].Any(t => t.x == row && t.y == col)) { Message = "Choose an unoccupied deployment tile."; Notify(); return; }
        Rosters[p].Add(type); Spawns[p].Add(new IVector2(row, col));
        Message = $"{ClassName(type)} deployed. {Rosters[p].Count}/{TeamSize} fighters ready.";
        Notify();
    }

    public bool CanAdd => Phase == MatchPhase.Deploy && MyTurn && Rosters[Viewer - 1].Count < TeamSize;

    public void SelectClass(CharacterClass type)
    {
        SelectedClass = (int)type;
        CursorRow = Viewer == 1 ? 6 : 9; CursorCol = 5;
        Notify();
    }

    public bool CanPlace(int row, int col) => Safe(row, col) && (Viewer == 1 ? row < 8 : row >= 8)
        && !Spawns[Viewer - 1].Exists(t => t.x == row && t.y == col);

    public void PlaceAt(int row, int col)
    {
        if (Phase != MatchPhase.Deploy) return;
        if (!CanPlace(row, col)) { Message = "Place a fighter on a free tile in your own half."; Notify(); return; }
        Deploy((CharacterClass)SelectedClass, row, col);
    }

    public void RemoveFighter(int index) => RemoveFighterAs(Viewer, index);

    public void RemoveFighterAs(int viewer, int index)
    {
        if (Route(nameof(RemoveFighter), viewer, index)) return;
        if (Phase != MatchPhase.Deploy || !CanAct(viewer) || index < 0 || index >= Rosters[viewer - 1].Count) return;
        Rosters[viewer - 1].RemoveAt(index);
        Spawns[viewer - 1].RemoveAt(index);
        Notify();
    }

    public static int[] SkillRanges(CharacterClass c, int skill) => (c, skill) switch
    {
        (CharacterClass.MAGE, 0) => new[] { 1, 2, 3, 4, 5, 6 },
        (CharacterClass.MAGE, 2) => new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        (CharacterClass.WARRIOR, 0) => new[] { 1 },
        (CharacterClass.WARRIOR, 1) => new[] { 1, 2 },
        (CharacterClass.WARRIOR, 2) => new[] { 2, 3 },
        (CharacterClass.WARRIOR, 3) => new[] { 2 },
        (CharacterClass.ARCHER, 0) => new[] { 2, 3 },
        (CharacterClass.ARCHER, 1) => new[] { 2, 3 },
        (CharacterClass.ARCHER, 2) => new[] { 5 },
        (CharacterClass.ARCHER, 3) => new[] { 1 },
        (CharacterClass.ORC, 0) => new[] { 1, 2, 3, 4, 5, 6 },
        (CharacterClass.ORC, 1) => new[] { 1, 2, 3, 4, 5, 6 },
        (CharacterClass.ORC, 2) => new[] { 1 },
        _ => Array.Empty<int>()
    };

    public void UndoDeployment() => UndoDeploymentAs(Viewer);

    public void UndoDeploymentAs(int viewer)
    {
        if (Route(nameof(UndoDeployment), viewer)) return;
        int p = viewer - 1;
        if (Phase == MatchPhase.Deploy && CanAct(viewer) && Rosters[p].Count > 0)
        { Rosters[p].RemoveAt(Rosters[p].Count - 1); Spawns[p].RemoveAt(Spawns[p].Count - 1); Notify(); }
    }

    public void SetPerk(int perk) => SetPerkAs(Viewer, perk);

    public void SetPerkAs(int viewer, int perk)
    {
        if (Route(nameof(SetPerk), viewer, perk)) return;
        if (Phase != MatchPhase.Deploy || perk < 0 || perk > 3) return;
        if (!CanAct(viewer) || (Lan && perk == (int)SuperPerk.KingCrimson)) return;
        if (Perks[2 - viewer] == (SuperPerk)perk) return;
        Perks[viewer - 1] = (SuperPerk)perk; Notify();
    }

    public void ConfirmDeployment() => ConfirmDeploymentAs(Viewer);

    public void ConfirmDeploymentAs(int viewer)
    {
        if (Route(nameof(ConfirmDeployment), viewer)) return;
        if (Phase != MatchPhase.Deploy || !CanAct(viewer)) return;
        int p = viewer - 1;
        if (Rosters[p].Count != TeamSize) return;
        if (Lan && (int)Perks[p] < 0) { Message = "Choose a team perk first."; Notify(); return; }
        if (Lan)
        {
            confirmed[p] = true;
            if (confirmed[0] && confirmed[1]) Configure();
            Notify(); return;
        }
        if (viewer == 1)
        {
            if (Perks[1] == Perks[0]) Perks[1] = (SuperPerk)(((int)Perks[0] + 1) % 4);
            if (Solo)
            {
                for (int i = 0; i < TeamSize; i++)
                {
                    Rosters[1].Add(i == 0 ? CharacterClass.WARRIOR : CharacterClass.MAGE);
                    Spawns[1].Add(new IVector2(11, 5 + i * 2));
                }
                Configure();
            }
            else Handoff(2, "Choose your team and deployment", () => { Phase = MatchPhase.Deploy; Message = "Deploy in the southern half."; });
        }
        else Configure();
        Notify();
    }

    void CompleteDeployment()
    {
        for (int p = 0; p < 2; p++)
        {
            var tiles = new List<IVector2>();
            for (int row = 0; row < Map.GetLength(0); row++)
                for (int col = 0; col < Map.GetLength(1); col++)
                    if (Safe(row, col) && (p == 0 ? row < 8 : row >= 8) && !Spawns[p].Any(t => t.x == row && t.y == col))
                        tiles.Add(new IVector2(row, col));
            while (Rosters[p].Count < TeamSize && tiles.Count > 0)
            {
                int index = deploymentRandom.Next(tiles.Count);
                Rosters[p].Add(deploymentRandom.Next(2) == 0 ? CharacterClass.WARRIOR : CharacterClass.MAGE);
                Spawns[p].Add(tiles[index]); tiles.RemoveAt(index);
            }
            confirmed[p] = true;
        }
        Configure(); Notify();
    }

    void Configure()
    {
        for (int p = 0; p < 2; p++)
        {
            var limits = Rosters[p].Select(c => MoveLimit(c, PremoveLimit)).ToArray();
            characterMoveLimits[p] = limits;
            int[][] plans = Rosters[p].Select((c, i) => new int[limits[i]]).ToArray();
            BattleEngine.setupPlayer((uint)p + 1, (uint)TeamSize, Rosters[p].ToArray(), plans, Spawns[p].ToArray(), Perks[p]);
        }
        configured = true;
        BeginPlanning();
    }

    void BeginPlanning()
    {
        Used[0].Clear(); Used[1].Clear();
        for (int p = 0; p < 2; p++)
        {
            var team = BattleEngine.getPlayer((uint)p + 1);
            for (int fighter = 0; fighter < team.count(); fighter++)
            {
                Character character = team.getCharacter(fighter);
                for (int slot = 0; slot < character.stepCount(); slot++)
                    BattleEngine.setStep((uint)p + 1, fighter, slot, 0);
            }
            Editors[p] = new Editor { Fighter = FirstAlive(p + 1) };
        }
        futureSightUsed = false;
        if (Solo) { Viewer = 1; Planning(); }
        else if (Lan) { Viewer = Local; Planning(); }
        else Handoff(1, "Your private planning window", Planning);
    }

    void Planning()
    {
        Phase = MatchPhase.Planning; Fighter = FirstAlive(Viewer); Slot = 0; Action = 0;
        Seconds = 0;
        Message = "Program each fighter. Both sides act at the same time. Zero ends a sequence.";
    }

    public void ContinueHandoff() => ContinueHandoffAs(Viewer);

    public void ContinueHandoffAs(int viewer)
    {
        if (Route(nameof(ContinueHandoff), viewer)) return;
        if (Phase != MatchPhase.Handoff) return;
        var next = afterHandoff; afterHandoff = null; next?.Invoke(); Notify();
    }

    void Handoff(int viewer, string text, System.Action next)
    {
        Viewer = viewer; HandoffText = text; Phase = MatchPhase.Handoff; afterHandoff = next;
    }

    public void Edit(int action) => EditAs(Viewer, action);

    public void EditAs(int viewer, int action)
    {
        if (Route(nameof(Edit), viewer, action)) return;
        if ((Phase != MatchPhase.Planning && Phase != MatchPhase.Foresight) || !CanAct(viewer)) return;
        var editor = Editors[viewer - 1];
        Character fighter = BattleEngine.getPlayer((uint)viewer).getCharacter(editor.Fighter);
        BattleEngine.setStep((uint)viewer, editor.Fighter, editor.Slot, action, editor.Direction, new IVector2(editor.Range, editor.Range));
        for (int slot = editor.Slot + 1; slot < fighter.stepCount(); slot++)
            BattleEngine.setStep((uint)viewer, editor.Fighter, slot, 0);
        if (editor.Slot < fighter.stepCount() - 1) editor.Slot++;
        editor.Action = 0;
        Message = ""; Notify();
    }

    public void StepRange(int delta)
    {
        if (Action < 0)
        {
            var ranges = SkillRanges(Current.characterClass(), -Action - 1);
            if (ranges.Length == 0) return;
            int index = Array.IndexOf(ranges, Range);
            if (index < 0) index = 0;
            Range = ranges[Math.Clamp(index + delta, 0, ranges.Length - 1)];
        }
        else Range = Math.Clamp(Range + delta, 1, 15);
        Notify();
    }

    public void SelectSkill(int skill)
    {
        Action = -skill;
        var ranges = SkillRanges(Current.characterClass(), skill - 1);
        if (ranges.Length > 0 && Array.IndexOf(ranges, Range) < 0) Range = ranges[0];
        Notify();
    }

    public void ClearPlan() => ClearPlanAs(Viewer);

    public void ClearPlanAs(int viewer)
    {
        if (Route(nameof(ClearPlan), viewer)) return;
        if ((Phase != MatchPhase.Planning && Phase != MatchPhase.Foresight) || !CanAct(viewer)) return;
        var editor = Editors[viewer - 1];
        Character fighter = BattleEngine.getPlayer((uint)viewer).getCharacter(editor.Fighter);
        for (int i = 0; i < fighter.stepCount(); i++) BattleEngine.setStep((uint)viewer, editor.Fighter, i, 0);
        editor.Slot = 0; Notify();
    }

    public void LockPlan() => LockPlanAs(Viewer);

    public void LockPlanAs(int viewer)
    {
        if (Route(nameof(LockPlan), viewer)) return;
        if (Phase == MatchPhase.Foresight) { FinishFutureSightAs(viewer); return; }
        if (Phase != MatchPhase.Planning || !CanAct(viewer)) return;
        NormalizePlan(viewer);
        BattleEngine.finishPlanning((uint)viewer);
        if (Lan) { AfterBothLocked(); Notify(); return; }
        if (viewer == 1 && !Solo) Handoff(2, "Your private planning window", Planning);
        else
        {
            if (Solo) { PlanComputer(); BattleEngine.finishPlanning(2); }
            int crimson = Array.IndexOf(Perks, SuperPerk.KingCrimson) + 1;
            if (crimson > 0)
            {
                futureSightUsed = true;
                if (Solo && crimson == 2) BattleEngine.finishFutureSight(2);
                else
                {
                    Handoff(crimson, "King Crimson · inspect enemy plans", () => {
                        Phase = MatchPhase.Foresight; Fighter = FirstAlive(Viewer); Slot = 0;
                        Seconds = BattleEngine.getFutureSightSeconds(); Message = "Enemy plans are revealed. Adjust your sequence, then continue.";
                    });
                    Notify(); return;
                }
            }
            BeginSelection();
        }
        Notify();
    }

    public void FinishFutureSight() => FinishFutureSightAs(Viewer);

    public void FinishFutureSightAs(int viewer)
    {
        if (Route(nameof(FinishFutureSight), viewer)) return;
        if (!futureSightUsed) return;
        BattleEngine.finishFutureSight((uint)viewer);
        BeginSelection();
        Notify();
    }

    void AfterBothLocked()
    {
        var details = BattleEngine.getDetails();
        if (details == null || !details.planningLocked[0] || !details.planningLocked[1]) return;
        int crimson = Array.IndexOf(Perks, SuperPerk.KingCrimson) + 1;
        if (crimson > 0 && !futureSightUsed)
        {
            futureSightUsed = true;
            Viewer = crimson;
            Phase = MatchPhase.Foresight; Fighter = FirstAlive(crimson); Slot = 0;
            Seconds = BattleEngine.getFutureSightSeconds();
            Message = "Enemy plans are revealed. Adjust your sequence, then continue.";
            return;
        }
        BeginSelection();
    }

    void NormalizePlan(int viewer)
    {
        var team = BattleEngine.getPlayer((uint)viewer);
        for (int i = 0; i < team.count(); i++)
        {
            Character fighter = team.getCharacter(i);
            bool ended = false;
            for (int slot = 0; slot < fighter.stepCount(); slot++)
            {
                if (ended) BattleEngine.setStep((uint)viewer, i, slot, 0);
                if (fighter.getStep(slot) == 0) ended = true;
            }
        }
    }

    void BeginSelection()
    {
        if (Lan)
        {
            Viewer = Local;
            Selection();
        }
        else if (TeamSize == 1)
        {
            SelectAutomatically(1);
            SelectAutomatically(2);
            StartExchange();
        }
        else if (Solo) { Viewer = 1; Selection(); }
        else Handoff(1, "Choose your next fighter privately", Selection);
    }

    void Selection()
    {
        Phase = MatchPhase.Selection;
        Fighter = Available(Viewer).First();
        Message = "Choose a living fighter who has not acted this cycle.";
    }

    void SelectAutomatically(int player)
    {
        int fighter = Available(player).First();
        Editors[player - 1].Fighter = fighter;
        BattleEngine.selectCharacter((uint)player, fighter);
        Used[player - 1].Add(fighter);
    }

    void StartExchange()
    {
        if (!BattleEngine.startExchange()) return;
        ReplayExchangeStart = Math.Max(0, Replay.Count - 1);
        Phase = MatchPhase.Combat;
        tickClock = 0.25;
        tickPending = false;
        Message = "Both parties are executing their plans.";
    }

    public IEnumerable<int> Available(int player)
    {
        var alive = Enumerable.Range(0, TeamSize).Where(i => BattleEngine.getPlayer((uint)player).getCharacter(i).isAlive());
        var fresh = alive.Where(i => !Used[player - 1].Contains(i)).ToArray();
        return fresh.Length > 0 ? fresh : alive;
    }

    public void ConfirmFighter() => ConfirmFighterAs(Viewer);

    public void ConfirmFighterAs(int viewer)
    {
        if (Route(nameof(ConfirmFighter), viewer)) return;
        if (Phase != MatchPhase.Selection) return;
        var editor = Editors[viewer - 1];
        if (!Available(viewer).Contains(editor.Fighter)) return;
        BattleEngine.selectCharacter((uint)viewer, editor.Fighter);
        Used[viewer - 1].Add(editor.Fighter);
        if (Lan)
        {
            var details = BattleEngine.getDetails();
            if (details != null && details.selected[0] >= 0 && details.selected[1] >= 0 && BattleEngine.startExchange())
            { ReplayExchangeStart = Math.Max(0, Replay.Count - 1); Phase = MatchPhase.Combat; tickClock = 0.25; tickPending = false; Message = "Both parties are executing their plans."; }
            Notify(); return;
        }
        if (viewer == 1)
        {
            if (!Solo) { Handoff(2, "Choose your next fighter privately", Selection); Notify(); return; }
            int enemy = Available(2).First();
            BattleEngine.selectCharacter(2, enemy); Used[1].Add(enemy);
        }
        if (BattleEngine.startExchange())
        { ReplayExchangeStart = Math.Max(0, Replay.Count - 1); Phase = MatchPhase.Combat; tickClock = 0.25; tickPending = false; Message = "Both parties are executing their plans."; }
        Notify();
    }

    public void Update(double delta, bool? remoteAnimationHold = null)
    {
        if (Paused) return;
        if (Lan && Phase == MatchPhase.Deploy)
        {
            Seconds = Math.Max(0, Seconds - delta);
            if (Seconds == 0) CompleteDeployment();
            return;
        }
        if (Phase == MatchPhase.Foresight)
        {
            Seconds = Math.Max(0, Seconds - delta);
            if (Seconds == 0) FinishFutureSight();
        }
        if (Phase != MatchPhase.Combat) return;
        tickClock -= delta;
        if (tickClock > 0) return;
        if (remoteAnimationHold ?? (tickPending && tickAnimationPending)) return;
        if (tickPending)
        {
            tickPending = false;
            tickAnimationPending = false;
            if (BattleEngine.needsRewindDecision())
            {
                int owner = Array.IndexOf(Perks, SuperPerk.DefyDestiny) + 1;
                if (Solo && owner == 2) BattleEngine.passRewindDecision(2);
                else if (Lan)
                {
                    Phase = MatchPhase.Rewind;
                    Viewer = owner;
                    Editors[owner - 1].Fighter = BattleEngine.getPlayer((uint)owner).getSelectedIndex();
                    PrepareRewindEditor(owner);
                    Message = "Review the exchange, replace its final action, or keep the outcome.";
                }
                else
                {
                    Viewer = owner; Phase = MatchPhase.Rewind;
                    Fighter = BattleEngine.getPlayer((uint)Viewer).getSelectedIndex();
                    PrepareRewindEditor(owner);
                    Message = "Review the exchange, replace its final action, or keep the outcome.";
                }
            }
            if (Phase == MatchPhase.Combat) AfterTick();
            if (Phase != MatchPhase.Combat) { Notify(); return; }
        }
        var before = BattleEngine.getDetails();
        if (Replay.Count == 0) Replay.Add(before);
        BattleEngine.advanceOneTick();
        var after = BattleEngine.getDetails(); Replay.Add(after);
        tickAnimationPending = TickPlayed != null;
        TickPlayed?.Invoke(before, after);
        tickClock = TickSeconds;
        tickPending = true;
        Notify();
    }

    public void CompleteTickAnimations()
    {
        tickAnimationPending = false;
    }

    public void Rewind(bool attempt) => RewindAs(Viewer, attempt);

    public void RewindAs(int viewer, bool attempt)
    {
        if (Route(nameof(Rewind), viewer, attempt ? 1 : 0)) return;
        if (Lan)
        {
            int owner = Array.IndexOf(Perks, SuperPerk.DefyDestiny) + 1;
            if (owner != viewer) return;
        }
        else if (Phase != MatchPhase.Rewind) return;
        var editor = Editors[viewer - 1];
        Snapshot before = BattleEngine.getDetails();
        if (attempt)
        {
            bool success = BattleEngine.tryDefyDestiny((uint)viewer, editor.Action, editor.Direction, new IVector2(editor.Range, editor.Range));
            Message = success ? "Destiny defied." : "The rewind failed.";
            if (success)
            {
                int slot = before.exchangeTick - 1;
                before.exchangeTick = slot;
                before.steps[viewer - 1][editor.Fighter][slot] = editor.Action;
                before.directions[viewer - 1][editor.Fighter][slot] = editor.Direction;
                before.lengths[viewer - 1][editor.Fighter][slot] = new IVector2(editor.Range, editor.Range);
            }
            var after = BattleEngine.getDetails(); Replay.Add(after); TickPlayed?.Invoke(before, after);
        }
        else BattleEngine.passRewindDecision((uint)viewer);
        if (Lan) Phase = MatchPhase.Combat;
        else { Viewer = viewer; Phase = MatchPhase.Combat; }
        tickClock = TickSeconds; tickPending = true; Notify();
    }

    void PrepareRewindEditor(int viewer)
    {
        var editor = Editors[viewer - 1];
        int fighter = BattleEngine.getPlayer((uint)viewer).getSelectedIndex();
        Snapshot state = BattleEngine.getDetails();
        int slot = Math.Max(0, state.exchangeTick - 1);
        editor.Fighter = fighter;
        editor.Slot = slot;
        editor.Action = state.steps[viewer - 1][fighter][slot];
        editor.Direction = state.directions[viewer - 1][fighter][slot];
        editor.Range = state.lengths[viewer - 1][fighter][slot].x;
        if (editor.Action == 0) editor.Action = 1;
    }

    void AfterTick()
    {
        if (BattleEngine.getOutcome() != 0)
        {
            Phase = MatchPhase.Finished;
            int outcome = BattleEngine.getOutcome();
            Message = outcome == 3 ? "Mutual defeat" : Solo ? outcome == 1 ? "Victory" : "Defeat" : $"Player {outcome} wins";
        }
        else if (!BattleEngine.isExchangeActive())
        {
            futureSightUsed = false;
            if (!BattleEngine.getDetails().planningLocked[0]) BeginPlanning();
            else BeginSelection();
        }
    }

    public bool Safe(int row, int col) => row >= 0 && col >= 0 && row < Map.GetLength(0) && col < Map.GetLength(1) && Map[row, col] != MapElement.W && Map[row, col] != MapElement.K;
    int FirstAlive(int player) => Enumerable.Range(0, TeamSize).First(i => BattleEngine.getPlayer((uint)player).getCharacter(i).isAlive());
    public void Notify() => Changed?.Invoke();

    void PlanComputer()
    {
        var team = BattleEngine.getPlayer(2);
        for (int i = 0; i < team.count(); i++)
        {
            Character c = team.getCharacter(i);
            if (!c.isAlive()) continue;
            IVector2 at = c.currentPosition();
            int[] cooldown = c.currentCooldown();
            for (int slot = 0; slot < c.stepCount(); slot++)
            {
                for (int k = 0; k < cooldown.Length; k++) cooldown[k]--;
                Character enemy = BattleEngine.getPlayer(1).getCharacters().Where(e => e.isAlive()).OrderBy(e => Distance(at, e.currentPosition())).First();
                IVector2 target = enemy.currentPosition();
                int direction = Math.Abs(target.x - at.x) >= Math.Abs(target.y - at.y) ? target.x < at.x ? 1 : 2 : target.y < at.y ? 3 : 4;
                int range = Math.Max(1, Distance(at, target));
                int bestSkill = -1, bestDirection = direction, bestRange = range, bestDamage = 0;
                for (int k = 0; k < cooldown.Length; k++)
                {
                    if (cooldown[k] <= 0)
                    {
                        foreach (int skillRange in SkillRanges(c.characterClass(), k))
                        {
                            for (int d = 1; d <= 4; d++)
                            {
                                int[,] grid = new int[Map.GetLength(0), Map.GetLength(1)];
                                SkillTable.skills[(int)c.characterClass()][k](at, new IVector2(skillRange, skillRange), Axis(d), ref grid);
                                int damage = grid[target.x, target.y];
                                if (damage > bestDamage) { bestDamage = damage; bestSkill = k; bestDirection = d; bestRange = skillRange; }
                            }
                        }
                    }
                }
                int action;
                if (bestSkill >= 0)
                { action = -bestSkill - 1; direction = bestDirection; range = bestRange; cooldown[bestSkill] = Cooldowns(c.characterClass())[bestSkill] + 1; }
                else
                {
                    action = NextMove(at, target);
                    if (action > 0) at = Move(at, action);
                    else action = c.characterClass() switch
                    {
                        CharacterClass.MAGE => -2,
                        CharacterClass.ARCHER => -1,
                        _ => -5
                    };
                }
                BattleEngine.setStep(2, i, slot, action, direction, new IVector2(range, range));
            }
        }
    }

    int NextMove(IVector2 start, IVector2 target)
    {
        var queue = new Queue<(IVector2 point, int first)>();
        var visited = new HashSet<(int, int)> { (start.x, start.y) };
        queue.Enqueue((start, 0));
        int best = 0, distance = Distance(start, target);
        while (queue.Count > 0)
        {
            var item = queue.Dequeue();
            int score = Distance(item.point, target);
            if (score < distance) { distance = score; best = item.first; }
            if (distance == 1) return best;
            for (int d = 1; d <= 4; d++)
            {
                var next = Move(item.point, d);
                if (!Safe(next.x, next.y) || Distance(next, target) == 0 || !visited.Add((next.x, next.y))) continue;
                queue.Enqueue((next, item.first == 0 ? d : item.first));
            }
        }
        return best;
    }
    public static int Distance(IVector2 a, IVector2 b) => Math.Abs(a.x - b.x) + Math.Abs(a.y - b.y);
    public static IVector2 Move(IVector2 p, int d, int range = 1) => d switch {
        1 => new(p.x - range, p.y), 2 => new(p.x + range, p.y), 3 => new(p.x, p.y - range), 4 => new(p.x, p.y + range), _ => p
    };
    public static uint Axis(int d) => d switch { 1 => (uint)Axis2.NX, 2 => (uint)Axis2.PX, 3 => (uint)Axis2.NY, 4 => (uint)Axis2.PY, _ => 0 };
}
