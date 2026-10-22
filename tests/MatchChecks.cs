using System;
using Godot;

public static class MatchChecks
{
    static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    static void Setup(CharacterClass a, CharacterClass b, IVector2 at, IVector2 bt, SuperPerk perk = SuperPerk.Teleport)
    {
        BattleEngine.setupEngine(0, 123);
        BattleEngine.setupPlayer(1, 1, new[] { a }, new[] { new int[a == CharacterClass.MAGE ? 10 : 15] }, new[] { at }, perk);
        BattleEngine.setupPlayer(2, 1, new[] { b }, new[] { new int[b == CharacterClass.MAGE ? 10 : 15] }, new[] { bt }, SuperPerk.Tactician);
    }

    static void Fight()
    {
        BattleEngine.finishPlanning(1); BattleEngine.finishPlanning(2);
        if (BattleEngine.getPlayer(1).getPerk() == SuperPerk.KingCrimson) BattleEngine.finishFutureSight(1);
        Require(BattleEngine.selectCharacter(1, 0) && BattleEngine.selectCharacter(2, 0), "Fighter selection failed.");
        Require(BattleEngine.startExchange(), "Exchange did not start.");
    }

    public static void Run()
    {
        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(8, 5));
        BattleEngine.setStep(1, 0, 0, -1, 2, new(1, 1));
        BattleEngine.setStep(2, 0, 0, -1, 1, new(1, 1));
        Fight();
        var before = BattleEngine.getDetails();
        BattleEngine.advanceOneTick();
        Require(BattleEngine.getPlayer(1).getCharacter(0).currentHP() == 55, "Knight slash damage.");
        Require(BattleEngine.getPlayer(2).getCharacter(0).currentHP() == 105, "Mage fireball damage.");
        Require(before.player1CharacterHPs[0] == 75, "Snapshots must be defensive copies.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(8, 5));
        BattleEngine.setStep(1, 0, 0, -2);
        BattleEngine.setStep(2, 0, 0, -1, 1);
        Fight(); BattleEngine.advanceOneTick();
        Require(BattleEngine.getPlayer(1).getCharacter(0).currentHP() == 75, "Barrier should absorb slash.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(8, 5));
        BattleEngine.setStep(1, 0, 0, -1, 2); BattleEngine.setStep(1, 0, 1, -1, 2); BattleEngine.setStep(1, 0, 2, -1, 2);
        Fight(); BattleEngine.advanceOneTick(); BattleEngine.advanceOneTick(); BattleEngine.advanceOneTick();
        Require(BattleEngine.getPlayer(2).getCharacter(0).currentHP() == 90, "Fireball cooldown must skip the second tick.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(9, 5));
        BattleEngine.setStep(1, 0, 0, 5, 4, new(10, 10));
        Fight(); BattleEngine.advanceOneTick();
        Require(BattleEngine.getOutcome() == 2, "Out-of-bounds teleport should lose the duel.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(9, 5));
        BattleEngine.setStep(1, 0, 0, 2); BattleEngine.setStep(2, 0, 0, 1);
        Fight(); BattleEngine.advanceOneTick();
        Require(BattleEngine.getPlayer(1).getCharacter(0).currentHP() == 70, "Collision damage for player one.");
        Require(BattleEngine.getPlayer(2).getCharacter(0).currentHP() == 115, "Collision damage for player two.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(9, 5), SuperPerk.KingCrimson);
        Require(BattleEngine.getVisibleOpponentSteps(1).Length == 0, "Enemy plan leaked before locking.");
        BattleEngine.finishPlanning(1); BattleEngine.finishPlanning(2);
        Require(BattleEngine.getVisibleOpponentSteps(1).Length == 1, "Future sight did not reveal plan.");
        BattleEngine.setStep(1, 0, 0, -1, 2, new(2, 2));
        BattleEngine.finishFutureSight(1);
        Require(BattleEngine.getVisibleOpponentSteps(1).Length == 0, "Future sight did not close.");

        Setup(CharacterClass.MAGE, CharacterClass.WARRIOR, new(7, 5), new(9, 5), SuperPerk.DefyDestiny);
        BattleEngine.setStep(1, 0, 0, 2);
        Fight(); BattleEngine.advanceOneTick();
        Require(BattleEngine.needsRewindDecision(), "Rewind decision was not offered.");
        BattleEngine.tryDefyDestiny(1, -2);
        Require(!BattleEngine.needsRewindDecision() && BattleEngine.getClock() == 1, "Rewind must resolve exactly one tick.");

        var session = new MatchSession();
        session.Start(false, 2);
        session.Deploy(CharacterClass.MAGE, 6, 5); session.Deploy(CharacterClass.WARRIOR, 6, 6); session.ConfirmDeployment();
        Require(session.Phase == MatchPhase.Handoff, "Deployment needs a private handoff.");
        session.ContinueHandoff();
        session.Deploy(CharacterClass.MAGE, 9, 5); session.Deploy(CharacterClass.WARRIOR, 9, 6); session.ConfirmDeployment(); session.ContinueHandoff();
        Require(session.Phase == MatchPhase.Planning && session.Viewer == 1, "Player one planning.");
        session.Paused = true; double seconds = session.Seconds; session.Update(5);
        Require(session.Seconds == seconds, "Pause must freeze the planning clock."); session.Paused = false;
        session.Slot = 3; session.Edit(2); session.LockPlan();
        Require(BattleEngine.getPlayer(1).getCharacter(0).getStep(3) == 0, "Commands after End must be removed.");
        session.ContinueHandoff(); session.LockPlan(); session.ContinueHandoff(); session.ConfirmFighter(); session.ContinueHandoff(); session.ConfirmFighter();
        Require(session.Phase == MatchPhase.Combat, "Local match did not start.");
        session.Update(3); session.Update(3);
        Require(session.Phase == MatchPhase.Handoff, "Second exchange selection must be private.");
        session.ContinueHandoff(); Require(session.Fighter == 1, "Fighter must act once per cycle."); session.ConfirmFighter();
        session.ContinueHandoff(); session.ConfirmFighter(); session.Update(3); session.Update(3);
        Require(BattleEngine.getCycleIndex() == 1, "Two-fighter cycle did not finish.");
        session.ContinueHandoff(); Require(session.Phase == MatchPhase.Planning, "Next cycle planning did not open.");
        GD.Print("CHECKS PASS: damage, defense, cooldowns, snapshots, teleport, collisions, future sight, rewind, privacy, clock, cycles");
    }

    public static void CheckSpriteScale(BattleBoard board)
    {
        float tile = board.Center(0, 1).X - board.Center(0, 0).X;
        foreach (Node child in board.Fighters)
        {
            if (child is not Node2D actor) continue;
            var rigs = actor.Get("rigs").AsGodotDictionary();
            var rig = rigs[actor.Get("facing")].AsGodotObject() as Node2D;
            Vector2 canvas = rig.Get("canvas_size").AsVector2();
            Require(Math.Abs(Math.Max(canvas.X, canvas.Y) * actor.Scale.X - tile) < 0.1f, "Standing sprite must fit its displayed tile.");
            Rect2 bounds = actor.Get("rest_bounds").AsGodotDictionary()[actor.Get("facing")].AsRect2();
            Require((rig.Position + bounds.GetCenter()).Length() < 0.1f, "Resting silhouette must be centered on the tile.");
        }
        GD.Print("CHECKS PASS: sprite scale and visual alignment");
    }
}
