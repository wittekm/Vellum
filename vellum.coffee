##### General CoffeeScript improvements #####
Array::remove = (elem) -> 
    @[t..t] = [] if (t = @indexOf(elem)) > -1

# analogous to c++'s std::find_if(itr, itr, pred)
findIf = (arr, predicate) ->
    return elem for elem in arr when predicate(elem)
    return null

Array::findIf = (predicate) ->
    findIf(this, predicate)

# jQuery setup
$ = jQuery

##### Actual code #####
class Game
    dimensions: []
    # denominator = frames per second
    msPerFrame: 1000/60

    constructor: ->
        @dimensions = [$(window).width() - 20, $(window).height() - 20]
        @canvas = @getCanvas()
        console.log "canvas? " + @canvas? + " dimensions? " + @dimensions[1]
        @time = new Time
        @rootObject = new GameObject(this)
        @bindEvents()

    run: ->
        setInterval @main, @msPerFrame

    # Fat arrow because we call main from a different context 
    main: =>
        @update()
        console.log "delta time:" + @time.deltaTime
        @rootObject.paint()

    getCanvas: ->
        canvas = $("#canvas")[0]
        [canvas.width, canvas.height] = @dimensions
        canvas

    bindEvents: ->
        $(canvas).on('mousemove', @rootObject.reactToEvent)
        $(canvas).on('mousedown', @rootObject.reactToEvent)
        $(canvas).on('mouseup', @rootObject.reactToEvent)

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
        
    paint: ->
        child.paint() for child in @children

    update: ->
        child.update() for child in @children
        
    # Searches children for a single child that accepts the event.
    reactToEvent: (event) =>
        #console.log "Reacting to event"
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
        @scale = 10;
        @draw = false
        @updateFuncs = []

        super(@game)

    reactToEvent: (event) =>
        @draw = true if event.type == "mousedown"
        @draw = false if event.type == "mouseup"

        if(event.type == "mousemove")
            [@dx, @dy] = [event.pageX, event.pageY]
            return true
        else
            return false

    update: ->
        console.log "UPDATE: " + Object.keys this
        func.call(this) for func in @updateFuncs

        @scale = (@game.time.curTime % 1000) / 10
        # does the downwards scaling
        @scale = 100 - @scale if(@scale > 50)
        #give it a base size of 10
        @scale += 10
        # and then multiply it so it looks nice and big
        @scale *= 2

    paint: ->
        if @ready && @draw
            ctx = @game.canvas.getContext("2d")
            #sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight
            ctx.drawImage(@image, 200, 50, 150, 150, @dx - @scale/2, @dy - @scale/2, @scale, @scale)
        #super()


$ ->
    game = new Game
    sprite = new SpriteObject(game, "http://www-personal.umich.edu/~wittekm/uploads/burgerdog.jpg")
    sprite.updateFuncs.push -> 
        console.log "testing. this in this context should be the s prite, but it isn't."
    
    game.rootObject.addChild(sprite)
    game.run()
