using Godot;
using System;
using System.Linq;

public partial class Premove : Control
{
    readonly MatchSession match = new();
    readonly Color ink = new("3a2a1b"), muted = new("6f573c"), gold = new("8a5a2b"), cyan = new("2f4f7a"), coral = new("a33b32");
    Control shell;
    Control keyOverlay;
    PanelContainer keyPanel;
    MarginContainer battleCenterMargin;
    Control phaseAnnouncement;
    ColorRect phaseCurtain;
    Label phaseTitle;
    PanelContainer syncPanel;
    Label syncLabel;
    ulong syncUntil;
    Tween phaseTween;
    MatchPhase previousPhase = MatchPhase.Menu;
    readonly int[] executing = { 0, 0 };
    string screen = "title";
    int characterIndex, tutorialPage;
    readonly string[] characterNames = { "Knight", "Mage", "Archer", "Orc" };
    Node2D showcase;
    Label lastMove;
    string moveText = "";
    NetworkMatch network;
    MusicPlayer music;
    SoundEffects sfx;
    bool Choosing => match.Phase == MatchPhase.Menu;
    BattleBoard board;
    VBoxContainer left, right, footer, header;
    VBoxContainer headerInfo;
    Control overlay, popup, showcaseStage;
    bool placementOpen;
    bool rewindPopup;
    readonly System.Collections.Generic.Dictionary<int, Node2D> showcaseCache = new();
    Node2D showcaseHolder;
    Label clock, tileInfo, selectionClock;
    bool solo = true, modalOpen;
    int teamSize = 1, mapIndex, premoveLimit = 8;
    string transient = "";

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        Theme = MakeTheme();
        BuildShell();
        showcaseHolder = new Node2D { Name = "ShowcaseHolder" }; AddChild(showcaseHolder);
        var menuLayer = new CanvasLayer { Name = "MenuLayer", Layer = 10 }; AddChild(menuLayer);
        popup = new Control { Name = "Popup", MouseFilter = MouseFilterEnum.Ignore }; menuLayer.AddChild(popup); popup.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        foreach (int kind in new[] { 0, 1, 2 }) { var figure = BuildFigure(kind); figure.Visible = false; showcaseHolder.AddChild(figure); showcaseCache[kind] = figure; }
        network = new NetworkMatch { Name = "Network", Session = match }; AddChild(network);
        music = new MusicPlayer { Name = "Music" }; AddChild(music);
        sfx = new SoundEffects { Name = "Sfx" }; AddChild(sfx);
        board.Sound = sfx;
        network.StatusChanged += status => { transient = status; if (match.Phase == MatchPhase.Menu) Refresh(); };
        network.DiscoveryChanged += () => { if (screen == "lan") Refresh(); };
        network.RemoteActivity += () => syncUntil = Time.GetTicksMsec() + 700;
        network.ConnectionLost += () => { ReturnToMenu(); transient = "Connection closed. Host or join again."; screen = "lan"; network.BeginDiscovery(); Refresh(); };
        network.GuestDisconnected += () =>
        {
            match.Lan = false; match.Local = match.Viewer = 1; modalOpen = false; screen = "lan"; match.Paused = false;
            match.Phase = MatchPhase.Menu; board.Reset(); transient = "Player 2 disconnected. Hosting remains open.";
            network.BeginDiscovery(); Refresh();
        };
        match.Changed += () =>
        {
            if (rewindPopup && match.Phase != MatchPhase.Rewind)
            {
                rewindPopup = false;
                modalOpen = false;
            }
            Refresh();
        };
        match.TickPlayed += (before, after) => { board.PlayTick(before, after); ShowLastMoves(before); };
        board.TickAnimationsFinished += match.CompleteTickAnimations;
        board.ImpactShown += Refresh;
        Refresh();
        if (OS.GetCmdlineUserArgs().Contains("--smoke-test")) CallDeferred(MethodName.RunSmokeTest);
        if (OS.GetCmdlineUserArgs().Contains("--capture-menu")) RunVisualCheck();
        bool lanTest = OS.GetCmdlineUserArgs().Any(a => a.StartsWith("--lan-test-host") || a.StartsWith("--lan-test-join"));
        if (lanTest)
        {
            var bot = new LanBot { Session = match, Network = network, Name = "LanBot" };
            AddChild(bot);
            bot.Run(OS.GetCmdlineUserArgs().Any(a => a.StartsWith("--lan-test-host")) ? "host" : "join");
        }
    }

    Theme MakeTheme()
    {
        var font = GD.Load<FontFile>("res://assets/fonts/Terminus.ttf");
        font.Antialiasing = TextServer.FontAntialiasing.None;
        font.FixedSize = 16;
        font.FixedSizeScaleMode = TextServer.FixedSizeScaleMode.Enabled;
        var theme = new Theme { DefaultFontSize = 16, DefaultFont = font };
        theme.SetColor("font_color", "Label", ink);
        theme.SetColor("font_color", "Button", ink);
        theme.SetColor("font_hover_color", "Button", new Color("182c3d"));
        theme.SetColor("font_disabled_color", "Button", new Color("8a7a63"));
        theme.SetColor("font_color", "TooltipLabel", ink);
        theme.SetFont("font", "TooltipLabel", font);
        theme.SetFontSize("font_size", "TooltipLabel", 16);
        theme.SetStylebox("panel", "TooltipPanel", Box("f1e3c5", "61432c"));
        theme.SetStylebox("normal", "Button", Box("efdfc1", "61432c", 0));
        theme.SetStylebox("hover", "Button", Box("c6dbe5", "355c75", 0));
        theme.SetStylebox("pressed", "Button", Box("e2b2a5", "a33b32", 0));
        var focus = Box("00000000", "355c75", 0);
        focus.ShadowSize = 0;
        theme.SetStylebox("focus", "Button", focus);
        theme.SetStylebox("disabled", "Button", Box("cbb492", "a08a6b", 7));
        theme.SetConstant("outline_size", "Label", 0);
        theme.SetColor("font_outline_color", "Label", new Color("e8d0a6"));
        theme.SetConstant("separation", "VBoxContainer", 12);
        theme.SetConstant("separation", "HBoxContainer", 12);
        return theme;
    }

    StyleBoxFlat Box(string fill, string border, int radius = 10)
    {
        return new StyleBoxFlat {
            BgColor = new Color(fill),
            CornerRadiusTopLeft = 0, CornerRadiusTopRight = 0, CornerRadiusBottomLeft = 0, CornerRadiusBottomRight = 0,
            BorderWidthLeft = 3, BorderWidthTop = 3, BorderWidthRight = 3, BorderWidthBottom = 3,
            BorderColor = new Color(border),
            BorderBlend = false, ShadowColor = new Color("38271f"), ShadowSize = 2, ShadowOffset = new Vector2(4, 4),
            ContentMarginLeft = 12, ContentMarginRight = 12, ContentMarginTop = 10, ContentMarginBottom = 10
        };
    }

    void BuildShell()
    {
        var backdrop = new ColorRect { Color = new Color("b38d65"), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(backdrop); backdrop.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var margin = new MarginContainer(); shell = margin; AddChild(margin); margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        foreach (string side in new[] { "left", "right", "top", "bottom" }) margin.AddThemeConstantOverride("margin_" + side, 24);
        var root = new VBoxContainer(); margin.AddChild(root);
        var headerPanel = new PanelContainer(); headerPanel.AddThemeStyleboxOverride("panel", Box("ead6b6", "61432c")); root.AddChild(headerPanel);
        header = new VBoxContainer();
        header.AddThemeConstantOverride("separation", 4);
        headerPanel.AddChild(header);
        var body = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; root.AddChild(body);
        var leftScroll = new ScrollContainer { CustomMinimumSize = new Vector2(0, 0), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        body.AddChild(leftScroll); leftScroll.Visible = false;
        left = new VBoxContainer { CustomMinimumSize = new Vector2(0, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill }; leftScroll.AddChild(left);
        var center = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        battleCenterMargin = new MarginContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        battleCenterMargin.AddThemeConstantOverride("margin_right", 356);
        battleCenterMargin.AddChild(center); body.AddChild(battleCenterMargin);
        var boardPanel = new PanelContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        boardPanel.AddThemeStyleboxOverride("panel", Box("88674c", "38271f", 0)); center.AddChild(boardPanel);
        board = new BattleBoard { Session = match, CustomMinimumSize = new Vector2(380, 420), SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
        boardPanel.AddChild(board);
        phaseAnnouncement = new Control { Name = "PhaseAnnouncement", MouseFilter = Control.MouseFilterEnum.Ignore, Visible = false, ZIndex = 2000 };
        phaseAnnouncement.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        board.AddChild(phaseAnnouncement);
        phaseCurtain = new ColorRect { Color = new Color("b38d65"), MouseFilter = Control.MouseFilterEnum.Ignore };
        phaseCurtain.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        phaseAnnouncement.AddChild(phaseCurtain);
        phaseTitle = Label("", 44, cyan);
        phaseTitle.HorizontalAlignment = HorizontalAlignment.Center;
        phaseTitle.VerticalAlignment = VerticalAlignment.Center;
        phaseTitle.MouseFilter = Control.MouseFilterEnum.Ignore;
        phaseTitle.AddThemeFontSizeOverride("font_size", 44);
        phaseTitle.AddThemeConstantOverride("outline_size", 3);
        phaseTitle.AddThemeColorOverride("font_outline_color", new Color("ead6b6"));
        phaseTitle.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        phaseAnnouncement.AddChild(phaseTitle);
        board.Resized += () =>
        {
            phaseCurtain.PivotOffset = board.Size / 2;
            phaseTitle.PivotOffset = board.Size / 2;
        };
        board.TileClicked += OnTile;
        board.TileHovered += text =>
        {
            if (GodotObject.IsInstanceValid(tileInfo))
                tileInfo.Text = text == "" ? $"{match.MapName}   /   G: TILE VIEW" : text;
        };
        keyPanel = new PanelContainer { MouseFilter = MouseFilterEnum.Ignore };
        keyPanel.AddThemeStyleboxOverride("panel", Box("c6d6dfef", "355c75", 0));
        keyOverlay = keyPanel; AddChild(keyPanel); keyPanel.SetAnchorsAndOffsetsPreset(LayoutPreset.RightWide);
        var rightScroll = new ScrollContainer {
            HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled,
            VerticalScrollMode = ScrollContainer.ScrollMode.Auto,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsVertical = SizeFlags.ExpandFill
        };
        keyPanel.AddChild(rightScroll);
        right = new VBoxContainer { CustomMinimumSize = new Vector2(232, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill }; rightScroll.AddChild(right);
        footer = new VBoxContainer { CustomMinimumSize = new Vector2(0, 78) }; root.AddChild(footer);
        overlay = new Control { MouseFilter = MouseFilterEnum.Ignore }; AddChild(overlay); overlay.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        syncPanel = new PanelContainer { Visible = false, MouseFilter = MouseFilterEnum.Ignore, ZIndex = 100 };
        syncPanel.AnchorLeft = syncPanel.AnchorRight = 1;
        syncPanel.AnchorTop = syncPanel.AnchorBottom = 0;
        syncPanel.OffsetLeft = -126; syncPanel.OffsetRight = -20;
        syncPanel.OffsetTop = 16; syncPanel.OffsetBottom = 48;
        syncPanel.AddThemeStyleboxOverride("panel", Box("ead6b6", "355c75"));
        syncLabel = Label("SYNC  |", 14, cyan);
        syncLabel.HorizontalAlignment = HorizontalAlignment.Center;
        syncPanel.AddChild(syncLabel);
        AddChild(syncPanel);
        GetViewport().SizeChanged += ResizeBattleLayout;
        ResizeBattleLayout();
    }

    void ResizeBattleLayout()
    {
        if (keyPanel == null) return;
        Vector2 viewport = GetViewportRect().Size;
        float margin = viewport.X < 1200 ? 12 : 24;
        float panelWidth = Mathf.Min(356, Mathf.Max(232, viewport.X * 0.278f));
        if (shell is MarginContainer shellMargin)
            foreach (string side in new[] { "left", "right" }) shellMargin.AddThemeConstantOverride("margin_" + side, Mathf.RoundToInt(margin));
        keyPanel.OffsetLeft = -panelWidth;
        keyPanel.OffsetRight = -margin;
        keyPanel.OffsetTop = Mathf.Max(144, Mathf.RoundToInt(220 - viewport.Y * 0.05f));
        keyPanel.OffsetBottom = -margin;
        battleCenterMargin?.AddThemeConstantOverride("margin_right", Mathf.RoundToInt(panelWidth));
    }

    Label Label(string text, int size = 15, Color? color = null)
    {
        var label = new Label { Text = text };
        label.AddThemeFontSizeOverride("font_size", Math.Max(16, size)); label.AddThemeColorOverride("font_color", color ?? ink);
        return label;
    }

    Label Text(string text, int size = 14, Color? color = null)
    {
        var label = Label(text, size, color); label.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        return label;
    }

    VBoxContainer HealthDisplay(string caption, int current, int maximum, Color color)
    {
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(180, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", 3);
        if (caption.Length > 0) content.AddChild(Label(caption, 18, ink));
        var bar = new ProgressBar { MinValue = 0, MaxValue = Math.Max(1, maximum), Value = Math.Max(0, current), ShowPercentage = false, CustomMinimumSize = new Vector2(0, 26), MouseFilter = MouseFilterEnum.Ignore };
        bar.AddThemeStyleboxOverride("background", new StyleBoxFlat { BgColor = new Color("382b24"), BorderColor = new Color("251c17"), BorderWidthLeft = 2, BorderWidthRight = 2, BorderWidthTop = 2, BorderWidthBottom = 2 });
        bar.AddThemeStyleboxOverride("fill", new StyleBoxFlat { BgColor = color });
        content.AddChild(bar);
        var value = Label($"{current} / {maximum} HP", 18, new Color("fff2d8"));
        value.AddThemeConstantOverride("outline_size", 3); value.AddThemeColorOverride("font_outline_color", new Color("251c17"));
        value.HorizontalAlignment = HorizontalAlignment.Center; value.VerticalAlignment = VerticalAlignment.Center;
        value.MouseFilter = MouseFilterEnum.Ignore; bar.AddChild(value); value.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        return content;
    }

    Button Button(string text, System.Action action, bool disabled = false, bool accent = false)
    {
        var b = new Button { Text = text, Disabled = disabled, CustomMinimumSize = new Vector2(0, 46), MouseDefaultCursorShape = CursorShape.PointingHand };
        b.AddThemeFontSizeOverride("font_size", 24);
        if (accent) { b.AddThemeStyleboxOverride("normal", Box("c6dcb6", "3d6548", 0)); b.AddThemeColorOverride("font_color", cyan); }
        b.Pressed += () => { transient = ""; action(); };
        b.MouseEntered += () => { if (!b.Disabled) sfx?.Play("hover", 0f, -16.5f); };
        b.MouseEntered += () => AnimateButtonHover(b, true);
        b.MouseExited += () => AnimateButtonHover(b, false);
        return b;
    }

    void AnimateButtonHover(Control button, bool hovered)
    {
        if (!GodotObject.IsInstanceValid(button)) return;
        button.PivotOffset = button.Size / 2;
        var tween = button.CreateTween();
        tween.SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(button, "scale", hovered ? new Vector2(1.025f, 1.025f) : Vector2.One, 0.12);
    }

    void BlinkAttention(Control control)
    {
        if (control == null || !control.IsInsideTree()) return;
        var tween = control.CreateTween();
        tween.SetLoops();
        tween.TweenProperty(control, "modulate", new Color(1.0f, 0.82f, 0.55f, 0.72f), 0.6)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        tween.TweenProperty(control, "modulate", Colors.White, 0.6)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    static void Clear(Node node)
    {
        foreach (Node child in node.GetChildren()) { node.RemoveChild(child); child.QueueFree(); }
    }

    VBoxContainer Card(VBoxContainer parent, string eyebrow)
    {
        var panel = new PanelContainer(); panel.AddThemeStyleboxOverride("panel", Box("e4c4b5", "90483d")); parent.AddChild(panel);
        var content = new VBoxContainer(); panel.AddChild(content);
        if (eyebrow.Length > 0) content.AddChild(Label(eyebrow, 11, muted));
        return content;
    }

    Node2D BuildFigure(int kind)
    {
        var figure = new Node2D { ProcessMode = ProcessModeEnum.Always };
        figure.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd"));
        figure.Ready += () => { figure.Call("configure", kind); figure.Call("fit_tile", 192f); };
        return figure;
    }

    void Refresh()
    {
        if (modalOpen) return;
        board.TrailFrames = match.Phase == MatchPhase.Rewind
            ? match.Replay.Skip(match.ReplayExchangeStart).ToArray()
            : Array.Empty<Snapshot>();
        foreach (var figure in showcaseCache.Values) { if (figure.GetParent() != showcaseHolder) figure.Reparent(showcaseHolder, false); figure.Visible = false; }
        Clear(left); Clear(right); Clear(header); Clear(footer); Clear(overlay); Clear(popup);
        shell.Visible = !Choosing;
        keyOverlay.Visible = !Choosing;
        showcase = null; showcaseStage = null; selectionClock = null;
        if (match.Phase != MatchPhase.Deploy) placementOpen = false;
        if (network != null && network.Active && !match.MyTurn && match.Phase != MatchPhase.Deploy && match.Phase != MatchPhase.Menu && match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Finished)
        {
            shell.Visible = false; keyOverlay.Visible = false;
            var wait = FullScreen(match.Phase == MatchPhase.Planning ? "YOUR PLANS ARE LOCKED" : "WAITING FOR OPPONENT");
            wait.AddChild(Label(match.Phase == MatchPhase.Planning ? "Combat starts as soon as both plans are ready." : "Waiting for their combat decision.", 24, cyan));
            selectionClock = Label("", 24, gold); wait.AddChild(selectionClock);
            wait.AddChild(Button("Leave match", ReturnToMenu)); FocusFirst(wait);
            board.Visible = false;
            return;
        }
        board.Visible = true;
        AnnouncePhaseTransition();
        board.CursorRow = match.Phase == MatchPhase.Deploy ? match.CursorRow : -1;
        board.CursorCol = match.Phase == MatchPhase.Deploy ? match.CursorCol : -1;
        var titleRow = new HBoxContainer { CustomMinimumSize = new Vector2(0, 32) };
        header.AddChild(titleRow);
        titleRow.AddChild(Label("PREMOVE", 21, gold));
        clock = Label("", 20, cyan); titleRow.AddChild(clock);
        clock.MouseFilter = MouseFilterEnum.Stop;
        clock.TooltipText = "Plan moves before the timer runs out.";
        titleRow.AddChild(new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill });
        tileInfo = Label($"{match.MapName}   /   G: TILE VIEW", 12, muted);
        tileInfo.HorizontalAlignment = HorizontalAlignment.Right;
        tileInfo.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        titleRow.AddChild(tileInfo);
        headerInfo = new VBoxContainer();
        headerInfo.AddThemeConstantOverride("separation", 2);
        header.AddChild(headerInfo);
        if (match.Phase != MatchPhase.Menu && match.Phase != MatchPhase.Deploy && match.Phase != MatchPhase.Handoff)
        {
            var healthRow = new HBoxContainer { CustomMinimumSize = new Vector2(0, 68) };
            healthRow.AddThemeConstantOverride("separation", 8);
            header.AddChild(healthRow);
            for (int p = 0; p < 2; p++)
            {
                for (int i = 0; i < match.TeamSize; i++)
                {
                    var unit = BattleEngine.getPlayer((uint)p + 1).getCharacter(i);
                    int current = board.DisplayHP(p, i);
                    int max = unit.maxHP();
                    var stats = HealthDisplay($"{MatchSession.ClassName(unit.characterClass())}", current, max, p == 0 ? cyan : coral);
                    stats.MouseFilter = MouseFilterEnum.Stop;
                    healthRow.AddChild(stats);
                }
            }
        }
        if (match.Phase == MatchPhase.Menu) Menu();
        else if (match.Phase == MatchPhase.Handoff) Handoff();
        else if (match.Phase == MatchPhase.Deploy) CharacterScreen();
        else Battle();
        if (match.Phase == MatchPhase.Combat || match.Phase == MatchPhase.Rewind)
        {
            lastMove = Label(moveText, 20, gold); headerInfo.AddChild(lastMove);
        }
        if (match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Rewind) board.Sync();
        if (placementOpen) BuildPlacementPopup();
        if (match.Phase == MatchPhase.Menu) board.Sync();
    }

    void AnnouncePhaseTransition()
    {
        if (match.Lan)
        {
            previousPhase = match.Phase;
            return;
        }
        bool wasPremove = previousPhase is MatchPhase.Planning or MatchPhase.Foresight or MatchPhase.Handoff;
        bool wasAction = previousPhase is MatchPhase.Combat or MatchPhase.Rewind;
        if ((match.Phase is MatchPhase.Planning or MatchPhase.Foresight) && !wasPremove)
            ShowPhaseAnnouncement("PREMOVE PHASE");
        else if (match.Phase == MatchPhase.Combat && !wasAction)
            ShowPhaseAnnouncement("ACTION PHASE");
        previousPhase = match.Phase;
    }

    void ShowPhaseAnnouncement(string title)
    {
        if (phaseTween != null && phaseTween.IsRunning()) phaseTween.Kill();
        phaseAnnouncement.Visible = true;
        phaseCurtain.Color = new Color("b38d65");
        phaseCurtain.Modulate = Colors.White;
        phaseCurtain.Scale = new Vector2(0, 1);
        phaseTitle.Text = title;
        phaseTitle.Scale = new Vector2(0.72f, 0.72f);
        phaseTitle.Rotation = -0.07f;
        phaseTitle.Modulate = new Color(1, 1, 1, 0);

        phaseTween = CreateTween();
        phaseTween.TweenProperty(phaseCurtain, "scale:x", 1.06f, 0.42)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        phaseTween.TweenProperty(phaseCurtain, "scale:x", 1.0f, 0.10)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        phaseTween.TweenCallback(Callable.From(AnimatePhaseTitleIn));
    }

    void AnimatePhaseTitleIn()
    {
        phaseTween = CreateTween().SetParallel(true);
        phaseTween.TweenProperty(phaseTitle, "scale", Vector2.One, 0.38)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        phaseTween.TweenProperty(phaseTitle, "rotation", 0.0, 0.30)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        phaseTween.TweenProperty(phaseTitle, "modulate:a", 1.0, 0.24)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        phaseTween.Chain().TweenInterval(0.62);
        phaseTween.Chain().TweenCallback(Callable.From(AnimatePhaseAnnouncementOut));
    }

    void AnimatePhaseAnnouncementOut()
    {
        phaseTween = CreateTween().SetParallel(true);
        phaseTween.TweenProperty(phaseTitle, "scale", new Vector2(1.12f, 0.82f), 0.34)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.In);
        phaseTween.TweenProperty(phaseTitle, "modulate:a", 0.0, 0.25)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.In);
        phaseTween.TweenProperty(phaseCurtain, "scale:x", 0.0f, 0.46)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.In);
        phaseTween.TweenProperty(phaseCurtain, "scale:y", 0.9f, 0.46)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.In);
        phaseTween.TweenProperty(phaseCurtain, "modulate:a", 0.0, 0.34)
            .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.In);
        phaseTween.Chain().TweenCallback(Callable.From(FinishPhaseAnnouncement));
    }

    void FinishPhaseAnnouncement()
    {
        phaseAnnouncement.Visible = false;
        phaseCurtain.Scale = Vector2.One;
        phaseCurtain.Modulate = Colors.White;
        phaseTitle.Scale = Vector2.One;
        phaseTitle.Rotation = 0;
        phaseTitle.Modulate = Colors.White;
    }

    VBoxContainer FullScreen(string title, float contentWidth = 600)
    {
        Clear(overlay); shell.Visible = false; keyOverlay.Visible = false;
        overlay.Modulate = match.Lan ? Colors.White : new Color(1, 1, 1, 0);
        if (!match.Lan)
        {
            var transition = overlay.CreateTween();
            transition.TweenProperty(overlay, "modulate:a", 1.0, 0.24)
                .SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        }
        var background = new ColorRect { Color = new Color("b38d65") }; overlay.AddChild(background); background.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var margin = new MarginContainer(); overlay.AddChild(margin); margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        foreach (string side in new[] { "left", "right", "top", "bottom" }) margin.AddThemeConstantOverride("margin_" + side, 36);
        var frame = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill }; frame.AddThemeStyleboxOverride("panel", Box("ead6b6", "61432c")); margin.AddChild(frame);
        var center = new CenterContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill }; frame.AddChild(center);
        float availableWidth = Math.Max(320, GetViewportRect().Size.X - 144);
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(Math.Min(contentWidth, availableWidth), 0), SizeFlagsHorizontal = SizeFlags.ShrinkCenter, SizeFlagsVertical = SizeFlags.ShrinkCenter };
        center.AddChild(content);
        content.AddThemeConstantOverride("separation", 14);
        if (title != "") { var heading = Label(title, 32, gold); heading.HorizontalAlignment = HorizontalAlignment.Center; content.AddChild(heading); }
        return content;
    }

    void FocusFirst(Control parent)
    {
        foreach (Node child in parent.GetChildren())
        {
            if (child is Button button && !button.Disabled) { CallDeferred(MethodName.FocusLater, button); return; }
        }
    }
    
    void FocusFirst(Button btn)
    {
        if (GodotObject.IsInstanceValid(btn) && !btn.Disabled) CallDeferred(MethodName.FocusLater, btn);
    }

    void FocusLater(Control node)
    {
        if (GodotObject.IsInstanceValid(node) && node.IsInsideTree()) node.GrabFocus();
    }

    void Menu()
    {
        var page = FullScreen(screen == "title" ? "" : screen == "lan" ? "PLAY OVER LAN" : "CHOOSE AN ARENA", screen == "title" ? 1200 : screen == "map" ? 900 : 600);
        if (screen == "title")
        {
            var columns = new HBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill }; page.AddChild(columns);
            var leftSide = new VBoxContainer { CustomMinimumSize = new Vector2(380, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ShrinkCenter };
            leftSide.AddThemeConstantOverride("separation", 14); columns.AddChild(leftSide);
            leftSide.AddChild(new PixelTitle { Caption = "PREMOVE", PixelScale = 10, Ink = cyan, CustomMinimumSize = new Vector2(380, 80) });
            var tagline = Label("Think ahead. Move together.", 20, coral); leftSide.AddChild(tagline);
            leftSide.AddChild(new Control { CustomMinimumSize = new Vector2(0, 18) });
            leftSide.AddChild(Button("LAN MULTIPLAYER", () => { screen = "lan"; network.BeginDiscovery(); Refresh(); }, accent: true));
            leftSide.AddChild(Button("Couch multiplayer", () => { solo = false; screen = "map"; Refresh(); }));
            leftSide.AddChild(Button("Practice", () => { solo = true; screen = "map"; Refresh(); }));
            leftSide.AddChild(Button("How to play", () => { tutorialPage = 0; ShowHelp(); }));
            leftSide.AddChild(Button("Audio settings", ShowAudio));
            leftSide.AddChild(Button("Quit", () => GetTree().Quit()));
            var rightSide = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill, CustomMinimumSize = new Vector2(420, 0) }; rightSide.AddThemeStyleboxOverride("panel", Box("a08660", "61432c"));
            columns.AddChild(rightSide);
            var tiles = new TitleTiles { SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
            rightSide.AddChild(tiles);
        }
        else if (screen == "lan")
        {
            page.AddChild(Label("Same local network. One hosts, one joins.", 20, cyan));
            page.AddChild(Button("Host game", () => { var error = network.Host(); transient = error == Error.Ok ? "Waiting for player two..." : error.ToString(); Refresh(); }));
            page.AddChild(Label("GAMES ON YOUR NETWORK", 16, gold));
            if (network.DiscoveredHosts.Count == 0)
                page.AddChild(Text("Searching… You can also enter an address below.", 14, muted));
            foreach (string host in network.DiscoveredHosts)
            {
                string addressFound = host;
                page.AddChild(Button($"Join Premove match  ·  {host}", () =>
                {
                    network.Address = addressFound;
                    var error = network.Join();
                    transient = error == Error.Ok ? $"Connecting to {addressFound}…" : error.ToString();
                    Refresh();
                }));
            }
            var address = new LineEdit { PlaceholderText = "Host IP address", Text = network.Address, CustomMinimumSize = new Vector2(0, 48) }; page.AddChild(address);
            address.TextChanged += value => network.Address = value;
            page.AddChild(Button("Join game", () => { var error = network.Join(); transient = error == Error.Ok ? "Connecting..." : error.ToString(); Refresh(); }));
            page.AddChild(Text(transient, 16, coral));
            if (network.IsHost) page.AddChild(Text("Host IP: " + string.Join(", ", IP.GetLocalAddresses().Where(ip => ip.Contains('.') && !ip.StartsWith("127."))), 16, cyan));
            page.AddChild(Button("Choose arena", () => { solo = false; screen = "map"; Refresh(); }, !network.CanStart, true));
            page.AddChild(Button("Back", () => { network.Close(); screen = "title"; Refresh(); }));
        }
        else
        {
            var maps = MapTable.getMaps();
            page.SizeFlagsVertical = SizeFlags.ExpandFill;
            page.CustomMinimumSize = new Vector2(
                Math.Max(320, GetViewportRect().Size.X - 144),
                Math.Max(320, GetViewportRect().Size.Y - 144));
            page.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            page.AddThemeConstantOverride("separation", 12);
            var layout = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
            layout.AddThemeConstantOverride("separation", 20);
            page.AddChild(layout);

            var previewHolder = new PanelContainer {
                CustomMinimumSize = new Vector2(400, 0),
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
                SizeFlagsVertical = SizeFlags.ExpandFill
            };
            previewHolder.AddThemeStyleboxOverride("panel", Box("d7c19f", "61432c", 0));
            var previewControl = new MapPreview { MapIndex = mapIndex, SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
            previewHolder.AddChild(previewControl);
            layout.AddChild(previewHolder);

            var controls = new VBoxContainer {
                CustomMinimumSize = new Vector2(400, 0),
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
                SizeFlagsVertical = SizeFlags.ShrinkCenter
            };
            controls.AddThemeConstantOverride("separation", 18);
            layout.AddChild(controls);
            var mapName = Label(maps[mapIndex].Replace("_", " "), 28, cyan);
            mapName.HorizontalAlignment = HorizontalAlignment.Center;
            controls.AddChild(mapName);

            var nav = new HBoxContainer();
            nav.AddThemeConstantOverride("separation", 12);
            controls.AddChild(nav);
            var previousMap = Button("← Prev", () => { mapIndex = (mapIndex + maps.Length - 1) % maps.Length; Refresh(); });
            previousMap.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            nav.AddChild(previousMap);
            var nextMap = Button("Next →", () => { mapIndex = (mapIndex + 1) % maps.Length; Refresh(); });
            nextMap.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            nav.AddChild(nextMap);

            var partySize = Button($"Party size: {teamSize}", () => { teamSize = teamSize % 3 + 1; Refresh(); });
            partySize.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            controls.AddChild(partySize);
            var maxMoves = Button($"Max moves: {premoveLimit}  [+/-]", () => { premoveLimit = premoveLimit == 10 ? 5 : premoveLimit + 1; Refresh(); });
            maxMoves.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            controls.AddChild(maxMoves);
            var startBtn = Button("Build your party", () => { board.Reset(); match.Start(solo, teamSize, mapIndex, premoveLimit); }, accent: true);
            startBtn.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            controls.AddChild(startBtn);
            var back = Button("Back", () => { screen = network.Active ? "lan" : "title"; Refresh(); });
            back.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            controls.AddChild(back);
            FocusFirst(startBtn);
        }
        page.AddChild(Label("↑ ↓  SELECT     ENTER  CONFIRM     ESC  BACK", 16, muted));
        FocusFirst(page);
    }

    void CharacterScreen()
    {
        teamSize = match.TeamSize; solo = match.Solo; premoveLimit = match.PremoveLimit; mapIndex = match.MapIndex;
        var page = FullScreen($"PLAYER {match.Viewer} · BUILD YOUR PARTY", 1120);
        var columns = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; page.AddChild(columns);
        var main = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; columns.AddChild(main);
        var stageFrame = new PanelContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        stageFrame.AddThemeStyleboxOverride("panel", Box(characterIndex == 0 ? "dfb7a7" : "bfd2df", characterIndex == 0 ? "90483d" : "355c75")); main.AddChild(stageFrame);
        var stage = new Control { CustomMinimumSize = new Vector2(320, 200), SizeFlagsVertical = SizeFlags.ExpandFill, MouseFilter = MouseFilterEnum.Ignore, ClipContents = true }; stageFrame.AddChild(stage); showcaseStage = stage;
        if (characterIndex < 3)
        {
            var figure = showcaseCache[characterIndex == 0 ? 1 : characterIndex == 1 ? 0 : 2]; showcase = figure;
            figure.Reparent(stage, false);
            figure.Call("show_direction", 2); figure.Call("reset_visual"); figure.Call("fit_tile", 192f);
            figure.Visible = true; figure.Modulate = Colors.White;
            void CenterFigure()
            {
                if (GodotObject.IsInstanceValid(stage) && GodotObject.IsInstanceValid(figure))
                    figure.Position = stage.Size / 2;
            }
            stage.ItemRectChanged += CenterFigure;
            CenterFigure();
        }
        else
        {
            var unknown = Label("?", 96, muted); stage.AddChild(unknown); unknown.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); unknown.HorizontalAlignment = HorizontalAlignment.Center; unknown.VerticalAlignment = VerticalAlignment.Center;
        }
        var arrows = new HBoxContainer(); main.AddChild(arrows);
        arrows.AddChild(Button("←", () => BrowseCharacter(-1)));
        var name = Label(characterNames[characterIndex].ToUpperInvariant(), 28, characterIndex == 0 ? coral : cyan); name.SizeFlagsHorizontal = SizeFlags.ExpandFill; name.HorizontalAlignment = HorizontalAlignment.Center; arrows.AddChild(name);
        arrows.AddChild(Button("→", () => BrowseCharacter(1)));
        main.AddChild(Label(characterIndex switch {
            0 => $"Sword & shield  /  {MatchSession.MoveLimit(CharacterClass.WARRIOR, premoveLimit)} moves",
            1 => $"Fire & magic  /  {MatchSession.MoveLimit(CharacterClass.MAGE, premoveLimit)} moves",
            2 => $"Bow & arrows  /  {MatchSession.MoveLimit(CharacterClass.ARCHER, premoveLimit)} moves",
            _ => "Coming soon"
        }, 14, muted));
        if (characterIndex < 3)
        {
            int hp = characterIndex switch { 0 => 120, 1 => 75, _ => 100 };
            main.AddChild(HealthDisplay("", hp, hp, characterIndex == 0 ? coral : cyan));
        }
        var chooseFighter = Button(characterIndex > 2 ? "Coming soon" : "Choose fighter  [Enter]", () => { BeginPlacement(); placementOpen = true; Refresh(); }, characterIndex > 2 || !match.CanAdd, true);
        main.AddChild(chooseFighter);
        if (!chooseFighter.Disabled) BlinkAttention(chooseFighter);
        main.AddChild(Label("← → Browse   Enter Choose   Backspace Remove", 16, muted));
        int perkIndex = (int)match.Perks[match.Viewer - 1];
        var perkCard = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        perkCard.AddThemeStyleboxOverride("panel", Box("d8c9a8", perkIndex switch { 0 => "a33b32", 1 => "355c75", 2 => "62816a", _ => "8a5a2b" }));
        var perkInfo = new VBoxContainer(); perkInfo.AddThemeConstantOverride("separation", 4); perkCard.AddChild(perkInfo); main.AddChild(perkCard);
        var perkHeading = new HBoxContainer(); perkInfo.AddChild(perkHeading);
        perkHeading.AddChild(Label("SUPER PERK", 16, gold));
        var perk = Button($"{MatchSession.PerkNames[perkIndex]}  [P]", CyclePerk, !match.PerkTurn, true);
        perk.SizeFlagsHorizontal = SizeFlags.ExpandFill; perkHeading.AddChild(perk);
        perkInfo.AddChild(Text(MatchSession.PerkDetails[perkIndex], 16, ink));
        var sidebar = new PanelContainer { CustomMinimumSize = new Vector2(260, 0), SizeFlagsVertical = SizeFlags.ExpandFill };
        sidebar.AddThemeStyleboxOverride("panel", Box("c6dcb6", "3d6548")); columns.AddChild(sidebar);
        var party = new VBoxContainer(); sidebar.AddChild(party);
        party.AddChild(Label($"PARTY  {match.Rosters[match.Viewer - 1].Count}/{teamSize}", 20, new Color("294b35")));
        selectionClock = Label("", 20, cyan); party.AddChild(selectionClock);
        for (int i = 0; i < teamSize; i++)
        {
            var card = new PanelContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; card.AddThemeStyleboxOverride("panel", Box("e5edda", "62816a")); party.AddChild(card);
            var fighterBox = new VBoxContainer { SizeFlagsVertical = SizeFlags.ShrinkCenter }; card.AddChild(fighterBox);
            fighterBox.AddThemeConstantOverride("separation", 4);
            if (i >= match.Rosters[match.Viewer - 1].Count)
            {
                var empty = Label("+", teamSize == 1 ? 60 : 32, new Color("62816a")); empty.HorizontalAlignment = HorizontalAlignment.Center; fighterBox.AddChild(empty);
                fighterBox.AddChild(Label($"Slot {i + 1}", 18, muted));
                if (match.Lan) fighterBox.AddChild(Label("Auto-pick at deadline", 14, muted));
                continue;
            }
            var at = match.Spawns[match.Viewer - 1][i]; var kind = match.Rosters[match.Viewer - 1][i];
            PortraitRow(fighterBox, $"FIGHTER {i + 1} · {MatchSession.ClassName(kind)}", $"Tile {at.y + 1},{at.x + 1}", kind == CharacterClass.MAGE ? "mage" : kind == CharacterClass.ARCHER ? "archer" : "knight", false);
            int hp = kind switch { CharacterClass.MAGE => 75, CharacterClass.ARCHER => 100, _ => 120 };
            fighterBox.AddChild(HealthDisplay("", hp, hp, new Color("3d6548")));
            int index = i; fighterBox.AddChild(Button("Remove", () => match.RemoveFighter(index), !match.MyTurn));
        }
        bool ready = match.Lan && match.DeploymentReady(match.Viewer);
        var enterArena = Button(ready ? "READY" : "Enter arena  [Space]", match.ConfirmDeployment, ready || match.Rosters[match.Viewer - 1].Count != teamSize, true);
        party.AddChild(enterArena);
        if (!enterArena.Disabled) BlinkAttention(enterArena);
        if (match.Lan)
            party.AddChild(Text(match.DeploymentReady(3 - match.Viewer) ? "Opponent ready." : "Both ready: start.", 14, cyan));
        if (transient.Length > 0) main.AddChild(Text(transient, 14, coral));
    }

    void BrowseCharacter(int direction) { characterIndex = (characterIndex + direction + 4) % 4; transient = ""; Refresh(); }
    void CyclePerk()
    {
        int start = (int)match.Perks[match.Viewer - 1];
        for (int i = 1; i <= 4; i++)
        {
            int next = (start + i) % 4;
            if ((int)match.Perks[2 - match.Viewer] == next) continue;
            match.SetPerk(next); break;
        }
        Refresh();
    }
    void BeginPlacement()
    {
        if (characterIndex > 2 || !match.CanAdd) return;
        match.SelectClass(characterIndex switch { 0 => CharacterClass.WARRIOR, 1 => CharacterClass.MAGE, _ => CharacterClass.ARCHER });
        transient = match.Message;
        if (GodotObject.IsInstanceValid(showcase)) showcase.Call("perform", -1, 2, showcase.Position, showcase.Position + new Vector2(100, 0), 1.0f);
        Refresh();
    }

    VBoxContainer OpenPopup(string title)
    {
        Clear(popup);
        var shade = new ColorRect { Color = new Color(0.05f, 0.04f, 0.02f, 0.85f) }; popup.AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer(); popup.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = new PanelContainer(); center.AddChild(panel); panel.AddThemeStyleboxOverride("panel", Box("ead6b6", "61432c", 0));
        var content = new VBoxContainer(); panel.AddChild(content);
        content.AddChild(Label(title, 24, gold));
        return content;
    }

    void BuildPlacementPopup()
    {
        // Hide showcase during placement
        if (GodotObject.IsInstanceValid(showcase)) showcase.Visible = false;
        var content = OpenPopup($"DEPLOY {MatchSession.ClassName((CharacterClass)match.SelectedClass).ToUpperInvariant()}");
        var map = new PlacementMap { Session = match, CursorRow = match.CursorRow, CursorCol = match.CursorCol, MapIndex = mapIndex };
        map.TilePicked += (row, col) => { if (match.PlaceAt(row, col)) ClosePlacementPopup(); };
        content.AddChild(map);
        var legend = new GridContainer { Columns = 3 }; content.AddChild(legend);
        foreach (var (color, caption) in new[] { ("a8dfb2", "Ground"), ("f0d264", "Damage"), ("e74c3c", "Fatal"), ("2d1f1a", "Wall"), ("101010", "Enemy side"), ("f3eee9", "Cursor outline") })
        {
            var entry = new HBoxContainer(); legend.AddChild(entry);
            entry.AddChild(new ColorRect { Color = new Color(color), CustomMinimumSize = new Vector2(12, 12), SizeFlagsVertical = SizeFlags.ShrinkCenter });
            entry.AddChild(Label(caption, 16, muted));
        }
        content.AddChild(Label("Dim tiles are unavailable. Choose a bright tile in your half.", 16, muted));
        content.AddChild(Label($"TILE {match.CursorCol + 1:00} / {match.CursorRow + 1:00}   ·   WASD moves · ENTER places · ESC cancels", 14, muted));
        content.AddChild(Button("Cancel  [Esc]", () => { ClosePlacementPopup(); }));
        FocusFirst(content);
    }

    void ClosePlacementPopup()
    {
        placementOpen = false;
        if (GodotObject.IsInstanceValid(showcase)) showcase.Visible = true;
        Refresh();
    }

    void PortraitRow(VBoxContainer parent, string name, string description, string asset, bool dim)
    {
        var row = new HBoxContainer(); parent.AddChild(row);
        var portrait = new TextureRect { Texture = GD.Load<Texture2D>($"res://assets/sprites/{asset}_portrait.png"), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, CustomMinimumSize = new Vector2(64, 72), TextureFilter = TextureFilterEnum.Nearest, Modulate = dim ? new Color(0.6f, 0.65f, 0.7f) : Colors.White };
        row.AddChild(portrait);
        var captions = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; row.AddChild(captions);
        captions.AddChild(Label(name, 17, dim ? muted : ink)); captions.AddChild(Text(description, 12, muted));
    }

    void Handoff()
    {
        var panel = FullScreen($"PLAYER {match.Viewer}");
        panel.AddChild(Label(match.HandoffText, 24, cyan));
        if (!network.Active) panel.AddChild(Text("Pass the keyboard. Your choices stay private.", 24, muted));
        var ready = Button("Ready  [Enter]", match.ContinueHandoff, accent: true);
        panel.AddChild(ready);
        BlinkAttention(ready);
        FocusFirst(panel);
    }

    void Battle()
    {
        bool planning = match.Phase is MatchPhase.Planning or MatchPhase.Foresight;
        if (match.Phase == MatchPhase.Selection)
        {
            right.AddChild(Label($"PLAYER {match.Viewer} / CHOOSE FIGHTER", 20, gold));
            right.AddChild(Text("Click one of your available fighters on the map, or choose below.", 16, muted));
            foreach (int fighterIndex in match.Available(match.Viewer))
            {
                int index = fighterIndex;
                Character fighter = BattleEngine.getPlayer((uint)match.Viewer).getCharacter(index);
                var position = fighter.currentPosition();
                var choice = Button(
                    $"FIGHTER {index + 1} · {MatchSession.ClassName(fighter.characterClass())} · {fighter.currentHP()} HP · tile {position.y + 1},{position.x + 1}",
                    () => { match.Fighter = index; match.ConfirmFighter(); },
                    accent: match.Fighter == index);
                right.AddChild(choice);
                BlinkAttention(choice);
            }
            return;
        }
        if (match.Phase == MatchPhase.Finished)
        {
            var page = FullScreen(match.Message.ToUpperInvariant());
            page.AddChild(Button("Rematch", () => { board.Reset(); match.Start(solo, teamSize, mapIndex, premoveLimit); }, network.Active && !network.CanStart, true));
            page.AddChild(Button("Main menu", ReturnToMenu)); FocusFirst(page); return;
        }
        if (planning) ActionPanel();
        if (planning)
        {
            var next = Button($"FIGHTER {match.Fighter + 1} · {MatchSession.ClassName(match.Current.characterClass())}  [Tab]", CyclePlannedFighter); right.AddChild(next);
            next.TooltipText = "Plan moves for each fighter before locking.";
            var ready = Button(match.Phase == MatchPhase.Foresight ? "Continue to fighter selection  [Space]" : "Ready to fight  [Space]", match.LockPlan, accent: true);
            right.AddChild(ready);
            BlinkAttention(ready);
            var intel = BattleEngine.getVisibleOpponentSteps((uint)match.Viewer);
            if (intel.Length > 0)
            {
                var reveal = Button("Revealed enemy plan", () => {
                    var panel = Modal(); panel.AddChild(Label("ENEMY PLAN", 24, coral));
                    int revealed = BattleEngine.getTacticianRevealedCharacter((uint)match.Viewer);
                    for (int i = 0; i < intel.Length; i++)
                    {
                        var kind = match.Rosters[2 - match.Viewer][revealed >= 0 ? revealed : i];
                        panel.AddChild(Text(MatchSession.ClassName(kind) + ": " + string.Join(" · ", intel[i].TakeWhile(a => a != 0).Select(a => MatchSession.ActionName(a, kind))), 16, cyan));
                    }
                    panel.AddChild(Button("Back", Refresh)); FocusFirst(panel);
                }); right.AddChild(reveal);
            }
            Timeline();
        }
        else if (match.Phase == MatchPhase.Rewind)
        {
            ShowRewindPopup();
        }
        else if (match.Phase == MatchPhase.Combat) CombatKeys();
    }

    void CyclePlannedFighter()
    {
        for (int offset = 1; offset <= match.TeamSize; offset++)
        {
            int index = (match.Fighter + offset) % match.TeamSize;
            if (!BattleEngine.getPlayer((uint)match.Viewer).getCharacter(index).isAlive()) continue;
            match.Fighter = index;
            match.Slot = 0;
            match.Action = 0;
            Refresh();
            return;
        }
    }

    void ShowRewindPopup()
    {
        if (rewindPopup) return;
        rewindPopup = modalOpen = true;
        BuildRewindPopup();
    }

    void BuildRewindPopup()
    {
        Clear(popup);
        var shade = new ColorRect { Color = new Color(0.02f, 0.05f, 0.08f, 0.72f) };
        popup.AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore };
        popup.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        float width = Math.Max(320, Math.Min(780, GetViewportRect().Size.X - 64));
        var panel = new PanelContainer { CustomMinimumSize = new Vector2(width, 0) };
        center.AddChild(panel); panel.AddThemeStyleboxOverride("panel", Box("ead6b6", "61432c", 0));
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(width - 36, 0) };
        panel.AddChild(content); content.AddThemeConstantOverride("separation", 8);
        content.AddChild(Label("DEFY DESTINY  /  EXCHANGE REVIEW", 25, gold));
        content.AddChild(Text("The exchange has ended. Review both players’ simultaneous moves and the trail on the map. Replace your final action once, or keep the outcome.", 14, muted));

        var history = new ScrollContainer
        {
            CustomMinimumSize = new Vector2(width - 52, Math.Min(220, GetViewportRect().Size.Y * 0.28f)),
            HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled,
            VerticalScrollMode = ScrollContainer.ScrollMode.Auto
        };
        content.AddChild(history);
        var rows = new VBoxContainer(); history.AddChild(rows);
        int first = Math.Clamp(match.ReplayExchangeStart, 0, Math.Max(0, match.Replay.Count - 1));
        for (int i = first + 1; i < match.Replay.Count; i++)
        {
            Snapshot before = match.Replay[i - 1], after = match.Replay[i];
            rows.AddChild(Text($"TICK {i - first:00}  ·  {ReplayMove(before, after, 0)}   /   {ReplayMove(before, after, 1)}", 13, cyan));
        }
        if (rows.GetChildCount() == 0)
            rows.AddChild(Text("No moves were recorded in this exchange.", 13, muted));

        Character unit = match.Current;
        bool canDecide = match.MyTurn;
        content.AddChild(Label($"REPLACE ONE FINAL ACTION  ·  {MatchSession.ClassName(unit.characterClass())}", 17, gold));
        if (canDecide)
        {
            var actions = new GridContainer { Columns = 4 }; content.AddChild(actions);
            foreach (var (caption, action) in new[] { ("End", 0), ("↑", 1), ("↓", 2), ("←", 3), ("→", 4) })
                actions.AddChild(Button(caption, () => SetRewindAction(action), accent: match.Action == action));
            if (match.Perks[match.Viewer - 1] == SuperPerk.Teleport)
                actions.AddChild(Button("Blink", () => SetRewindAction(5), accent: match.Action == 5));
            string[] skills = MatchSession.SkillNames(unit.characterClass());
            for (int i = 0; i < skills.Length; i++)
            {
                int action = -i - 1;
                actions.AddChild(Button(skills[i], () => SetRewindAction(action), accent: match.Action == action));
            }

            var aim = new HBoxContainer(); content.AddChild(aim);
            aim.AddChild(Label($"Aim: {new[] { "", "↑", "↓", "←", "→" }[match.Direction]}   Range: {match.Range}", 15, cyan));
            foreach (var (caption, direction) in new[] { ("↑", 1), ("↓", 2), ("←", 3), ("→", 4) })
                aim.AddChild(Button(caption, () => { match.Direction = direction; BuildRewindPopup(); }));
            aim.AddChild(Button("−", () => { match.StepRange(-1); BuildRewindPopup(); }));
            aim.AddChild(Button("+", () => { match.StepRange(1); BuildRewindPopup(); }));

            var choices = new HBoxContainer(); content.AddChild(choices);
            choices.AddChild(Button("Risk 70% replacement", () =>
            {
                rewindPopup = modalOpen = false;
                match.Rewind(true);
            }, accent: true));
            choices.AddChild(Button("Keep the outcome", () =>
            {
                rewindPopup = modalOpen = false;
                match.Rewind(false);
            }));
            FocusFirst(content);
        }
        else
        {
            content.AddChild(Text($"Waiting for Player {match.Viewer} to make their Defy Destiny choice.", 16, cyan));
        }
    }

    void SetRewindAction(int action)
    {
        match.Action = action;
        if (action < 0)
        {
            int[] ranges = MatchSession.SkillRanges(match.Current.characterClass(), -action - 1);
            if (ranges.Length > 0 && !ranges.Contains(match.Range)) match.Range = ranges[0];
        }
        BuildRewindPopup();
    }

    string ReplayMove(Snapshot before, Snapshot after, int player)
    {
        int fighter = before.selected[player];
        if (fighter < 0 || fighter >= match.Rosters[player].Count) return $"P{player + 1}: —";
        int slot = before.exchangeTick;
        int action = slot < before.steps[player][fighter].Length ? before.steps[player][fighter][slot] : 0;
        string name = MatchSession.ActionName(action, match.Rosters[player][fighter]);
        var positions = player == 0 ? before.player1CharacterPositions : before.player2CharacterPositions;
        var next = player == 0 ? after.player1CharacterPositions : after.player2CharacterPositions;
        IVector2 from = positions[fighter], to = next[fighter];
        bool skipped = action < 0 && before.cooldowns[player][fighter][-action - 1] > 1
            || action == 5 && before.teleportCooldowns[player][fighter] > 1;
        string result = $"P{player + 1} {MatchSession.ClassName(match.Rosters[player][fighter])} {name}";
        if (skipped) result += " (cooldown)";
        return $"{result}  [{from.x + 1},{from.y + 1} → {to.x + 1},{to.y + 1}]";
    }

    void CombatKeys()
    {
        var state = BattleEngine.getDetails();
        if (state == null) return;
        for (int p = 0; p < 2; p++)
        {
            int index = state.selected[p];
            if (index < 0 || index >= BattleEngine.getPlayer((uint)p + 1).count()) continue;
            var unit = BattleEngine.getPlayer((uint)p + 1).getCharacter(index);
            right.AddChild(Label($"P{p + 1}  {MatchSession.ClassName(unit.characterClass())}", 24, p == 0 ? cyan : coral));
            var pad = new GridContainer { Columns = 3 }; right.AddChild(pad);
            var names = MatchSession.SkillNames(unit.characterClass());
            for (int row = 2; row >= 0; row--) for (int col = 1; col <= 3; col++)
            {
                int number = row * 3 + col;
                bool active = executing[p] == -number;
                var panel = new PanelContainer(); panel.AddThemeStyleboxOverride("panel", Box(active ? "f4e3c2" : "e6cfa8dd", active ? "8a5a2b" : "8a6a45aa"));
                panel.CustomMinimumSize = new Vector2(76, 52); pad.AddChild(panel);
                var label = Label(number <= names.Length ? $"{number}  {(unit.currentCooldown()[number - 1] > 1 ? "CD" : "")}" : "·", 24, active ? Colors.White : muted); label.HorizontalAlignment = HorizontalAlignment.Center; panel.AddChild(label);
                if (number <= names.Length) panel.TooltipText = names[number - 1] + $" · cooldown {Math.Max(0, unit.currentCooldown()[number - 1] - 1)}";
                if (active) BlinkAttention(panel);
            }
            MovementKeys(right, executing[p]);
        }
    }

    void MovementKeys(VBoxContainer parent, int active)
    {
        var row = new HBoxContainer(); row.AddThemeConstantOverride("separation", 4); parent.AddChild(row);
        foreach (var (key, action) in new[] { ("W", 1), ("A", 3), ("S", 2), ("D", 4), ("T", 5) })
        {
            var cap = new PanelContainer { CustomMinimumSize = new Vector2(47, 36) }; row.AddChild(cap);
            var style = Box(active == action ? "f4e3c2" : "e6cfa8dd", active == action ? "8a5a2b" : "8a6a45aa");
            style.ContentMarginLeft = style.ContentMarginRight = style.ContentMarginTop = style.ContentMarginBottom = 4; cap.AddThemeStyleboxOverride("panel", style);
            var label = Label(key, 24, active == action ? Colors.White : muted); label.HorizontalAlignment = HorizontalAlignment.Center; cap.AddChild(label);
            if (active == action) BlinkAttention(cap);
        }
    }

    void ActionPanel()
    {
        Character unit = match.Current;
        if (unit == null) return;
        var actions = new VBoxContainer(); right.AddChild(actions);
        var commandFrame = new PanelContainer();
        commandFrame.AddThemeStyleboxOverride("panel", Box("e8ddc1", "355c75"));
        actions.AddChild(commandFrame);
        var commands = new VBoxContainer(); commandFrame.AddChild(commands);
        commands.AddChild(Label("COMMANDS  ·  NUMPAD", 17, cyan));
        string[] names = MatchSession.SkillNames(unit.characterClass());
        string[] details = MatchSession.SkillDetails(unit.characterClass());
        int[] cooldown = PlanningCooldowns(unit);
        var pad = new GridContainer { Columns = 3 }; commands.AddChild(pad);
        foreach (int number in new[] { 7, 8, 9, 4, 5, 6, 1, 2, 3 })
        {
            int skill = -number;
            bool exists = number <= names.Length;
            int remaining = exists ? Math.Max(0, cooldown[number - 1]) : 0;
            int maximumCooldown = exists ? MatchSession.Cooldowns(unit.characterClass())[number - 1] : 0;
            bool ready = remaining == 0;
            string caption = exists ? $"{number}\n{SkillButtonName(names[number - 1])}\n{(ready ? "READY" : $"CD {remaining}")}" : number.ToString();
            var key = Button(caption, () => { if (exists) match.SelectSkill(number); Refresh(); }, !exists, match.Action == skill);
            key.AddThemeFontSizeOverride("font_size", 16);
            key.CustomMinimumSize = new Vector2(65, 84); key.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            string fillColor = !exists ? "77736d" : ready ? "8fd694" : "77736d";
            string borderColor = match.Action == skill ? "355c75" : "8a6a45aa";
            var cap = Box(fillColor, borderColor);
            cap.ContentMarginLeft = cap.ContentMarginRight = 4;
            key.AddThemeStyleboxOverride("normal", cap);
            key.AddThemeStyleboxOverride("hover", Box(ready ? "a6e3a4" : "8b8980", borderColor));
            key.AddThemeStyleboxOverride("pressed", Box(ready ? "76c77c" : "686760", borderColor));
            key.AddThemeStyleboxOverride("disabled", Box("77736d", borderColor));
            if (exists)
            {
                var recharge = new ProgressBar
                {
                    MinValue = 0,
                    MaxValue = Math.Max(1, maximumCooldown),
                    Value = ready || maximumCooldown == 0
                        ? Math.Max(1, maximumCooldown)
                        : Math.Clamp(maximumCooldown - remaining, 0, maximumCooldown),
                    ShowPercentage = false,
                    MouseFilter = MouseFilterEnum.Ignore,
                    AnchorLeft = 0,
                    AnchorRight = 1,
                    AnchorTop = 1,
                    AnchorBottom = 1,
                    OffsetLeft = 5,
                    OffsetRight = -5,
                    OffsetTop = -13,
                    OffsetBottom = -5
                };
                recharge.AddThemeStyleboxOverride("background", new StyleBoxFlat { BgColor = new Color("49453f") });
                recharge.AddThemeStyleboxOverride("fill", new StyleBoxFlat { BgColor = new Color("76c77c") });
                key.AddChild(recharge);
                key.TooltipText = details[number - 1] + (ready ? " · ready" : $" · recharging: {remaining} turn{(remaining == 1 ? "" : "s")} left");
            }
            pad.AddChild(key);
        }
        commands.AddChild(Label("MOVEMENT", 15, muted));
        MovementKeys(commands, match.Action);
        if (match.Action < 0 || match.Action == 5)
        {
            actions.TooltipText = match.Action < 0 ? details[-match.Action - 1] : "Choose a safe teleport destination.";
            actions.AddChild(Label($"Aim {new[] { "", "↑", "↓", "←", "→" }[match.Direction]}   Range {match.Range}", 24, cyan));
            actions.AddChild(Label("ARROWS aim   +/- range", 16, muted));
            actions.AddChild(Label("ENTER add · NUM 0 end", 16, gold));
        }

        static string SkillButtonName(string name) => name switch
        {
            "Cinderbolt" => "Cinder",
            "Ember Aegis" => "Aegis",
            "Prism Barrage" => "Prism",
            "Trueflight" => "Trueflight",
            "Twinstring" => "Twinstring",
            "Piercing Draw" => "Piercer",
            "Lance Thrust" => "Thrust",
            "Skybreaker" => "Skybreak",
            "Knight's Edge" => "Knight's Edge",
            "Iron Vow" => "Iron Vow",
            _ => name
        };
    }

    int[] PlanningCooldowns(Character unit)
    {
        var cooldown = unit.currentCooldown();
        for (int i = 0; i <= match.Slot; i++)
        {
            for (int k = 0; k < cooldown.Length; k++) cooldown[k]--;
            if (i == match.Slot || unit.getStep(i) == 0) break;
            int action = unit.getStep(i);
            if (action < 0 && cooldown[-action - 1] <= 0) cooldown[-action - 1] = MatchSession.Cooldowns(unit.characterClass())[-action - 1] + 1;
        }
        return cooldown;
    }

    void Timeline()
    {
        Character unit = match.Current;
        var scroll = new ScrollContainer { HorizontalScrollMode = ScrollContainer.ScrollMode.Auto, VerticalScrollMode = ScrollContainer.ScrollMode.Disabled, SizeFlagsVertical = SizeFlags.ExpandFill };
        footer.AddChild(scroll);
        var slots = new HBoxContainer(); scroll.AddChild(slots);
        bool ended = false;
        for (int i = 0; i < unit.stepCount(); i++)
        {
            int index = i, action = unit.getStep(i);
            string name = MatchSession.ActionName(action, unit.characterClass());
            var b = Button($"{i + 1:00}\n{name}", () => { match.Slot = index; Refresh(); }, accent: match.Slot == i);
            b.CustomMinimumSize = new Vector2(77, 58); b.AddThemeFontSizeOverride("font_size", 16);
            b.TooltipText = action < 0 ? $"{name} · direction {unit.getDirection(i)} · range {unit.getLength(i).x}" : name;
            if (ended) b.Modulate = new Color(0.6f, 0.65f, 0.7f);
            slots.AddChild(b); if (action == 0) ended = true;
        }
        right.AddChild(Text("WASD move · NUM skill · ←→ aim · ENTER add · SPACE lock", 12, muted));
        right.AddChild(Text("Click a slot to edit; later moves clear. Skills on cooldown are skipped.", 12, muted));
        if (transient.Length > 0 || match.Message.Length > 0)
            right.AddChild(Text(transient.Length > 0 ? transient : match.Message, 12, muted));
    }

    void ShowLastMoves(Snapshot before)
    {
        var moves = new System.Collections.Generic.List<string>();
        for (int p = 0; p < 2; p++)
        {
            int fighter = before.selected[p], slot = before.exchangeTick;
            if (fighter < 0 || fighter >= match.Rosters[p].Count) continue;
            int action = slot < before.steps[p][fighter].Length ? before.steps[p][fighter][slot] : 0;
            bool skipped = action < 0 && before.cooldowns[p][fighter][-action - 1] > 1 || action == 5 && before.teleportCooldowns[p][fighter] > 1;
            executing[p] = skipped ? 0 : action;
            string key = action < 0 ? $"NUM {-action}" : action switch { 1 => "W", 2 => "S", 3 => "A", 4 => "D", 5 => "T", _ => "0" };
            moves.Add($"P{p + 1} [{key}]  {MatchSession.ActionName(action, match.Rosters[p][fighter])}{(skipped ? " · COOLDOWN" : "")}");
        }
        moveText = string.Join("     /     ", moves);
    }

    void FooterMessage(string title, string message)
    {
        footer.AddChild(Label(title, 12, cyan)); footer.AddChild(Text(message, 16, muted));
        footer.AddChild(Label("SKY ISLAND     /     PREMOVE", 11, new Color("6f573c")));
    }

    void OnTile(int row, int col)
    {
        if (match.Phase == MatchPhase.Selection)
        {
            foreach (int fighter in match.Available(match.Viewer))
            {
                Character unit = BattleEngine.getPlayer((uint)match.Viewer).getCharacter(fighter);
                IVector2 position = unit.currentPosition();
                if (position.x != row || position.y != col) continue;
                match.Fighter = fighter;
                match.ConfirmFighter();
                return;
            }
            return;
        }
        if (match.Phase != MatchPhase.Planning && match.Phase != MatchPhase.Foresight && match.Phase != MatchPhase.Rewind) return;
        var from = match.Phase == MatchPhase.Rewind ? match.Current.currentPosition() : BattleEngine.previewPosition((uint)match.Viewer, match.Fighter, match.Slot - 1);
        if (match.Action == 0)
        {
            for (int i = 0; i < teamSize; i++)
            {
                var unit = BattleEngine.getPlayer((uint)match.Viewer).getCharacter(i);
                if (unit.currentPosition().x == row && unit.currentPosition().y == col) { match.Fighter = i; match.Slot = 0; Refresh(); return; }
            }
        }
        int dr = row - from.x, dc = col - from.y;
        if (dr != 0 && dc != 0) { transient = "Aim along a row or column. Prism Barrage and defensive skills target automatically."; Refresh(); return; }
        if (dr == 0 && dc == 0) return;
        match.Direction = dr == 0 ? dc < 0 ? 3 : 4 : dr < 0 ? 1 : 2;
        match.Range = Math.Abs(dr + dc); Refresh();
    }

    VBoxContainer Modal()
    {
        Clear(popup);
        var shade = new ColorRect { Color = new Color(0.02f, 0.05f, 0.08f, 0.92f) }; popup.AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore }; popup.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = new PanelContainer { CustomMinimumSize = new Vector2(530, 0) }; center.AddChild(panel); panel.AddThemeStyleboxOverride("panel", Box("ead6b6", "61432c", 0));
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(490, 0) }; panel.AddChild(content);
        return content;
    }

    void ShowHelp()
    {
        modalOpen = true;
        match.Paused = !network.Active;
        var panel = Modal();
        string[] titles = { "1 / 3  ·  THINK AHEAD", "2 / 3  ·  PICK A SKILL", "3 / 3  ·  MOVE TOGETHER" };
        string[] tips = { "WASD writes moves into your sequence.\nBackspace returns to the previous slot.", "Numpad 1–5 chooses a skill. Arrows aim.\n+ / - changes range. Enter adds it to your plan.", match.Lan ? "Space locks your plan. Both ready: combat starts.\nFighters take turns automatically." : "Space locks your plan. Pick a fighter, then Enter.\nBoth sides act together. Defeat the enemy party!" };
        panel.AddChild(Label(titles[tutorialPage], 30, gold));
        panel.AddChild(Text(tips[tutorialPage], 24, cyan));
        panel.AddChild(Button(tutorialPage < 2 ? "Next" : "Let's play", () => { if (++tutorialPage < 3) ShowHelp(); else { tutorialPage = 0; modalOpen = false; match.Paused = false; Refresh(); } }, accent: true));
        FocusFirst(panel);
    }

    void ShowPause()
    {
        modalOpen = true;
        var panel = Modal(); panel.AddChild(Label(network.Active ? "MENU / MATCH CONTINUES" : "PAUSED", 30, gold));
        panel.AddChild(Button("Resume", () => { modalOpen = false; match.Paused = false; Refresh(); }, accent: true));
        panel.AddChild(Button("How to play", () => { tutorialPage = 0; ShowHelp(); }));
        panel.AddChild(Button(board.TrackCamera ? "Camera: follow fighters" : "Camera: whole map", () => { board.TrackCamera = !board.TrackCamera; ShowPause(); }));
        panel.AddChild(Button("Fullscreen / windowed", ToggleFullscreen));
        panel.AddChild(Button("Audio settings", ShowAudio));
        panel.AddChild(Button("Return to menu", ReturnToMenu));
        FocusFirst(panel);
    }

    void ReturnToMenu()
    {
        network?.Close(); match.Lan = false; match.Local = match.Viewer = 1; modalOpen = false; screen = "title"; match.Paused = false; match.Phase = MatchPhase.Menu; board.Reset(); Refresh();
    }
    void ToggleFullscreen() => DisplayServer.WindowSetMode(DisplayServer.WindowGetMode() == DisplayServer.WindowMode.Fullscreen ? DisplayServer.WindowMode.Windowed : DisplayServer.WindowMode.Fullscreen);

    void SyncMusic()
    {
        if (music == null) return;
        if (match.Phase == MatchPhase.Menu) { music.Play("title"); return; }
        if (match.Phase == MatchPhase.Finished)
        {
            int outcome = BattleEngine.getOutcome();
            bool won = match.Solo ? outcome == 1 : outcome == match.Local;
            music.Play(won ? "victory" : "defeat");
            return;
        }
        music.Play("battle");
    }

    void ShowAudio()
    {
        modalOpen = true;
        match.Paused = match.Phase != MatchPhase.Menu && !network.Active;
        var panel = Modal();
        panel.AddChild(Label("AUDIO", 30, gold));
        var musicSlider = VolumeRow(panel, "Music", music.Volume, music.SetVolume);
        VolumeRow(panel, "Effects", sfx.Volume, sfx.SetVolume);
        panel.AddChild(Button(music.Muted ? "Music: muted" : "Music: on", () => { music.SetMuted(!music.Muted); ShowAudio(); }));
        panel.AddChild(Button(sfx.Muted ? "Effects: muted" : "Effects: on", () => { sfx.SetMuted(!sfx.Muted); ShowAudio(); }));
        panel.AddChild(Text("Tracks live in assets/music; hit sounds in assets/sounds (.ogg, .wav or .mp3).", 13, muted));
        panel.AddChild(Button("Back", () =>
        {
            if (match.Phase == MatchPhase.Menu) { modalOpen = false; Refresh(); }
            else ShowPause();
        }));
        CallDeferred(MethodName.FocusLater, musicSlider);
    }

    HSlider VolumeRow(VBoxContainer panel, string caption, float value, System.Action<float> apply)
    {
        var row = new HBoxContainer();
        row.AddChild(Label(caption, 24, cyan));
        var readout = Label($"{Mathf.RoundToInt(value * 100)}%", 24, ink);
        var slider = new HSlider { MinValue = 0, MaxValue = 100, Step = 1, Value = Mathf.Round(value * 100), SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ShrinkCenter, CustomMinimumSize = new Vector2(240, 28) };
        var track = new StyleBoxFlat { BgColor = new Color("b08a5e"), BorderColor = new Color("8a6a45"), BorderWidthLeft = 2, BorderWidthTop = 2, BorderWidthRight = 2, BorderWidthBottom = 2, ContentMarginTop = 4, ContentMarginBottom = 4 };
        var fill = new StyleBoxFlat { BgColor = cyan, ContentMarginTop = 4, ContentMarginBottom = 4 };
        slider.AddThemeStyleboxOverride("slider", track);
        slider.AddThemeStyleboxOverride("grabber_area", fill);
        slider.AddThemeStyleboxOverride("grabber_area_highlight", fill);
        slider.ValueChanged += changed => { apply((float)changed / 100f); readout.Text = $"{changed:0}%"; };
        row.AddChild(slider);
        row.AddChild(readout);
        panel.AddChild(row);
        return slider;
    }

    public override void _Process(double delta)
    {
        SyncMusic();
        GetTree().Paused = match.Paused;
        bool syncing = network.Active && Time.GetTicksMsec() < syncUntil;
        syncPanel.Visible = syncing;
        if (syncing)
        {
            string[] frames = { "|", "/", "—", "\\" };
            syncLabel.Text = $"SYNC  {frames[(int)((Time.GetTicksMsec() / 120) % (ulong)frames.Length)]}";
        }
        if (network.Active && !match.Lan)
        {
            match.Lan = true; match.Local = network.LocalPlayer; match.Viewer = match.Local;
            solo = false;
        }
        network.Advance(delta);
        if (match.Phase == MatchPhase.Deploy && GodotObject.IsInstanceValid(showcaseStage) && GodotObject.IsInstanceValid(showcase))
            {
            showcase.Position = showcaseStage.Size / 2;
            showcase.Call("fit_display", showcaseStage.Size - new Vector2(72, 48));
        }
        if (GodotObject.IsInstanceValid(selectionClock))
            selectionClock.Text = match.Phase == MatchPhase.Deploy
                ? match.Lan ? $"{Math.Ceiling(match.Seconds):00}s TO CHOOSE" : $"MAX {match.PremoveLimit} MOVES"
                : match.Phase == MatchPhase.Planning ? "NO TIME LIMIT / OPPONENT PLANNING" : "Their decision stays private.";
        if (GodotObject.IsInstanceValid(clock))
            clock.Text = match.Phase == MatchPhase.Planning ? "NO TIME LIMIT  /  PLAN"
                : match.Phase == MatchPhase.Foresight ? $"{Math.Ceiling(match.Seconds):000}s  /  FORESIGHT"
                : match.Phase == MatchPhase.Combat ? $"TICK {BattleEngine.getClock():00}" : match.MapName;
    }

    public override void _Input(InputEvent input)
    {
        if (input is not InputEventKey key || !key.Pressed || key.Echo) return;
        if (match.Phase == MatchPhase.Menu)
        {
            if (screen == "map")
            {
                if (key.Keycode == Key.Left) { int count = MapTable.getMaps().Length; mapIndex = (mapIndex + count - 1) % count; Refresh(); }
                else if (key.Keycode == Key.Right) { int count = MapTable.getMaps().Length; mapIndex = (mapIndex + 1) % count; Refresh(); }
                else if (key.Keycode is Key.KpAdd or Key.Equal or Key.Plus) { premoveLimit = Math.Min(10, premoveLimit + 1); Refresh(); }
                else if (key.Keycode is Key.KpSubtract or Key.Minus) { premoveLimit = Math.Max(5, premoveLimit - 1); Refresh(); }
                else if (key.Keycode is Key.Enter or Key.KpEnter) { board.Reset(); match.Start(solo, teamSize, mapIndex, premoveLimit); }
                else if (key.Keycode == Key.Escape) { screen = network.Active ? "lan" : "title"; Refresh(); }
                else return;
                GetViewport().SetInputAsHandled(); return;
            }
            return;
        }
        if (network.Active && !match.MyTurn && match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Finished) return;
        if (modalOpen || match.Paused || overlay.GetChildCount() > 0 && match.Phase != MatchPhase.Deploy && match.Phase != MatchPhase.Handoff && match.Phase != MatchPhase.Selection) return;
        if (match.Phase == MatchPhase.Deploy)
        {
            if (placementOpen)
            {
                if (key.Keycode == Key.W) match.CursorRow = Math.Max(0, match.CursorRow - 1);
                else if (key.Keycode == Key.S) match.CursorRow = Math.Min(14, match.CursorRow + 1);
                else if (key.Keycode == Key.A) match.CursorCol = Math.Max(0, match.CursorCol - 1);
                else if (key.Keycode == Key.D) match.CursorCol = Math.Min(12, match.CursorCol + 1);
                else if (key.Keycode is Key.Enter or Key.KpEnter) { if (match.PlaceAt(match.CursorRow, match.CursorCol)) placementOpen = false; }
                else if (key.Keycode == Key.Escape) placementOpen = false;
                else return;
                Refresh(); return;
            }
            if (key.Keycode == Key.Left) BrowseCharacter(-1);
            else if (key.Keycode == Key.Right) BrowseCharacter(1);
            else if (key.Keycode is Key.Enter or Key.KpEnter) { if (characterIndex < 3 && match.CanAdd) { BeginPlacement(); placementOpen = true; } }
            else if (key.Keycode == Key.Space) match.ConfirmDeployment();
            else if (key.Keycode == Key.Backspace) match.RemoveFighter(match.Rosters[match.Viewer - 1].Count - 1);
            else if (key.Keycode == Key.P) CyclePerk();
            else if (key.Keycode == Key.Escape) ReturnToMenu();
            else return;
        }
        else
        {
            if (match.Phase == MatchPhase.Selection && key.Keycode is Key.Left or Key.Right)
            {
                var available = match.Available(match.Viewer).ToArray();
                int index = Array.IndexOf(available, match.Fighter);
                match.Fighter = available[(index + (key.Keycode == Key.Left ? available.Length - 1 : 1)) % available.Length]; Refresh();
            }
            else if (key.Keycode == Key.Space) match.LockPlan();
            else if (key.Keycode == Key.Tab && match.Current != null) CyclePlannedFighter();
            else if (key.Keycode is Key.Left or Key.Right or Key.Up or Key.Down)
            { match.Direction = key.Keycode switch { Key.Up => 1, Key.Down => 2, Key.Left => 3, _ => 4 }; Refresh(); }
            else if (key.Keycode is Key.KpAdd or Key.Equal or Key.Plus) { match.StepRange(1); Refresh(); }
            else if (key.Keycode is Key.KpSubtract or Key.Minus) { match.StepRange(-1); Refresh(); }
            else _UnhandledKeyInput(input);
        }
        GetViewport().SetInputAsHandled();
    }

    public override void _UnhandledKeyInput(InputEvent input)
    {
        if (input is not InputEventKey key || !key.Pressed || key.Echo) return;
        if (key.Keycode == Key.Escape && rewindPopup) return;
        if (key.Keycode == Key.Escape && modalOpen) { modalOpen = false; match.Paused = false; Refresh(); return; }
        if (match.Phase == MatchPhase.Menu && key.Keycode == Key.Escape) { screen = "title"; match.Paused = false; Refresh(); return; }
        if (network.Active && !match.MyTurn && match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Finished) return;
        if (key.Keycode == Key.F11) { ToggleFullscreen(); return; }
        if (key.Keycode == Key.Escape)
        {
            if (match.Paused) { modalOpen = false; match.Paused = false; Refresh(); }
            else { match.Paused = !network.Active; ShowPause(); }
            return;
        }
        if (match.Paused) return;
        if (key.Keycode == Key.G) { board.TileView = !board.TileView; Refresh(); return; }
        if (key.Keycode is Key.Enter or Key.KpEnter)
        {
            if (match.Phase == MatchPhase.Handoff) match.ContinueHandoff();
            else if (match.Phase == MatchPhase.Selection) match.ConfirmFighter();
            else if (match.Phase == MatchPhase.Deploy) match.ConfirmDeployment();
            else if (match.Phase == MatchPhase.Planning || match.Phase == MatchPhase.Foresight) match.Edit(match.Action);
            return;
        }
        bool editing = match.Phase == MatchPhase.Planning || match.Phase == MatchPhase.Foresight;
        if (!editing && match.Phase != MatchPhase.Rewind) return;
        int direction = key.Keycode switch { Key.W => 1, Key.S => 2, Key.A => 3, Key.D => 4, _ => 0 };
        if (direction > 0) { match.Action = direction; if (editing) match.Direction = direction; Refresh(); return; }
        int skill = key.Keycode switch { Key.Key1 or Key.Kp1 => 1, Key.Key2 or Key.Kp2 => 2, Key.Key3 or Key.Kp3 => 3, Key.Key4 or Key.Kp4 => 4, Key.Key5 or Key.Kp5 => 5, _ => 0 };
        if (skill > 0 && skill <= MatchSession.SkillNames(match.Current.characterClass()).Length) { match.SelectSkill(skill); Refresh(); }
        if (key.Keycode == Key.T && match.Perks[match.Viewer - 1] == SuperPerk.Teleport) { match.Action = 5; Refresh(); }
        if (editing && key.Keycode is Key.Kp0 or Key.Key0) { match.Edit(0); return; }
        if (editing && key.Keycode == Key.Backspace) { match.Slot = Math.Max(0, match.Slot - 1); Refresh(); }
    }

    async System.Threading.Tasks.Task Capture(string path)
    {
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        GetViewport().GetTexture().GetImage().SavePng(path);
        GD.Print("Saved " + path);
    }

    async void RunVisualCheck()
    {
        await Capture("/tmp/premove-menu.png");
        screen = "map"; Refresh(); await Capture("/tmp/premove-map.png");
        teamSize = 2; solo = true; match.Start(true, 2);
        await Capture("/tmp/premove-characters.png");
        BrowseCharacter(2); await Capture("/tmp/premove-archer-select.png");
        BeginPlacement(); placementOpen = true; Refresh(); await Capture("/tmp/premove-archer-placement.png");
        placementOpen = false;
        match.Deploy(CharacterClass.ARCHER, 6, 5); match.Deploy(CharacterClass.MAGE, 6, 6);
        await Capture("/tmp/premove-deployment.png");
        match.ConfirmDeployment(); match.Edit(2); match.Edit(-1);
        match.Fighter = 1; match.Slot = 0; match.Range = 4; match.Direction = 2; match.Action = -3;
        Refresh();
        for (int frame = 0; frame < 30; frame++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await Capture("/tmp/premove-planning.png");
                board.TileView = true; Refresh(); await Capture("/tmp/premove-tiles.png"); board.TileView = false;
        match.Edit(-3); match.LockPlan();
        await Capture("/tmp/premove-selection.png");
        match.ConfirmFighter();
        for (int frame = 0; frame < 40; frame++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await Capture("/tmp/premove-combat.png");
        match.Paused = true;
        var gallery = FullScreen("KNIGHT / PERSPECTIVE POSES", 1200);
        var poses = new Control { CustomMinimumSize = new Vector2(1100, 500) }; gallery.AddChild(poses);
        for (int d = 1; d <= 4; d++) for (int a = 0; a < 3; a++)
        {
            var actor = new Node2D(); actor.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd")); poses.AddChild(actor);
            actor.Position = new Vector2(130 + (d - 1) * 280, 85 + a * 165); actor.Call("configure", 1); actor.Call("show_direction", d); actor.Call("fit_tile", 112f);
            var player = actor.Get("current").AsGodotObject(); player.Call("play", "knight_slash"); player.Call("set_process", false);
            player.Call("apply_pose", player.Call("sample", a == 0 ? 0.0 : a == 1 ? 0.27 : 0.48));
        }
        await Capture("/tmp/premove-knight-poses.png");
        var effectsPage = FullScreen("ATTACK PLAYBACK", 1200);
        var effectStage = new Control { CustomMinimumSize = new Vector2(1150, 500) }; effectsPage.AddChild(effectStage);
        foreach (var (kind, action, spot) in new[] {
            (0, -1, new Vector2(140, 120)), (0, -3, new Vector2(430, 120)),
            (1, -1, new Vector2(720, 120)), (1, -4, new Vector2(1010, 120)),
            (2, -1, new Vector2(140, 380)), (2, -2, new Vector2(430, 380)),
            (2, -3, new Vector2(720, 380)), (2, -4, new Vector2(1010, 380))
        })
        {
            var actor = new Node2D { ProcessMode = ProcessModeEnum.Always }; actor.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd")); effectStage.AddChild(actor);
            actor.Position = spot; actor.Call("configure", kind); actor.Call("fit_tile", 64f);
            actor.Call("perform", action, 4, spot, spot + new Vector2(170, 0), 1.3f);
        }
        await ToSignal(GetTree().CreateTimer(0.79), SceneTreeTimer.SignalName.Timeout);
        await Capture("/tmp/premove-attack-impact.png");
    }

    async void RunSmokeTest()
    {
        try
        {
            MatchChecks.Run();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            match.Start(true, 1); match.Deploy(CharacterClass.MAGE, 6, 6); match.ConfirmDeployment();
            MatchChecks.CheckSpriteScale(board);
            for (int i = 0; i < BattleEngine.getPlayer(1).getCharacter(0).stepCount(); i++) { match.Slot = i; match.Range = 5; match.Direction = 2; match.Edit(-1); }
            match.LockPlan(); match.ConfirmFighter();
            for (int i = 0; i < 20; i++)
            {
                match.Update(3);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                if (match.Phase != MatchPhase.Combat) break;
            }
            GD.Print("SMOKE: practice phase=" + match.Phase + " tick=" + BattleEngine.getClock());
            board.Reset();
            match.Start(false, 2);
            match.Deploy(CharacterClass.ARCHER, 6, 5); match.Deploy(CharacterClass.MAGE, 6, 6); match.ConfirmDeployment();
            match.ContinueHandoff(); match.Deploy(CharacterClass.WARRIOR, 9, 5); match.Deploy(CharacterClass.MAGE, 9, 6); match.ConfirmDeployment();
            match.ContinueHandoff(); match.Direction = 2; match.Range = 3; match.Edit(-1); match.LockPlan();
            match.ContinueHandoff(); match.Edit(0); match.LockPlan();
            match.ContinueHandoff(); match.ConfirmFighter(); match.ContinueHandoff(); match.ConfirmFighter();
            match.Update(3);
            if (match.Phase == MatchPhase.Rewind) match.Rewind(false);
            if (BattleEngine.getPlayer(2).getCharacter(0).currentHP() != 102)
                throw new InvalidOperationException("Archer smoke attack did not resolve.");
            for (int frame = 0; frame < 45; frame++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            GD.Print("SMOKE: local phase=" + match.Phase + " tick=" + BattleEngine.getClock());
            GD.Print("SMOKE PASS");
        }
        catch (Exception error) { GD.PushError("SMOKE FAIL: " + error); GetTree().Quit(1); return; }
        GetTree().Quit();
    }
}
