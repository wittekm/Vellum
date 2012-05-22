##### General CoffeeScript improvements #####
Array::remove = (elem) -> 
    @[t..t] = [] if (t = @indexOf(elem)) > -1

findIf = (arr, predicate) ->
    return elem for elem in arr when predicate(elem)
    return null


# analogous to c++'s std::find_if(itr, itr, pred)
Array::findIf = (predicate) ->
    findIf(this, predicate)

##### Actual code #####
class Game
    dimensions: [640, 480]
    # 10 frames per second
    msPerFrame: 1000/30

    constructor: ->
        @dimensions = [document.width, document.height]
        @canvas = @getCanvas()
        @time = new Time
        @rootObject = new GameObject(this)
        canvas.addEventListener("click", @rootObject.reactToEvent, false);
        canvas.addEventListener("mousemove", @rootObject.reactToEvent, false);

    run: ->
        setInterval @main, @msPerFrame

    # Fat arrow because we call main from a different context 
    main: =>
        @update()
        console.log "hey" + @time.deltaTime
        @rootObject.paint()

    getCanvas: ->
        canvas = document.getElementById 'canvas'
        [canvas.width, canvas.height] = @dimensions
        canvas

    update: ->
        @time.update()
        @rootObject.update()

class Time
    constructor: ->
        @oldTime = 0
        @curTime = Date.now()
    update: ->
        @oldTime = @curTime
        @curTime = Date.now()
        @deltaTime = @curTime - @oldTime


class GameObject
    constructor: (@game) ->
        @parent = null
        @children = []
        console.log(@children.length)
        
    paint: ->
        console.log(@children.length)
        child.paint() for child in @children

    update: ->
        child.update() for child in @children
        
    # Searches children for a single child that accepts the event.
    reactToEvent: (event) =>
        gameObject = @children.findIf( (child) -> child.reactToEvent(event))
        return gameObject?
        # oh my god coffeescript existence is beautiful


    addChild: (child) ->
        @children.push(child)
        child.parent = this

    removeChild: (child) ->
        child.parent = null
        @children.remove(child)

class SpriteObject extends GameObject
    constructor: (@game, imageUrl) ->
        image = new Image
        image.src = imageUrl
        image.onload = => @ready = true
        @image = image
        [@dx, @dy] = 32
        @scale = 1;

        super(@game)

    reactToEvent: ->
        if(event.type == "mousemove")
            [@dx, @dy] = [event.x, event.y]
        return true

    update: ->
        @scale = @game.time.curTime % 2000 / 4 
        @scale = 500 - @scale if(@scale > 250)
        ###
        if(@vx != 0)
            @dx += @vx
        if(@vy != 0)
            @vy += @vy
        ###

    paint: ->
        if @ready
            ctx = @game.canvas.getContext("2d")
            #sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight
            ctx.drawImage(@image, 200, 50, 150, 150, @dx - @scale/2, @dy - @scale/2, @scale, @scale)
        #super()

game = new Game
sprite = new SpriteObject(game, "http://www-personal.umich.edu/~wittekm/uploads/burgerdog.jpg")
obj = new GameObject(game)
game.rootObject.addChild(sprite)
game.run()

