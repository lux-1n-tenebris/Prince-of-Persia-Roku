' ********************************************************************************************************
' ********************************************************************************************************
' **  Roku Prince of Persia Channel - http://github.com/lvcabral/Prince-of-Persia-Roku
' **
' **  Created: February 2016
' **  Updated: September 2019
' **
' **  Ported to Brighscript by Marcelo Lv Cabral from the Git projects:
' **  https://github.com/ultrabolido/PrinceJS - HTML5 version by Ultrabolido
' **  https://github.com/jmechner/Prince-of-Persia-Apple-II - Original Apple II version by Jordan Mechner
' **
' ********************************************************************************************************
' ********************************************************************************************************
Library "v30/bslDefender.brs"

Sub Main()
    'Constants
    m.code = bslUniversalControlEventCodes()
    m.const = GetConstants()
    m.colors = { red: &hAA0000FF, green:&h00AA00FF, yellow: &hFFFF55FF, black: &hFF, white: &hFFFFFFFF, gray: &h404040FF, navy: &h080030FF, darkred: &h810000FF }
    m.maxLevels = 14
    'Util objects
    m.theme = GetTheme()
    m.port = CreateObject("roMessagePort")
    m.clock = CreateObject("roTimespan")
    m.timer = CreateObject("roTimespan")
    m.audioPlayer = CreateObject("roAudioPlayer")
    m.audioPort = CreateObject("roMessagePort")
    m.audioPlayer.SetMessagePort(m.audioPort)
    m.sounds = LoadSounds(true)
    m.files = CreateObject("roFileSystem")
    m.fonts = {reg:CreateObject("roFontRegistry")}
    m.fonts.reg.Register("pkg:/assets/fonts/PoP.ttf")
    m.fonts.reg.Register("pkg:/assets/fonts/Gotham-Medium.otf")
    m.fonts.KeysFont = m.fonts.reg.getFont("Gotham Medium", 30, false, false)
    m.bitmapFont = LoadBitmapFont()
    m.prandom = CreatePseudoRandom()
    m.manifest = GetManifestArray()
    m.status = []
    'Check Roku model for performance alert
    if not IsOpenGL()
        m.mainScreen = CreateObject("roScreen", true, 1280, 720)
        canvas = CreateCanvas()
        MessageDialog(m.port, "Prince of Persia", "Warning: Your Roku device doesn't support accelerated" + chr(10) + "graphics, this game may not perform well.")
    end if
    'Initialize Screen
    ResetMainScreen()
    'Load Mods
    m.mods = LoadMods()
    'Initialize Settings
    m.settings = LoadSettings()
    if m.settings = invalid
        m.settings = {}
        m.settings.controlMode = m.const.CONTROL_VERTICAL
        m.settings.spriteMode = m.const.SPRITES_DOS
    else if m.settings.modId <> invalid
        if m.mods.DoesExist(m.settings.modId)
            if m.mods[m.settings.modId].sprites
                m.settings.spriteMode = Val(m.settings.modId)
            end if
        else
            m.settings.modId = invalid
            m.settings.spriteMode = m.const.SPRITES_DOS
        end if
    end if
    if m.settings.fight = invalid then m.settings.fight = m.const.FIGHT_ATTACK
    if m.settings.rewFF = invalid then m.settings.rewFF = m.const.REWFF_NONE
    if m.settings.saveGame = invalid then m.settings.saveGame = true
    if m.settings.okMode = invalid then m.settings.okMode = m.const.OKMODE_TIME
    'Game/Debug switches
    m.debugMode = false ' flag to enable/disable debug code
    m.dark = false 'flag for debugging without map tiles paint
    m.intro = true 'flag to enable/disable intro screens
    m.flip = false 'flag to flip the screen vertically
    'Load saved game and high scores
    m.savedGame = LoadSavedGame()
    m.highScores = LoadHighScores()
    if m.highScores = invalid then m.highScores = []
    'Play Game Introduction and Disclaimer
    if m.intro
        print "Starting intro..."
        PlayIntro(m.const.SPRITES_MAC)
        PlaySong("scene-1b-princess", true)
        TextScreen("text-disclaimer", m.colors.black, 27000, 0, m.const.SPRITES_MAC)
        m.audioPlayer.Stop()
    end if
    'Main Menu Loop
    while true
        print "Starting menu..."
        m.cameras = StartMenu()
        if m.cameras > 0
            'Configure screen/game areas based on the configuration
            SetupGameScreen()
            'Restore saved game
            m.currentLevel = 1
            if m.settings.modId = invalid
                m.startTime = m.const.TIME_LIMIT
                m.startHealth = m.const.START_HEALTH
            else
                m.startTime = m.mods[m.settings.modId].time * 60
                m.startHealth = m.mods[m.settings.modId].health
            end if
            m.checkPoint = invalid
            m.usedCheat = (m.settings.fight > m.const.FIGHT_ATTACK)
            if m.settings.saveGame and m.savedGame <> invalid
                ClearScreenBuffers()
                option = MessageBox(m.gameScreen, 320, 100, "Restore Saved Game?")
                if option = m.const.BUTTON_YES
                    m.currentLevel = m.savedGame.level
                    m.checkPoint = m.savedGame.checkPoint
                    m.startTime = m.savedGame.time
                    m.startHealth = m.savedGame.health
                    m.settings.modId = m.savedGame.modId
                    if m.settings.modId <> invalid and m.mods[m.settings.modId].sprites
                        m.settings.spriteMode = Val(m.settings.modId)
                    else if m.settings.modId <> invalid or m.settings.spriteMode > m.const.SPRITES_MAC
                        m.settings.spriteMode = m.const.SPRITES_DOS
                    end if
                    if m.savedGame.cheat <> invalid
                        m.usedCheat = (m.usedCheat and m.savedGame.cheat)
                    end if
                    SaveSettings(m.settings)
                end if
            else
                option = m.const.BUTTON_NO
            end if
            if option <> m.const.BUTTON_CANCEL
                ClearScreenBuffers()
                'Download mod if remote
                if m.settings.modId <> invalid and Left(m.mods[m.settings.modId].url, 3) = "tmp"
                    DownloadMod(m.mods[m.settings.modId])
                end if
                'Debug: Uncomment the next two lines to start at a specific location
                'm.currentLevel = 3
                'm.checkPoint = {room: 6, tile: 7, face: 1}
                print "Starting the Game"
                m.levelTime = m.startTime
                'Play introduction and cut scene
                skip = false
                if m.currentLevel = 1
                    skip = PlayIntro()
                    if not skip
                        print "Starting opening story..."
                        PlaySong("scene-1a-absence")
                        skip = TextScreen("text-in-the-absence", m.colors.navy, 15000, 7)
                    end if
                end if
                if not skip
                    skip = PlayScene(m.gameScreen, m.currentLevel)
                end if
                if m.currentLevel = 1 and not skip
                    TextScreen("text-marry-jaffar", m.colors.navy, 18000, 7)
                end if
                'Open Game Screen
                ResetGame()
                PlayGame()
            end if
        end if
        ResetMainScreen()
    end while
End Sub

Sub NextLevel()
    g = GetGlobalAA()
    if g.currentLevel = g.maxLevels then return
    g.currentLevel++
    g.startHealth = g.kid.maxHealth
    g.levelTime = g.timeLeft
    g.checkPoint = invalid
    PlayScene(g.gameScreen, g.currentLevel)
    ResetGame()
End Sub

Sub PreviousLevel()
    g = GetGlobalAA()
    if g.currentLevel = 1 or g.currentLevel = g.maxLevels then return
    g.currentLevel--
    g.startHealth = g.kid.maxHealth
    g.checkPoint = invalid
    ResetGame()
End Sub

Sub ResetGame()
    g = GetGlobalAA()
    if g.currentLevel = g.maxLevels and g.cameras > 1
        'Force final level always to be shown in Classic 1 room mode
        g.cameras = 1
        SetupGameScreen()
        g.kid = invalid
    end if
    g.tileSet = LoadTiles(g.currentLevel)
    LoadGameSprites(g.tileSet.spriteMode, g.tileSet.level.type, g.scale, g.tileSet.level.guards)
    if g.checkPoint <> invalid
        g.startRoom = g.checkPoint.room
        g.startTile = g.checkPoint.tile
        g.startFace = g.checkPoint.face
    else
        g.startRoom = g.tileSet.level.prince.room
        g.startTile = g.tileSet.level.prince.location - 1
        g.startFace = g.tileSet.level.prince.direction
    end if
    if g.kid = invalid
        g.kid = CreateKid(g.tileSet.level, g.startRoom, g.startTile, g.startFace, g.startHealth)
    else
        g.kid.startLevel(g.tileSet.level, g.startRoom, g.startTile, g.startFace, g.startHealth)
    end if
    g.xOff = (g.const.ROOM_WIDTH * g.scale) * g.tileSet.level.rooms[g.startRoom].x
    g.yOff = (g.const.ROOM_HEIGHT * g.scale) * g.tileSet.level.rooms[g.startRoom].y
    g.oldRoom = g.startRoom
    g.floor = invalid
    if g.flip then FlipScreen()
    g.redraw = true
    if g.mobs <> invalid
        for each mob in g.mobs
            if mob.tile <> invalid then mob.tile.fall = false
            if mob.sprite.back <> invalid then mob.sprite.back.Remove()
        next
    end if
    if g.guards = invalid then g.guards = []
    if g.guards.Count() > 0
        for each guard in g.guards
            if guard.sprite <> invalid then  guard.sprite.Remove()
            if guard.sword.sprite <> invalid then guard.sword.sprite.remove()
            if guard.splash.sprite <> invalid then guard.splash.sprite.remove()
        next
        g.guards.Clear()
    end if
    for i = 0 to g.tileSet.level.guards.Count() - 1
        ginfo = g.tileSet.level.guards[i]
        if g.tileSet.level.rooms[ginfo.room] <> invalid
            g.guards.Push(CreateGuard(g.tileSet.level, ginfo.room, ginfo.location - 1, ginfo.direction, ginfo.skill, ginfo.type, ginfo.colors, ginfo.active, ginfo.visible))
        end if
    next
    g.status.Clear()
    If g.currentLevel < g.maxLevels - 1
        g.status.Push({ text: "LEVEL " + m.currentLevel.toStr(), duration: 2, alert: false})
        g.showTime = true
    end if
    StopAudio()
End Sub

Sub SetupGameScreen()
	m.scale = 1.0
	if IsHD()
		if m.cameras = 3 '3x3
			maxResolution = true
			m.gameWidth = 960
			m.gameHeight = 600
		else if m.cameras = 2 '2x2
			maxResolution = false
			m.gameWidth = 640
			m.gameHeight = 400
		else 'classic 1x1 scale 2
			m.cameras = 1
			maxResolution = false
            if m.settings.spriteMode = m.const.SPRITES_MAC
                m.gameWidth = 640
                m.gameHeight = 400
                m.scale = 2.0
            else
                m.gameWidth = 320
                m.gameHeight = 200
            end if
        end if
		if maxResolution
			m.mainWidth = 1280
			m.mainHeight = 720
		else
			m.mainWidth = 854
			m.mainHeight = 480
		end if
	else
		if m.cameras = 3 '2x3
			maxResolution = true
			m.gameWidth = 640
			m.gameHeight = 600
		else if m.cameras = 2 '2x2
			maxResolution = false
			m.gameWidth = 640
			m.gameHeight = 400
		else 'classic 1x1 scale 2
			m.cameras = 1
			maxResolution = false
            if m.settings.spriteMode = m.const.SPRITES_MAC
                m.gameWidth = 640
                m.gameHeight = 400
                m.scale = 2.0
            else
                m.gameWidth = 320
                m.gameHeight = 200
            end if
		end if
		if maxResolution
			m.mainWidth = 854
			m.mainHeight = 626
		else
			m.mainWidth = 720
			m.mainHeight = 540
		end if
	end if
    ResetScreen(m.mainWidth, m.mainHeight, m.gameWidth, m.gameHeight)
End Sub

Sub ResetScreen(mainWidth as integer, mainHeight as integer, gameWidth as integer, gameHeight as integer)
    g = GetGlobalAA()
    g.mainScreen = CreateObject("roScreen", true, mainWidth, mainHeight)
    g.mainScreen.SetMessagePort(g.port)
    if mainWidth <> gameWidth or mainHeight <> gameHeight
        if m.gameWidth = 320
            g.gameXOff = Cint((g.mainWidth-g.gameWidth*2)/2)
            g.gameYOff = Cint((g.mainHeight-g.gameHeight*2)/2)
            g.gameScale = 2.0
        else
            g.gameXOff = Cint((g.mainWidth-g.gameWidth)/2)
            g.gameYOff = Cint((g.mainHeight-g.gameHeight)/2)
            g.gameScale = 1.0
        end if
        g.gameScreen = CreateObject("roBitmap", {width:g.gameWidth, height:g.gameHeight, alphaenable:true})
    else
        g.gameScreen = g.mainScreen
    end if
    g.gameScreen.SetAlphaEnable(true)
    g.compositor = CreateObject("roCompositor")
    g.compositor.SetDrawTo(g.gameScreen, g.colors.black)
    g.gameCanvas = CreateObject("roBitmap",{width:gameWidth, height:gameHeight, alphaenable:true})
End Sub

Sub ClearScreenBuffers()
    m.mainScreen.Clear(0)
    m.mainScreen.SwapBuffers()
    m.mainScreen.Clear(0)
    m.mainScreen.SwapBuffers()
    m.mainScreen.Clear(0)
End Sub

Sub LoadGameSprites(spriteMode as integer, levelType as integer, scale as float, guards = [] as object)
    g = GetGlobalAA()
    if g.regions = invalid then g.regions = {spriteMode: spriteMode, levelType: levelType, scale: scale}
    path = "pkg:/assets/sprites/"
    if spriteMode = g.const.SPRITES_MAC
        suffix = "-mac"
        scale /= 2.0
    else
        suffix = "-dos"
    end if
    'Check if a Mod with sprites is loaded
    useModSprite = (g.settings.modId <> invalid and g.mods[g.settings.modId].sprites and spriteMode = Val(g.settings.modId))
    if useModSprite
        modPath = g.mods[g.settings.modId].url + g.mods[g.settings.modId].path
        if Left(modPath, 3) = "pkg"
            modPath = modPath + "sprites/"
        end if
    end if
    'Load Regions
    if g.regions.general = invalid or g.regions.spriteMode <> spriteMode or g.regions.scale <> scale
        if useModSprite and g.files.Exists(modPath + "scenes.png")
            g.regions.scenes = LoadBitmapRegions(scale, modPath, "scenes")
        else
            g.regions.scenes = LoadBitmapRegions(scale, path + "scenes/", "scenes" + suffix)
        end if
        if useModSprite and g.files.Exists(modPath + "general.png")
            g.regions.general = LoadBitmapRegions(scale, modPath, "general")
        else
            g.regions.general = LoadBitmapRegions(scale, path + "general/", "general" + suffix)
        end if
        sprites = ["kid", "sword", "princess", "mouse", "jaffar"]
        for each name in sprites
            fullPath = path + name + "/"
            fullName = name + suffix
            if useModSprite and g.files.Exists(modPath + name + ".png")
                fullPath = modPath
                fullName = name
            end if
            charArray = []
            charArray.Push(LoadBitmapRegions(scale, fullPath, fullName, fullName, false))
            charArray.Push(LoadBitmapRegions(scale, fullPath, fullName, fullName, true))
            g.regions.AddReplace(name, charArray)
        next
    end if
    g.regions.guards = {}
    for i = 0 to guards.Count() - 1
        charArray = []
        if guards[i].type = "guard"
            png = guards[i].type + guards[i].colors.toStr()
        else
            png = guards[i].type
        end if
        fullPath = path + "guards/"
        fullName = guards[i].type + suffix
        fullImage = png + suffix
        if useModSprite and g.files.Exists(modPath + png + ".png")
            fullPath = modPath
            fullName = guards[i].type
            fullImage = png
        end if
        charArray.Push(LoadBitmapRegions(scale, fullPath, fullName, fullImage, false))
        charArray.Push(LoadBitmapRegions(scale, fullPath, fullName, fullImage, true))
        g.regions.guards.AddReplace(png, charArray)
    next
    levelColor = ""
    if levelType >= 0
        if g.settings.modId <> invalid and g.mods[g.settings.modId].levelColors <> invalid
            levelColor = g.mods[g.settings.modId].levelColors[g.currentLevel]
        end if
        if g.regions.tiles = invalid or g.regions.spriteMode <> spriteMode or g.regions.levelType <> levelType or g.regions.levelColor <> levelColor or g.regions.scale <> scale
            g.regions.tiles = invalid
            fullPath = path + "tiles/"
            if levelType = g.const.TYPE_DUNGEON
                fullName = "dungeon" + suffix
                if useModSprite and g.files.Exists(modPath + "dungeon.png")
                    fullPath = modPath
                    fullName = "dungeon"
                end if
            else
                fullName = "palace" + suffix
                if useModSprite and g.files.Exists(modPath + "palace.png")
                    fullPath = modPath
                    fullName = "palace"
                end if
            end if
            g.regions.tiles = LoadBitmapRegions(scale, fullPath, fullName, fullName + levelColor)
        end if
    end if
    g.regions.spriteMode = spriteMode
    g.regions.levelType = levelType
    g.regions.levelColor = levelColor
    g.regions.scale = scale
End Sub

Function GetTheme() as object
    theme = {
        BackgroundColor: "#000000FF",
        OverhangSliceSD: "pkg:/images/overhang_sd.jpg",
        OverhangSliceHD: "pkg:/images/overhang_hd.jpg",
        ListScreenHeaderText: "#FFFFFFFF",
        ListScreenDescriptionText: "#FFFFFFFF",
        ListItemHighlightSD: "pkg:/images/item_highlight_sd.png",
        ListItemHighlightHD: "pkg:/images/item_highlight_hd.png",
        ListItemText: "#C0C0C0FF",
        ListItemHighlightText: "#FF0000FF"
    }
    return theme
End Function
