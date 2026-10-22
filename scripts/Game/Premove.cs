using Godot;
using System;
using System.Linq;

public partial class Premove : Control
{
    readonly MatchSession match = new();
    readonly Color ink = new("3a2a1b"), muted = new("6f573c"), gold = new("8a5a2b"), cyan = new("2f4f7a"), coral = new("a33b32");
    Control shell;
    Control keyOverlay;
    readonly int[] executing = { 0, 0 };
    string screen = "title";
    int characterIndex, tutorialPage;
    readonly string[] characterNames = { "Knight", "Mage", "Archer", "Orc" };
    Node2D showcase;
    Label lastMove;
    string moveText = "";
    NetworkMatch network;
    bool Choosing => match.Phase == MatchPhase.Menu;
    BattleBoard board;
    VBoxContainer left, right, footer;
    HBoxContainer header;
    Control overlay, popup;
    bool placementOpen;
    readonly System.Collections.Generic.Dictionary<int, Node2D> showcaseCache = new();
    Node2D showcaseHolder;
    Label clock, tileInfo;
    bool solo = true, modalOpen;
    int teamSize = 1, mapIndex;
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
        for (int kind = 0; kind < 2; kind++) { var figure = BuildFigure(kind); figure.Visible = false; showcaseHolder.AddChild(figure); showcaseCache[kind] = figure; }
        network = new NetworkMatch { Name = "Network", Session = match }; AddChild(network);
        network.StatusChanged += status => { transient = status; if (match.Phase == MatchPhase.Menu) Refresh(); };
        network.ConnectionLost += () => { ReturnToMenu(); transient = "Connection closed. Host or join again."; screen = "lan"; Refresh(); };
        match.Changed += Refresh;
        match.TickPlayed += (before, after) => { board.PlayTick(before, after); ShowLastMoves(before); };
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
        theme.SetColor("font_hover_color", "Button", Colors.White);
        theme.SetColor("font_disabled_color", "Button", new Color("8a7a63"));
        theme.SetStylebox("normal", "Button", Box("e6cfa8", "8a6a45", 0));
        theme.SetStylebox("hover", "Button", Box("f4e3c2", "8a5a2b", 0));
        theme.SetStylebox("pressed", "Button", Box("d8bb8d", "8a5a2b", 7));
        var focus = Box("00000000", "2f4f7a", 0);
        focus.ShadowSize = 0;
        theme.SetStylebox("focus", "Button", focus);
        theme.SetStylebox("disabled", "Button", Box("cbb492", "a08a6b", 7));
        theme.SetConstant("outline_size", "Label", 2);
        theme.SetColor("font_outline_color", "Label", new Color("e8d0a6"));
        theme.SetConstant("separation", "VBoxContainer", 10);
        theme.SetConstant("separation", "HBoxContainer", 10);
        return theme;
    }

    StyleBoxFlat Box(string fill, string border, int radius = 10)
    {
        return new StyleBoxFlat {
            BgColor = new Color(fill),
            CornerRadiusTopLeft = 0, CornerRadiusTopRight = 0, CornerRadiusBottomLeft = 0, CornerRadiusBottomRight = 0,
            BorderWidthLeft = 3, BorderWidthTop = 3, BorderWidthRight = 3, BorderWidthBottom = 3,
            BorderColor = new Color(border).Lightened(0.12f),
            BorderBlend = false, ShadowColor = new Color("6b4f2e"), ShadowSize = 3, ShadowOffset = new Vector2(3, 3),
            ContentMarginLeft = 15, ContentMarginRight = 15, ContentMarginTop = 12, ContentMarginBottom = 12
        };
    }

    void BuildShell()
    {
        var backdrop = new ColorRect { Color = new Color("d9b98c"), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(backdrop); backdrop.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var margin = new MarginContainer(); shell = margin; AddChild(margin); margin.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        foreach (string side in new[] { "left", "right", "top", "bottom" }) margin.AddThemeConstantOverride("margin_" + side, 24);
        var root = new VBoxContainer(); margin.AddChild(root);
        header = new HBoxContainer { CustomMinimumSize = new Vector2(0, 54) }; root.AddChild(header);
        var body = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill }; root.AddChild(body);
        var leftScroll = new ScrollContainer { CustomMinimumSize = new Vector2(0, 0), HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled };
        body.AddChild(leftScroll); leftScroll.Visible = false;
        left = new VBoxContainer { CustomMinimumSize = new Vector2(0, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill }; leftScroll.AddChild(left);
        var center = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        var centerMargin = new MarginContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        centerMargin.AddThemeConstantOverride("margin_right", 272);
        centerMargin.AddChild(center); body.AddChild(centerMargin);
        var boardPanel = new PanelContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        boardPanel.AddThemeStyleboxOverride("panel", Box("c19a6b", "8a6a45", 0)); center.AddChild(boardPanel);
        board = new BattleBoard { Session = match, CustomMinimumSize = new Vector2(380, 420), SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill };
        boardPanel.AddChild(board);
        board.TileClicked += OnTile;
        tileInfo = Label("ARENA   /   G: TILE VIEW", 12, muted); center.AddChild(tileInfo);
        board.TileHovered += text => tileInfo.Text = text == "" ? "ARENA   /   G: TILE VIEW" : text;
        var keyPanel = new PanelContainer { MouseFilter = MouseFilterEnum.Ignore };
        keyPanel.AddThemeStyleboxOverride("panel", Box("c19a6be6", "2f4f7a66", 0));
        keyOverlay = keyPanel; AddChild(keyPanel); keyPanel.SetAnchorsAndOffsetsPreset(LayoutPreset.TopRight);
        keyPanel.OffsetLeft = -292; keyPanel.OffsetRight = -24; keyPanel.OffsetTop = 104; keyPanel.OffsetBottom = 690;
        var rightScroll = new ScrollContainer { HorizontalScrollMode = ScrollContainer.ScrollMode.Disabled, SizeFlagsVertical = SizeFlags.ExpandFill };
        keyPanel.AddChild(rightScroll);
        right = new VBoxContainer { CustomMinimumSize = new Vector2(232, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill }; rightScroll.AddChild(right);
        footer = new VBoxContainer { CustomMinimumSize = new Vector2(0, 115) }; root.AddChild(footer);
        overlay = new Control { MouseFilter = MouseFilterEnum.Ignore }; AddChild(overlay); overlay.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
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

    Button Button(string text, System.Action action, bool disabled = false, bool accent = false)
    {
        var b = new Button { Text = text, Disabled = disabled, CustomMinimumSize = new Vector2(0, 42), MouseDefaultCursorShape = CursorShape.PointingHand };
        b.AddThemeFontSizeOverride("font_size", 24);
        if (accent) { b.AddThemeStyleboxOverride("normal", Box("e8c48c", "8a5a2b", 0)); b.AddThemeColorOverride("font_color", cyan); }
        b.Pressed += () => { transient = ""; action(); };
        return b;
    }

    static void Clear(Node node)
    {
        foreach (Node child in node.GetChildren()) { node.RemoveChild(child); child.QueueFree(); }
    }

    VBoxContainer Card(VBoxContainer parent, string eyebrow)
    {
        var panel = new PanelContainer(); panel.AddThemeStyleboxOverride("panel", Box("c19a6bb0", "2f4f7a66")); parent.AddChild(panel);
        var content = new VBoxContainer(); panel.AddChild(content);
        if (eyebrow.Length > 0) content.AddChild(Label(eyebrow, 11, muted));
        return content;
    }

    Node2D BuildFigure(int kind)
    {
        var figure = new Node2D { ProcessMode = ProcessModeEnum.Always };
        figure.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd"));
        figure.Call("configure", kind);
        figure.Call("fit_tile", 192f);
        return figure;
    }

    void Refresh()
    {
        if (modalOpen) return;
        foreach (var figure in showcaseCache.Values) { if (figure.GetParent() != showcaseHolder) showcaseHolder.AddChild(figure); figure.Visible = false; }
        Clear(left); Clear(right); Clear(header); Clear(footer); Clear(overlay); Clear(popup);
        shell.Visible = !Choosing;
        keyOverlay.Visible = !Choosing;
        showcase = null;
        if (network != null && network.Active && !match.MyTurn && match.Phase != MatchPhase.Menu && match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Finished)
        {
            shell.Visible = false; keyOverlay.Visible = false;
            var wait = FullScreen("OPPONENT'S TURN");
            wait.AddChild(Label("Their choice stays private.", 24, cyan));
            wait.AddChild(Button("Leave match", ReturnToMenu)); FocusFirst(wait);
            board.Visible = false;
            return;
        }
        board.Visible = true;
        board.CursorRow = match.Phase == MatchPhase.Deploy ? match.CursorRow : -1;
        board.CursorCol = match.Phase == MatchPhase.Deploy ? match.CursorCol : -1;
        header.AddChild(Label("PREMOVE", 24, gold));
        header.AddChild(new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill });
        clock = Label("", 24, cyan); header.AddChild(clock);
        clock.MouseFilter = MouseFilterEnum.Stop;
        clock.TooltipText = "Plan before the timer expires. Both parties execute their sequences together.";
        if (match.Phase != MatchPhase.Menu && match.Phase != MatchPhase.Deploy && match.Phase != MatchPhase.Handoff)
        {
            for (int p = 0; p < 2; p++)
            {
                var hp = string.Join("  ", Enumerable.Range(0, match.TeamSize).Select(i => {
                    var unit = BattleEngine.getPlayer((uint)p + 1).getCharacter(i);
                    return $"{MatchSession.ClassName(unit.characterClass())} {board.DisplayHP(p, i)} HP";
                }));
                int total = Enumerable.Range(0, match.TeamSize).Sum(i => board.DisplayHP(p, i));
                var stats = Label($"P{p + 1}  {total} HP", 24, p == 0 ? cyan : coral);
                stats.MouseFilter = MouseFilterEnum.Stop;
                stats.TooltipText = hp + "\nDefeat every enemy fighter. Health persists; cooldowns reset each cycle.";
                header.AddChild(stats);
            }
        }
        if (match.Phase == MatchPhase.Menu) Menu();
        else if (match.Phase == MatchPhase.Handoff) Handoff();
        else if (match.Phase == MatchPhase.Deploy) CharacterScreen();
        else Battle();
        if (match.Phase == MatchPhase.Combat || match.Phase == MatchPhase.Rewind)
        {
            var feedback = new PanelContainer(); feedback.AddThemeStyleboxOverride("panel", Box("c19a6b99", "8a5a2b")); footer.AddChild(feedback);
            lastMove = Label(moveText, 24, gold); feedback.AddChild(lastMove);
        }
        if (match.Phase != MatchPhase.Combat && match.Phase != MatchPhase.Rewind) board.Sync();
        if (placementOpen) BuildPlacementPopup();
        if (match.Phase == MatchPhase.Menu) board.Sync();
    }

    VBoxContainer FullScreen(string title)
    {
        Clear(overlay); shell.Visible = false; keyOverlay.Visible = false;
        var background = new ColorRect { Color = new Color("d9b98c") }; overlay.AddChild(background); background.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer(); overlay.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(600, 0) }; center.AddChild(content);
        content.AddThemeConstantOverride("separation", 18);
        if (title != "") { var heading = Label(title, 40, gold); heading.HorizontalAlignment = HorizontalAlignment.Center; content.AddChild(heading); }
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
        var page = FullScreen(screen == "title" ? "" : screen == "lan" ? "LOCAL NETWORK" : "CHOOSE YOUR MAP");
        if (screen == "title")
        {
            var title = new CenterContainer(); page.AddChild(title);
            title.AddChild(new PixelTitle { Caption = "PREMOVE", PixelScale = 12, Ink = cyan, CustomMinimumSize = new Vector2(510, 100) });
            var tagline = Label("Think ahead. Move together.", 24, coral); tagline.HorizontalAlignment = HorizontalAlignment.Center; page.AddChild(tagline);
            page.AddChild(new Control { CustomMinimumSize = new Vector2(0, 50) });
            page.AddChild(Button("LAN MULTIPLAYER", () => { screen = "lan"; Refresh(); }, accent: true));
            page.AddChild(Button("Couch multiplayer", () => { solo = false; screen = "map"; Refresh(); }));
            page.AddChild(Button("Practice", () => { solo = true; screen = "map"; Refresh(); }));
            page.AddChild(Button("Small tutorial", () => { tutorialPage = 0; ShowHelp(); }));
            page.AddChild(Button("Quit", () => GetTree().Quit()));
        }
        else if (screen == "lan")
        {
            page.AddChild(Label("Two computers. One local network.", 24, cyan));
            page.AddChild(Button("Host game", () => { var error = network.Host(); transient = error == Error.Ok ? "Waiting for player two..." : error.ToString(); Refresh(); }));
            var address = new LineEdit { PlaceholderText = "Host IP address", Text = network.Address, CustomMinimumSize = new Vector2(0, 48) }; page.AddChild(address);
            address.TextChanged += value => network.Address = value;
            page.AddChild(Button("Join game", () => { var error = network.Join(); transient = error == Error.Ok ? "Connecting..." : error.ToString(); Refresh(); }));
            page.AddChild(Text(transient, 16, coral));
            if (network.CanStart) page.AddChild(Text("Host IP: " + string.Join(", ", IP.GetLocalAddresses().Where(ip => ip.Contains('.') && !ip.StartsWith("127."))), 16, cyan));
            page.AddChild(Button("Choose map", () => { solo = false; screen = "map"; Refresh(); }, !network.CanStart, true));
            page.AddChild(Button("Back", () => { network.Close(); screen = "title"; Refresh(); }));
        }
        else
        {
            var maps = new[] { "Grassland_1", "Grassland_2", "Grassland_3", "Volcanic_Ruins_1", "Volcanic_Ruins_2", "Volcanic_Ruins_3" };
            
            var container = new CenterContainer(); page.AddChild(container);
            var mainVBox = new VBoxContainer { CustomMinimumSize = new Vector2(800, 0) }; container.AddChild(mainVBox);
            
            // Large map preview area - constructed from tile textures
            var previewHolder = new PanelContainer { CustomMinimumSize = new Vector2(700, 400) };
            previewHolder.AddThemeStyleboxOverride("panel", Box("c19a6b", "8a5a2b", 0));
            var previewControl = new MapPreview { MapIndex = mapIndex, CustomMinimumSize = new Vector2(680, 380) };
            previewHolder.AddChild(previewControl);
            mainVBox.AddChild(previewHolder);
            
            // Map name
            var mapName = Label(maps[mapIndex].Replace("_", " "), 28, cyan); 
            mapName.HorizontalAlignment = HorizontalAlignment.Center; 
            mainVBox.AddChild(mapName);
            
            // Visible arrow buttons for navigation
            var nav = new HBoxContainer(); mainVBox.AddChild(nav);
            nav.AddChild(new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill });
            nav.AddChild(Button("← Prev", () => { mapIndex = (mapIndex + 5) % 6; Refresh(); }));
            var nameLabel = Label(maps[mapIndex].Replace("_", " "), 28, cyan); nameLabel.HorizontalAlignment = HorizontalAlignment.Center; nav.AddChild(nameLabel);
            nav.AddChild(Button("Next →", () => { mapIndex = (mapIndex + 1) % 6; Refresh(); }));
            
            // Party size and start
            var controls = new HBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; mainVBox.AddChild(controls);
            controls.AddChild(new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill });
            controls.AddChild(Button($"Party size: {teamSize}  ·  change", () => { teamSize = teamSize % 3 + 1; Refresh(); }));
            var startBtn = Button("Choose characters", () => { board.Reset(); match.Start(solo, teamSize, mapIndex); }, accent: true);
            controls.AddChild(startBtn);
            controls.AddChild(Button("Back", () => { screen = network.Active ? "lan" : "title"; Refresh(); }));
            
            // Ensure start button gets focus
            FocusFirst(startBtn);
        }
        page.AddChild(Label("↑ ↓  SELECT     ENTER  CONFIRM     ESC  BACK", 16, muted));
        FocusFirst(page);
    }

    void CharacterScreen()
    {
        teamSize = match.TeamSize; solo = match.Solo;
        var page = FullScreen($"PLAYER {match.Viewer}  /  CHOOSE YOUR PARTY");
        var stage = new Control { CustomMinimumSize = new Vector2(600, 290), MouseFilter = MouseFilterEnum.Ignore }; page.AddChild(stage);
        if (characterIndex < 2)
        {
            showcase = showcaseCache[characterIndex == 0 ? 1 : 0];
            float xPos = Size.X / 2 + (characterIndex == 1 ? -20f : 0f); // Mage slightly left
            showcase.Position = new Vector2(xPos, Size.Y * 0.35f);
            showcase.Visible = true;
            showcase.Modulate = new Color(1,1,1,1);
            showcase.Call("fit_tile", 192f);
        }
        else if (characterIndex == 2)
        {
            var art = new TextureRect { Texture = GD.Load<Texture2D>("res://assets/sprites/archer_portrait.png"), Position = new Vector2(204, 60), Size = new Vector2(192, 192), TextureFilter = TextureFilterEnum.Nearest, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, Modulate = new Color("6f573c") }; stage.AddChild(art);
        }
        else { var unknown = Label("?", 128, muted); unknown.Position = new Vector2(265, 80); stage.AddChild(unknown); }
        var arrows = new HBoxContainer(); page.AddChild(arrows);
        arrows.AddChild(Button("←", () => BrowseCharacter(-1)));
        var name = Label(characterNames[characterIndex].ToUpperInvariant(), 32, characterIndex == 0 ? coral : cyan); name.SizeFlagsHorizontal = SizeFlags.ExpandFill; name.HorizontalAlignment = HorizontalAlignment.Center; arrows.AddChild(name);
        arrows.AddChild(Button("→", () => BrowseCharacter(1)));
        var description = Label(characterIndex switch { 0 => "120 HP  /  Close-range swordplay", 1 => "75 HP  /  Ranged magic", _ => "COMING SOON  /  More animation assets needed" }, 16, muted); description.HorizontalAlignment = HorizontalAlignment.Center; page.AddChild(description);
        var add = Button(characterIndex > 1 ? "Coming soon" : "Place on the map  [Enter]", () => { BeginPlacement(); placementOpen = true; Refresh(); }, characterIndex > 1 || !match.CanAdd, true);
        page.AddChild(add);
        page.AddChild(Label("The map opens when you place a fighter. Only safe tiles in your half can be used.", 13, muted));
        var perkIndex = (int)match.Perks[match.Viewer - 1];
        var perk = Button(perkIndex < 0 ? "Perk: choose  [P]" : $"Perk: {MatchSession.PerkNames[perkIndex]}  [P]", CyclePerk, !match.PerkTurn);
        perk.TooltipText = perkIndex < 0 ? "One perk per team. It changes how the round is played." : MatchSession.PerkDetails[perkIndex];
        page.AddChild(perk);
        if (!match.PerkTurn) page.AddChild(Label($"Waiting for player {match.PerkOrder} to pick a perk first", 13, muted));
        page.AddChild(Button("Enter arena  [Space]", match.ConfirmDeployment, match.Rosters[match.Viewer - 1].Count != teamSize || (match.Lan && perkIndex < 0)));
        var party = new HBoxContainer { Position = new Vector2(Size.X - 520, Size.Y - 140), CustomMinimumSize = new Vector2(500, 100) }; overlay.AddChild(party);
        var partyLabel = new VBoxContainer(); partyLabel.AddChild(Label($"PARTY  {match.Rosters[match.Viewer - 1].Count}/{teamSize}", 24, gold)); party.AddChild(partyLabel);
        for (int i = 0; i < match.Rosters[match.Viewer - 1].Count; i++)
        {
            var at = match.Spawns[match.Viewer - 1][i];
            var kind = match.Rosters[match.Viewer - 1][i];
            var fighterBox = new VBoxContainer();
            PortraitRow(fighterBox, MatchSession.ClassName(kind), $"TILE {at.y + 1:00} / {at.x + 1:00}", kind == CharacterClass.MAGE ? "mage" : "knight", false);
            int index = i;
            fighterBox.AddChild(Button("Remove", () => { match.RemoveFighter(index); Refresh(); }));
            party.AddChild(fighterBox);
        }
        page.AddChild(Label("← →  BROWSE    ENTER  ADD    BACKSPACE  REMOVE", 16, muted));
        if (transient.Length > 0) page.AddChild(Text(transient, 16, coral));
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
        if (characterIndex > 1) return;
        match.SelectClass(characterIndex == 0 ? CharacterClass.WARRIOR : CharacterClass.MAGE);
        transient = match.Message;
        if (GodotObject.IsInstanceValid(showcase)) showcase.Call("perform", -1, 2, showcase.Position, showcase.Position + new Vector2(100, 0), 1.0f);
        Refresh();
    }

    VBoxContainer OpenPopup(string title)
    {
        Clear(popup);
        var shade = new ColorRect { Color = new Color(0.05f, 0.04f, 0.02f, 0.85f) }; popup.AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer(); popup.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = new PanelContainer(); center.AddChild(panel); panel.AddThemeStyleboxOverride("panel", Box("c19a6b", "8a5a2b", 0));
        var content = new VBoxContainer(); panel.AddChild(content);
        content.AddChild(Label(title, 24, gold));
        return content;
    }

    void BuildPlacementPopup()
    {
        // Hide showcase during placement
        if (GodotObject.IsInstanceValid(showcase)) showcase.Visible = false;
        var content = OpenPopup($"PLACE YOUR {MatchSession.ClassName((CharacterClass)match.SelectedClass).ToUpperInvariant()}");
        var map = new PlacementMap { Session = match, CursorRow = match.CursorRow, CursorCol = match.CursorCol, MapIndex = mapIndex };
        map.TilePicked += (row, col) => { match.PlaceAt(row, col); ClosePlacementPopup(); };
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
        var portrait = new TextureRect { Texture = GD.Load<Texture2D>($"res://assets/sprites/{asset}_portrait.png"), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, CustomMinimumSize = new Vector2(42, 48), TextureFilter = TextureFilterEnum.Nearest, Modulate = dim ? new Color(0.6f, 0.65f, 0.7f) : Colors.White };
        row.AddChild(portrait);
        var captions = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill }; row.AddChild(captions);
        captions.AddChild(Label(name, 17, dim ? muted : ink)); captions.AddChild(Text(description, 12, muted));
    }

    void Handoff()
    {
        var panel = FullScreen($"PLAYER {match.Viewer}");
        panel.AddChild(Label(match.HandoffText, 24, cyan));
        if (!network.Active) panel.AddChild(Text("Pass the keyboard. Your choices stay private.", 24, muted));
        panel.AddChild(Button("Ready  [Enter]", match.ContinueHandoff, accent: true));
        FocusFirst(panel);
    }

    void Battle()
    {
        bool planning = match.Phase is MatchPhase.Planning or MatchPhase.Foresight;
        if (match.Phase == MatchPhase.Selection)
        {
            var page = FullScreen($"PLAYER {match.Viewer}  /  NEXT FIGHTER");
            var stage = new Control { CustomMinimumSize = new Vector2(600, 280) }; page.AddChild(stage);
            var actor = new Node2D(); actor.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd")); stage.AddChild(actor);
            actor.Position = new Vector2(300, 150); actor.Call("configure", (int)match.Current.characterClass()); actor.Call("fit_tile", 192f);
            page.AddChild(Label($"<  {MatchSession.ClassName(match.Current.characterClass()).ToUpperInvariant()}  >", 32, cyan));
            page.AddChild(Label($"{match.Current.currentHP()} HP   ·   READY", 24, gold));
            page.AddChild(Button("Choose fighter  [Enter]", match.ConfirmFighter, accent: true));
            page.AddChild(Label("← →  CHOOSE     ENTER  CONFIRM", 16, muted));
            FocusFirst(page); return;
        }
        if (match.Phase == MatchPhase.Finished)
        {
            var page = FullScreen(match.Message.ToUpperInvariant());
            page.AddChild(Button("Rematch", () => { board.Reset(); match.Start(solo, teamSize); }, network.Active && !network.CanStart, true));
            page.AddChild(Button("Main menu", ReturnToMenu)); FocusFirst(page); return;
        }
        if (planning || match.Phase == MatchPhase.Rewind) ActionPanel();
        if (planning)
        {
            var next = Button($"{MatchSession.ClassName(match.Current.characterClass())}  [Tab]", () => { match.Fighter = (match.Fighter + 1) % match.TeamSize; match.Slot = 0; Refresh(); }); right.AddChild(next);
            next.TooltipText = "Write a sequence for every fighter before locking your party's plans.";
            right.AddChild(Button("Lock plans  [Space]", match.LockPlan, accent: true));
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
            right.AddChild(Button("Attempt rewind", () => match.Rewind(true), accent: true));
            right.AddChild(Button("Keep this tick", () => match.Rewind(false)));
        }
        else if (match.Phase == MatchPhase.Combat) CombatKeys();
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
                if (active) { panel.Modulate = new Color(1.4f, 1.4f, 1.4f); panel.CreateTween().TweenProperty(panel, "modulate", Colors.White, 0.8); }
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
            if (active == action) { cap.Modulate = new Color(1.4f, 1.4f, 1.4f); cap.CreateTween().TweenProperty(cap, "modulate", Colors.White, 0.8); }
        }
    }

    void ActionPanel()
    {
        Character unit = match.Current;
        if (unit == null) return;
        bool rewind = match.Phase == MatchPhase.Rewind;
        var actions = new VBoxContainer(); right.AddChild(actions);
        string[] names = MatchSession.SkillNames(unit.characterClass());
        string[] details = MatchSession.SkillDetails(unit.characterClass());
        int[] cooldown = PlanningCooldowns(unit);
        var pad = new GridContainer { Columns = 3 }; actions.AddChild(pad);
        foreach (int number in new[] { 7, 8, 9, 4, 5, 6, 1, 2, 3 })
        {
            int skill = -number;
            bool exists = number <= names.Length;
            string caption = exists ? $"{number}\n{names[number - 1].Replace("Energy barrier", "Barrier").Replace("Meteorite", "Meteor").Replace("Quad beam", "Beam").Replace("Knight's Edge", "Edge")}\n{(cooldown[number - 1] > 0 ? "CD " + cooldown[number - 1] : "READY")}" : number.ToString();
            var key = Button(caption, () => { if (exists) match.SelectSkill(number); Refresh(); }, !exists, match.Action == skill);
            key.AddThemeFontSizeOverride("font_size", 16);
            key.CustomMinimumSize = new Vector2(65, 76); key.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            var cap = Box(match.Action == skill ? "f4e3c2" : "e6cfa8", match.Action == skill ? "8a5a2b" : "8a6a45aa");
            cap.ContentMarginLeft = cap.ContentMarginRight = 4;
            key.AddThemeStyleboxOverride("normal", cap); key.AddThemeStyleboxOverride("disabled", cap);
            if (exists) key.TooltipText = details[number - 1];
            pad.AddChild(key);
        }
        MovementKeys(actions, match.Action);
        if (match.Action < 0 || match.Action == 5 || rewind)
        {
            actions.TooltipText = match.Action < 0 ? details[-match.Action - 1] : "Choose a safe teleport destination.";
            actions.AddChild(Label($"Aim {new[] { "", "↑", "↓", "←", "→" }[match.Direction]}   Range {match.Range}", 24, cyan));
            actions.AddChild(Label("ARROWS aim   +/- range", 16, muted));
            if (!rewind) actions.AddChild(Label("ENTER add · NUM 0 end", 16, gold));
        }
    }

    int[] PlanningCooldowns(Character unit)
    {
        if (match.Phase == MatchPhase.Rewind) return unit.currentCooldown().Select(c => Math.Max(0, c - 1)).ToArray();
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
        var heading = new HBoxContainer(); footer.AddChild(heading);
        heading.AddChild(Label($"{MatchSession.ClassName(unit.characterClass()).ToUpperInvariant()} / ACTION SEQUENCE", 12, cyan));
        heading.AddChild(new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill });
        heading.AddChild(Label("WASD move · NUMPAD skill · ARROWS aim · ENTER add · SPACE lock", 12, muted));
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
        footer.AddChild(Label(transient.Length > 0 ? transient : match.Message.Length > 0 ? match.Message : "Click a slot to replace it. Skills on cooldown will be skipped in combat.", 12, muted));
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
        if (dr != 0 && dc != 0) { transient = "Aim along a row or column. Quad beam and guard target automatically."; Refresh(); return; }
        if (dr == 0 && dc == 0) return;
        match.Direction = dr == 0 ? dc < 0 ? 3 : 4 : dr < 0 ? 1 : 2;
        match.Range = Math.Abs(dr + dc); Refresh();
    }

    VBoxContainer Modal()
    {
        Clear(popup);
        var shade = new ColorRect { Color = new Color(0.02f, 0.05f, 0.08f, 0.92f) }; popup.AddChild(shade); shade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var center = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore }; popup.AddChild(center); center.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var panel = new PanelContainer { CustomMinimumSize = new Vector2(530, 0) }; center.AddChild(panel); panel.AddThemeStyleboxOverride("panel", Box("c19a6b", "8a5a2b", 0));
        var content = new VBoxContainer { CustomMinimumSize = new Vector2(490, 0) }; panel.AddChild(content);
        return content;
    }

    void ShowHelp()
    {
        modalOpen = true;
        match.Paused = !network.Active;
        var panel = Modal();
        string[] titles = { "1 / 3  ·  THINK AHEAD", "2 / 3  ·  PICK A SKILL", "3 / 3  ·  MOVE TOGETHER" };
        string[] tips = { "WASD writes moves into your sequence.\nBackspace returns to the previous slot.", "Numpad 1–5 chooses a skill. Arrows aim.\n+ / - changes range. Enter adds it to your plan.", "Space locks your plan. Pick a fighter, then Enter.\nBoth sides act together. Defeat the enemy party!" };
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
        panel.AddChild(Button("Small tutorial", () => { tutorialPage = 0; ShowHelp(); }));
        panel.AddChild(Button(board.TrackCamera ? "Camera: follow fighters" : "Camera: whole map", () => { board.TrackCamera = !board.TrackCamera; ShowPause(); }));
        panel.AddChild(Button("Fullscreen / windowed", ToggleFullscreen));
        panel.AddChild(Button("Return to menu", ReturnToMenu));
        FocusFirst(panel);
    }

    void ReturnToMenu()
    {
        network?.Close(); modalOpen = false; screen = "title"; match.Paused = false; match.Phase = MatchPhase.Menu; board.Reset(); Refresh();
    }
    void ToggleFullscreen() => DisplayServer.WindowSetMode(DisplayServer.WindowGetMode() == DisplayServer.WindowMode.Fullscreen ? DisplayServer.WindowMode.Windowed : DisplayServer.WindowMode.Fullscreen);
    public override void _Process(double delta)
    {
        GetTree().Paused = match.Paused;
        if (network.Active && !match.Lan)
        {
            match.Lan = true; match.Local = network.LocalPlayer; match.Viewer = match.Local;
            solo = false;
        }
        network.Advance(delta);
        if (GodotObject.IsInstanceValid(clock))
            clock.Text = match.Phase == MatchPhase.Planning || match.Phase == MatchPhase.Foresight ? $"{Math.Ceiling(match.Seconds):000}s  /  PLAN" : match.Phase == MatchPhase.Combat ? $"TICK {BattleEngine.getClock():00}" : "SKY ISLAND";
    }

    public override void _Input(InputEvent input)
    {
        if (input is not InputEventKey key || !key.Pressed || key.Echo) return;
        if (match.Phase == MatchPhase.Menu)
        {
            if (screen == "map")
            {
                if (key.Keycode == Key.Left) { mapIndex = (mapIndex + 5) % 6; Refresh(); }
                else if (key.Keycode == Key.Right) { mapIndex = (mapIndex + 1) % 6; Refresh(); }
                else if (key.Keycode is Key.Enter or Key.KpEnter) { board.Reset(); match.Start(solo, teamSize, mapIndex); }
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
                else if (key.Keycode is Key.Enter or Key.KpEnter) { match.PlaceAt(match.CursorRow, match.CursorCol); placementOpen = false; }
                else if (key.Keycode == Key.Escape) placementOpen = false;
                else return;
                Refresh(); return;
            }
            if (key.Keycode == Key.Left) BrowseCharacter(-1);
            else if (key.Keycode == Key.Right) BrowseCharacter(1);
            else if (key.Keycode is Key.Enter or Key.KpEnter) { BeginPlacement(); placementOpen = true; }
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
            else if (key.Keycode == Key.Tab && match.Current != null) { match.Fighter = (match.Fighter + 1) % match.TeamSize; match.Slot = 0; Refresh(); }
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
        match.Deploy(CharacterClass.WARRIOR, 6, 5); match.Deploy(CharacterClass.MAGE, 6, 6);
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
        var gallery = FullScreen("KNIGHT / PERSPECTIVE POSES");
        var poses = new Control { CustomMinimumSize = new Vector2(1100, 500) }; gallery.AddChild(poses);
        for (int d = 1; d <= 4; d++) for (int a = 0; a < 3; a++)
        {
            var actor = new Node2D(); actor.SetScript(GD.Load<GDScript>("res://scripts/Game/FighterVisual.gd")); poses.AddChild(actor);
            actor.Position = new Vector2(130 + (d - 1) * 280, 85 + a * 165); actor.Call("configure", 1); actor.Call("show_direction", d); actor.Call("fit_tile", 112f);
            var player = actor.Get("current").AsGodotObject(); player.Call("play", "knight_slash"); player.Call("set_process", false);
            player.Call("apply_pose", player.Call("sample", a == 0 ? 0.0 : a == 1 ? 0.27 : 0.48));
        }
        await Capture("/tmp/premove-knight-poses.png");
        var effectsPage = FullScreen("ATTACK PLAYBACK");
        var effectStage = new Control { CustomMinimumSize = new Vector2(1050, 480) }; effectsPage.AddChild(effectStage);
        foreach (var (kind, action, spot) in new[] { (0, -1, new Vector2(150, 120)), (0, -3, new Vector2(150, 340)), (1, -1, new Vector2(650, 120)), (1, -4, new Vector2(650, 340)) })
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
            for (int i = 0; i < 10; i++) { match.Slot = i; match.Range = 5; match.Direction = 2; match.Edit(-1); }
            match.LockPlan(); match.ConfirmFighter();
            for (int i = 0; i < 20; i++)
            {
                match.Update(3);
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                if (match.Phase != MatchPhase.Combat) break;
            }
            GD.Print("SMOKE: practice phase=" + match.Phase + " tick=" + BattleEngine.getClock());
            match.Start(false, 2);
            match.Deploy(CharacterClass.WARRIOR, 6, 5); match.Deploy(CharacterClass.MAGE, 6, 6); match.ConfirmDeployment();
            match.ContinueHandoff(); match.Deploy(CharacterClass.WARRIOR, 9, 5); match.Deploy(CharacterClass.MAGE, 9, 6); match.ConfirmDeployment();
            match.ContinueHandoff(); match.Edit(2); match.LockPlan(); match.ContinueHandoff(); match.Edit(1); match.LockPlan();
            match.ContinueHandoff(); match.ConfirmFighter(); match.ContinueHandoff(); match.ConfirmFighter();
            match.Update(3);
            if (match.Phase == MatchPhase.Rewind) match.Rewind(false);
            GD.Print("SMOKE: local phase=" + match.Phase + " tick=" + BattleEngine.getClock());
            GD.Print("SMOKE PASS");
        }
        catch (Exception error) { GD.PushError("SMOKE FAIL: " + error); GetTree().Quit(1); return; }
        GetTree().Quit();
    }
}
