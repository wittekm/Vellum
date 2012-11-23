

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


class Hexagon extends GameObject
    constructor: (@game, @radius = 100) ->
        @x_offset = 0
        @y_offset = 0
        @precomputedWithRadius = Hexagon.precomputedSides.multByConst(@radius)
        @width = @precomputedWithRadius[0][0] * 2
        @height = @radius * 2

        super(@game)

    @precomputedSides:
        [
            [0.8660254037844387, 0.5] # cos and sin 30
            [0, 1]                    # cos and sin 90
            [-0.8660254037844387,0.5]
            [-0.8660254037844387,-0.5]
            [0,-1]
            [0.8660254037844387,-0.5]
        ]
    
    ###
    paintSelf: ->
        ctx = @game.ctx
        #paint each side
        for i in [0..5]
            x = @x_offset + @precomputedSides[i][0]*@radius;
            y = @y_offset + @precomputedSides[i][1]*@radius;
            ctx.moveTo(x, y);
            next = (i+1)%6
            x = @x_offset + @precomputedSides[next][0]*@radius;
            y = @y_offset + @precomputedSides[next][1]*@radius;
            ctx.lineTo(x, y);
        ctx.stroke()
    ###
                
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


