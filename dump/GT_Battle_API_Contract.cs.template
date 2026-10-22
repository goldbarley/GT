// GT integration contract v1.0 — DECLARATIONS, NOT AN IMPLEMENTATION.
// Requires .NET 8/C# 12; use the existing CharacterClass enum rather than duplicating it.
using System;
using System.Collections.Generic;

public enum MatchPhase { Placement, PerkDraft, Planning, FutureSight, Selection, Playback, RewindDecision, Finished }
public enum Perk { FutureSight, DefyDestiny, Teleport, Tactician }
public enum StepKind { Wait, Move, Skill, Teleport }
public enum Cardinal { Up, Down, Left, Right }
public enum TileType { Ground = 0, Wall = 1, Pit = 2, Obstacle = 3, Stairs = 4, Damage = 5 }
public enum MatchOutcome { Undecided, Player0Win, Player1Win, Draw }
public enum EventKind { Moved, Teleported, Collision, Blocked, SkillUsed, SkillOnCooldown, Defense, Damage, Hazard, Died, Rewound, RewindFailed, ExchangeEnded, MatchEnded }

public readonly record struct Cell(int X, int Y);
// For Move/Teleport supply direction; Teleport also requires Distance > 0.
// For Skill supply SkillId, optional Direction/Length.
public sealed record PlannedAction(StepKind Kind, Cardinal Direction = Cardinal.Up,
    string? SkillId = null, int Distance = 0, int Length = 0);
public sealed record SkillDefinition(string Id, string Name, int CooldownInTicks, string Description);
public sealed record CharacterView(int Id, int Owner, CharacterClass Class, Cell Position,
    int Hp, int MaxHp, bool Alive, int PlannedSlots,
    IReadOnlyDictionary<string,int> Cooldowns);
public sealed record BattleEvent(EventKind Kind, int Tick, int? ActorId, int? TargetId,
    Cell? From, Cell? To, int Amount, string? Detail);
// An actual-state view is filtered for the phase and viewer.
// In private planning, enemy characters MUST NOT appear in Characters.
public sealed record MatchView(MatchPhase Phase, int CycleIndex, int ExchangeIndex,
    int GlobalTick, int ExchangeTick, IReadOnlyList<CharacterView> Characters,
    int? SelectedPlayer0Character, int? SelectedPlayer1Character, MatchOutcome Outcome);
// A draft preview is only an advisory projection based on visible terrain/allies;
// it neither commits a step nor mutates actual combat state.
public sealed record DraftPreview(Cell ConfirmedPosition, Cell PendingPosition,
    IReadOnlyList<Cell> AffectedTiles, bool TerrainLegal, string? Warning);
public sealed record TickOutcome(int Tick, IReadOnlyList<BattleEvent> Events,
    MatchView View, bool ExchangeOver, bool NeedsRewindDecision);
public sealed record Reveal(int OpponentCharacterId, IReadOnlyList<PlannedAction> Plan);
public sealed record CharacterStats(int CharacterId, int StepsExecuted, int TilesTravelled,
    int DamageDealt, int DamageTaken, int DamageBlocked, int SkillUses,
    int CooldownSkips, int Collisions, int Kills, int Deaths);
public sealed record PlayerStats(int PlayerId, int PerkActivations, int PerkSuccesses,
    int PerkFailures, IReadOnlyList<CharacterStats> Characters);
public sealed record MatchReport(MatchOutcome Outcome, int TotalTicks,
    int CompletedExchanges, IReadOnlyList<PlayerStats> Players);

// The sole authoritative entrypoint for gameplay and UI integration.
// Every Try* method is atomic: false means nothing changed; error gives the reason.
public interface IBattleEngine
{
    MatchView ViewFor(int playerId);
    TileType[,] TerrainCopy(); // [y,x], values compatible with Sky Island JSON
    int FirstPerkPicker { get; }
    int PlanningSecondsFor(int playerId); // 60 normally; Tactician 120
    int FutureSightSeconds { get; } // 20
    IReadOnlyList<SkillDefinition> SkillsFor(int characterId);
    IReadOnlyList<PlannedAction>? VisiblePlan(int viewerId, int characterId);
    IReadOnlyList<int> SelectableCharacters(int playerId);
    Reveal? TacticianRevealFor(int playerId);
    MatchReport? FinalReport();

    // One-time, private initial placement and mutually exclusive perk draft.
    bool TryPlaceCharacter(int playerId, int characterId, Cell at, out string error);
    bool TryLockPlacement(int playerId, out string error);
    bool TryChoosePerk(int playerId, Perk chosen, out string error);

    // Input handling: key previews without modifying a committed plan.
    DraftPreview PreviewPending(int viewerId, int characterId, PlannedAction pending);
    bool TryConfirmAt(int viewerId, int characterId, int slot,
        PlannedAction pending, out string error); // Enter
    bool TryClearSlot(int viewerId, int characterId, int slot, out string error);
    bool TryFinishPlanning(int playerId, out string error); // also timer expiry
    bool TryFinishFutureSight(int ownerId, out string error);

    bool TrySelectForExchange(int playerId, int characterId, out string error);
    bool TryStartExchange(out string error);
    TickOutcome AdvanceOneTick(); // exactly one simultaneous GLOBAL tick

    // Requires the previous tick still eligible for rewind. Only changes ONE
    // owner's selected character's action in that immediately preceding tick.
    // On 30% failure, preserves original tick, consumes the attempt.
    bool TryDefyDestiny(int ownerId, PlannedAction replacement,
        out TickOutcome result, out string error);
    bool TryPassRewindDecision(int playerId, out string error);
}
