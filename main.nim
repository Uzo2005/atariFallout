import pkg/[raylib]
import std/[strutils, json]

const
    WIDTH = 640
    HEIGHT = 420
    Bg = getColor 0x191919ff
    paddingTop = 30.0
    padding = 5.0
    playableWidth = WIDTH - (padding * 2)
    playableHeight = HEIGHT - (padding + paddingTop)
    paddleWidth = 100.0
    paddleHeight = 20.0
    paddleColor = Blue
    bulletColor = RayWhite
    bulletSize = 10.0
    tileMargin = 3.0
    tileCols = 10
    tileWidth = (playableWidth - (tileMargin * tileCols)) / tileCols
    tileHeight = 3 * paddleHeight / 4
    steps = 0.2
    tileColors = [Red, Orange, Green, Yellow]
    continueGameText = "continue previous game"
    newGameText = "start a new game"
    fontSize = 16
    bgImageFileName = "resources/bg.png"
    maxSpawns = 4

type
    GameStatus = enum
        Intro
        Paused
        Playing
        GameOver

    Bullet = object
        x: float32
        y: float32
        xVelocity: float32
        yVelocity: float32
        size = bulletSize
        color = bulletColor

    Paddle = object
        x: float32
        y: float32
        width = paddleWidth
        height = paddleHeight
        color = paddleColor

    Tile = object
        pos: Vector2
        points: uint8

    GameState = object
        score: int
        highestScore: int
        reSpawns: int
        bullet: ref Bullet
        paddle: ref Paddle
        tiles: ref seq[Tile]
        status: GameStatus
        bgImage: ref Texture2D
        heartImage: ref Texture2D
        bgImageTint: Color
        isResumeGame: bool

proc loadStateFromFile(fileName: string, gameState: var GameState) =
    let gameStateJson = parseJson(readfile(fileName))
    gameState.score = gameStateJson["score"].getInt()
    gameState.highestScore = gameStateJson["highestScore"].getInt()
    gameState.reSpawns = gameStateJson["reSpawns"].getInt()
    gameState.status = parseEnum[GameStatus](getStr(gameStateJson["status"]))
    gameState.bgImageTint.r = gameStateJson["bgImageTint"]["r"].getint.uint8
    gameState.bgImageTint.g = gameStateJson["bgImageTint"]["g"].getint.uint8
    gameState.bgImageTint.b = gameStateJson["bgImageTint"]["b"].getint.uint8
    gameState.bgImageTint.a = gameStateJson["bgImageTint"]["a"].getint.uint8

    gameState.bullet.x = gameStateJson["bullet"]["x"].getFloat()
    gameState.bullet.y = gameStateJson["bullet"]["y"].getFloat()
    gameState.bullet.xVelocity = gameStateJson["bullet"]["xVelocity"].getFloat()
    gameState.bullet.yVelocity = gameStateJson["bullet"]["yVelocity"].getFloat()

    gameState.paddle.x = gameStateJson["paddle"]["x"].getFloat()
    gameState.paddle.y = gameStateJson["paddle"]["y"].getFloat()

    var index: int
    for tile in gameStateJson["tiles"].items:
        gameState.tiles[index].pos.x = tile["xPos"].getFloat()
        gameState.tiles[index].pos.y = tile["yPos"].getFloat()
        gameState.tiles[index].points = tile["points"].getInt().uint8
        inc index

proc initGame(gameState: var GameState) =
    gameState.bullet = new Bullet
    gameState.paddle = new Paddle
    gameState.tiles = new seq[Tile]
    gameState.bgImage = new Texture2D
    gameState.heartImage = new Texture2D

    gameState.tiles[] = newSeq[Tile](tileCols * tileColors.len)

    const tileInitY = paddingTop + tileHeight - (tileColors.len * (tileHeight))
    for index, tile in gameState.tiles[]:
        let
            tx = index mod tileCols
            ty = (index div tileCols)
            point = uint8(tileColors.len - ty)
        gameState.tiles[index].points = point
        gameState.tiles[index].pos = Vector2(
            x: padding + (tx.float * (tileWidth + tileMargin)),
            y: tileInitY + (ty.float * (tileHeight + tileMargin)),
        )

    gameState.paddle.x = ((padding + playableWidth) / 2) - (paddleWidth / 2)
    gameState.paddle.y = (playableHeight - paddleHeight + padding)
    gameState.bullet.x = gameState.paddle.x + (paddleWidth / 2)
    gameState.bullet.y = gameState.paddle.y
    gameState.bullet.xVelocity = 0.09
    gameState.bullet.yVelocity = -0.09

    gameState.bgImage[] = loadTexture(bgImageFileName)
    gameState.heartImage[] = loadTexture("resources/heart.png")

    gameState.reSpawns = maxSpawns
    gameState.status = Intro
    gameState.score = 0

func drawScoreBoard(gameState: var GameState) =
    let
        scoreBoardRect = Rectangle(x: 0, y: 0, width: WIDTH, height: paddingTop)
        scoreDisplay = "score: " & $gameState.score

    drawRectangle(scoreBoardRect, DarkGray)

    drawText(
        scoreDisplay.cstring, padding.int32, (paddingTop.int32 - 15) div 2, 15, White
    )

    for i in 0 ..< gameState.reSpawns:
        let tPadding =
            (padding + gameState.heartImage.width.float) * gameState.reSpawns.float
        drawTexture(
            gameState.heartImage[],
            Vector2(
                x:
                    WIDTH - tPadding +
                    float((gameState.heartImage.width.float + padding) * i.float),
                y: 0,
            ),
            White,
        )

func drawBullet(gameState: GameState) =
    drawRectangle(
        Rectangle(
            x: gameState.bullet.x,
            y: gameState.bullet.y,
            width: gameState.bullet.size,
            height: gameState.bullet.size,
        ),
        gameState.bullet.color,
    )

proc handleKeyPresses(gameState: var GameState, sound: Sound) =
    case gameState.status
    of Playing:
        if isKeyDown(Right) or isKeyDown(D):
            if gameState.paddle.x <
                    ((playableWidth + padding).float - gameState.paddle.width):
                gameState.paddle.x += steps
        elif isKeyDown(Left) or isKeyDown(A):
            if gameState.paddle.x > padding:
                gameState.paddle.x -= steps
        elif isKeyPressed(Space):
            playSound(sound)
            gameState.status = Paused
    of Paused:
        if isKeyPressed(Space):
            playSound(sound)
            gameState.status = Playing
    of Intro:
        if isKeyPressed(Tab):
            playSound(sound)
            gameState.isResumeGame = not (gameState.isResumeGame)

        if isKeyPressed(Enter):
            playSound(sound)
            if gameState.isResumeGame:
                loadStateFromFile("prevGameState.dump.json", gameState)
            else:
                gameState.status = Playing
    of GameOver:
        if isKeyPressed(Enter):
            playSound(sound)
            initGame(gameState)
            gameState.status = Playing

func drawPaddle(gameState: GameState) =
    drawRectangle(
        Rectangle(
            x: gameState.paddle.x,
            y: gameState.paddle.y,
            width: gameState.paddle.width,
            height: gameState.paddle.height,
        ),
        gameState.paddle.color,
    )

func drawTiles(gameState: var GameState) =
    for index, tile in gameState.tiles[]:
        let tileColor = tileColors[tileColors.len - tile.points]

        drawRectangle(
            Rectangle(
                x: tile.pos.x, y: tile.pos.y, width: tileWidth, height: tileHeight
            ),
            tileColor,
        )

        if gameState.status == Playing:
            gameState.tiles[index].pos.y += 1e-3

proc handlePhysics(
        gameState: var GameState, hitPaddleSound, hitTileSound, gameOverSound: Sound
) =
    case gameState.status
    of Playing:
        if gameState.reSpawns <= 0:
            gameState.highestScore = max(gameState.score, gameState.highestScore)
            playSound(gameOverSound)
            gameState.status = GameOver
        else:
            let
                bulletRect = Rectangle(
                    x: gameState.bullet.x,
                    y: gameState.bullet.y,
                    width: gameState.bullet.size,
                    height: gameState.bullet.size,
                )
                paddleRect = Rectangle(
                    x: gameState.paddle.x,
                    y: gameState.paddle.y,
                    width: gameState.paddle.width,
                    height: gameState.paddle.height,
                )

            for index, tile in gameState.tiles[]:
                let tileRect = Rectangle(
                    x: tile.pos.x, y: tile.pos.y, width: tileWidth, height: tileHeight
                )

                if bulletRect.checkCollisionRecs(tileRect):
                    playSound(hitTileSound)
                    gameState.bullet.yVelocity *= -1.0
                    inc gameState.score, tile.points

                    gameState.tiles[index] = Tile(
                        pos: Vector2(
                            x: tile.pos.x,
                            y:
                                paddingTop - (
                                    (tileHeight + tileMargin) * tileColors.len
                                ) - 50,
                        ),
                        points: tile.points,
                    )

                if tile.pos.y + tileHeight >= playableHeight:
                    gameState.highestScore =
                        max(gameState.score, gameState.highestScore)
                    playSound(gameOverSound)
                    gameState.status = GameOver

            if bulletRect.checkCollisionRecs(paddleRect):
                playSound(hitPaddleSound)
                gameState.bullet.yVelocity *= -1.0
                gameState.bullet.y = gameState.paddle.y - gameState.bullet.size

            if gameState.bullet.x <= padding or
                    (gameState.bullet.x + gameState.bullet.size) >=
                    (playableWidth + padding):
                gameState.bullet.xVelocity *= -1.0

            if gameState.bullet.y <= paddingTop:
                gameState.bullet.yVelocity *= -1.0

            if (gameState.bullet.y + gameState.bullet.size) >=
                    (playableHeight + paddingTop):
                playSound(gameOverSound)
                dec gameState.reSpawns
                gameState.bullet.x = gameState.paddle.x + (paddleWidth / 2)
                gameState.bullet.y = gameState.paddle.y

            gameState.bullet.y += gameState.bullet.yVelocity
            gameState.bullet.x += gameState.bullet.xVelocity
    else:
        discard

proc drawScreen(gameState: var GameState) =
    case gameState.status
    of Intro:
        const gameTitle = "ATARI FALLOUT"
        gameState.bgImageTint = Blue
        drawText(
            gameTitle,
            (WIDTH - measureText(gameTitle, 20)) div 2,
            2 * padding.int32,
            20,
            White,
        )
        let
            continueGameTextWidth = continueGameText.measureText(fontSize)
            newGameTextWidth = newGameText.measureText(fontSize)
            width = max(continueGameTextWidth, newGameTextWidth).float + 50
            height = 50.0
            marginY = 10.0
            buttonRect1 = Rectangle(
                x: (WIDTH - width) / 2,
                y: ((HEIGHT - height) / 2) - marginY,
                width: width,
                height: height,
            )
            buttonRect2 = Rectangle(
                x: (WIDTH - width) / 2,
                y: ((HEIGHT + height) / 2) + marginY,
                width: width,
                height: height,
            )

        if not gameState.isResumeGame:
            drawRectangleRounded(buttonRect1, 0.2, 500, Green)
            drawText(
                newGameText,
                int32(buttonRect1.x + buttonRect1.width / 2 - newGameTextWidth / 2),
                int32(buttonRect1.y + buttonRect1.height / 2 - fontSize / 2),
                fontSize,
                White,
            )
            drawText(
                continueGameText,
                int32(buttonRect2.x + buttonRect2.width / 2 - continueGameTextWidth / 2),
                int32(buttonRect2.y + buttonRect2.height / 2 - fontSize / 2),
                fontSize,
                Green,
            )
            drawRectangleRoundedLines(buttonRect2, 0.2, 500, 2.0, White)
        else:
            drawText(
                newGameText,
                int32(buttonRect1.x + buttonRect1.width / 2 - newGameTextWidth / 2),
                int32(buttonRect1.y + buttonRect1.height / 2 - fontSize / 2),
                fontSize,
                Green,
            )
            drawRectangleRoundedLines(buttonRect1, 0.2, 500, 2.0, White)
            drawRectangleRounded(buttonRect2, 0.2, 500, Green)
            drawText(
                continueGameText,
                int32(buttonRect2.x + buttonRect2.width / 2 - continueGameTextWidth / 2),
                int32(buttonRect2.y + buttonRect2.height / 2 - fontSize / 2),
                fontSize,
                White,
            )

            # if gameState.isResumeGame:
    of Playing:
        gameState.bgImageTint = Green
        gameState.drawTiles()
        gameState.drawBullet()
        gameState.drawPaddle()
        gameState.drawScoreBoard()
    of Paused:
        gameState.bgImageTint = Yellow
        const pausedTitle = "Game Paused"
        drawText(
            pausedTitle,
            (WIDTH - measureText(pausedTitle, 20)) div 2,
            HEIGHT div 2,
            20,
            Yellow,
        )
        gameState.drawTiles()
        gameState.drawBullet()
        gameState.drawPaddle()
        gameState.drawScoreBoard()
    of GameOver:
        let
            currentScore = "Score: " & $gameState.score
            highestScore = "Highest score: " & $gameState.highestScore

        drawText(
            currentScore.cstring,
            (WIDTH - measureText(currentScore.cstring, 35)) div 2,
            paddingTop.int32,
            35,
            Green,
        )

        drawText(
            highestScore.cstring,
            (WIDTH - measureText(highestScore.cstring, 35)) div 2,
            paddingTop.int32 + 50,
            35,
            Green,
        )
        gameState.bgImageTint = Red
        const pausedTitle = "Game Over"
        let
            newGameTextWidth = newGameText.measureText(fontSize)
            width = newGameTextWidth.float + 50
            height = 50.0
            marginY = 10.0
            buttonRect1 = Rectangle(
                x: (WIDTH - width) / 2,
                y: HEIGHT - height - marginY,
                width: width,
                height: height,
            )
        drawText(
            pausedTitle,
            (WIDTH - measureText(pausedTitle, 25)) div 2,
            HEIGHT div 2,
            25,
            Red,
        )
        drawRectangleRounded(buttonRect1, 0.2, 500, Green)
        drawText(
            newGameText,
            int32(buttonRect1.x + buttonRect1.width / 2 - newGameTextWidth / 2),
            int32(buttonRect1.y + buttonRect1.height / 2 - fontSize / 2),
            fontSize,
            White,
        )

proc updateGame(
        gameState: var GameState,
        selectSound, hitPaddleSound, hitTileSound, gameOverSound: Sound,
) =
    let bgSrc = Rectangle(
        x: 0,
        y: 0,
        width: gameState.bgImage.width.float,
        height: gameState.bgImage.height.float,
    )

    drawTexture(
        gameState.bgImage[],
        bgSrc,
        Rectangle(x: 0, y: 0, width: WIDTH, height: HEIGHT),
        Vector2(x: 0, y: 0),
        0,
        gameState.bgImageTint,
    )

    gameState.handleKeyPresses(selectSound)
    gameState.drawScreen()
    gameState.handlePhysics(hitPaddleSound, hitTileSound, gameOverSound)

proc save(gameState: GameState, storageFile: string) =
    var gameStateJson = %*{}
    gameStateJson["score"] = %gameState.score
    gameStateJson["highestScore"] = %gameState.highestScore
    gameStateJson["reSpawns"] = %gameState.reSpawns
    gameStateJson["status"] = %gameState.status
    gameStateJson["bgImageTint"] = %gameState.bgImageTint

    gameStateJson["bullet"] =
        %*{
            "x": gameState.bullet.x,
            "y": gameState.bullet.y,
            "xVelocity": gameState.bullet.xVelocity,
            "yVelocity": gameState.bullet.yVelocity,
        }

    gameStateJson["paddle"] = %*{"x": gameState.paddle.x, "y": gameState.paddle.y}
    gameStateJson["tiles"] = %*[]
    for tile in gameState.tiles[]:
        gameStateJson["tiles"].add(
            %*{"xPos": tile.pos.x, "yPos": tile.pos.y, "points": tile.points}
        )

    writeFile(storageFile, $gameStateJson)

proc playGame() =
    var gameState: GameState
    initAudioDevice()
    let
        backgroundMusic = loadMusicStream("resources/music.mp3")
        selectSound = loadSound("resources/select.ogg")
        hitPaddleSound = loadSound("resources/hitPaddle.ogg")
        hitTileSound = loadSound("resources/hitTile.ogg")
        gameOverSound = loadSound("resources/gameOver.ogg")

    initWindow(WIDTH, HEIGHT, "Atari Fallout")
    setConfigFlags(flags(Msaa4xHint))

    initGame(gameState)

    while not (windowShouldClose()):
        playMusicStream(backgroundMusic)
        drawing:
            clearBackground(Bg)
            updateGame(
                gameState, selectSound, hitPaddleSound, hitTileSound, gameOverSound
            )
        updateMusicStream(backgroundMusic)

    closeAudioDevice()

    gameState.save("prevGameState.dump.json")

when isMainModule:
    playGame()
