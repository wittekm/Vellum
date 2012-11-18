

# Old code I'm too scared to get rid of because it might prove useful in the future:
    ###
    sprite = new SpriteObject(game, "http://www-personal.umich.edu/~wittekm/uploads/burgerdog.jpg")
    zoomyScript = new Script
    zoomyScript.update = -> 
        @scale = (@game.time.curTime % 1000) / 10
        @scale = 100 - @scale if(@scale > 50)
        @scale = ( @scale + 10 ) * 1.5 #give it a lowest amount and a default scale

    sprite.scripts.push(zoomyScript)
    game.rootObject.addChild(sprite)
    ###

    ###
    tile = new Tile(0, 0, "grass", false)
    tileView = new TileView(tile)

    tile.setTerrain "grass"

    console.log tile.toString()
    ###

    #game.run()
