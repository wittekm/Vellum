

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

                
class SpriteObject extends GameObject
    constructor: (@game, imageUrl) ->
        image = new Image
        image.src = imageUrl
        image.onload = => @ready = true
        @image = image
        [@dx, @dy] = 32
        @scale = 10
        @draw = false
        @scripts = []

        super(@game)

    reactToEvent: (event) =>
        switch event.type
            when "mousedown"
                @draw = true
            when "mouseup"
                @draw = false
            when "mousemove"
                [@dx, @dy] = [event.pageX, event.pageY]
            else
                return false
        true

    ###
    updateSelf: =>
        console.log "UPDATE: " + @constructor.name 
        script.update.call(this) for script in @scripts

    paintSelf: ->
        if @ready && @draw
            ctx = @game.ctx
            #sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight
            ctx.drawImage(@image, 200, 50, 150, 150, @dx - @scale/2, @dy - @scale/2, @scale, @scale)
    ###


