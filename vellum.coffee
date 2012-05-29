##### General CoffeeScript improvements #####
Array::remove = (elem) -> 
    @[t..t] = [] if (t = @indexOf elem) > -1

# analogous to c++'s std::find_if(itr, itr, pred)
findIf = (arr, predicate) ->
    return elem for elem in arr when predicate(elem)
    return null

Array::findIf = (predicate) ->
    findIf(this, predicate)

Array::clone = ->
	cloned = []
	for i in this
		cloned.push i
	cloned

Array::multByConst = (constant) ->
    clone = []
    for elem in this
        if typeof elem is "object"
            clone.push elem.multByConst(constant)
        else
            clone.push elem * constant
    clone

# jQuery setup
$ = jQuery


##### mixins #####
moduleKeywords = ['extended', 'included']

class Module
  @extend: (obj) ->
    for key, value of obj when key not in moduleKeywords
      @[key] = value

    obj.extended?.apply(@)
    this

  @include: (obj) ->
    for key, value of obj when key not in moduleKeywords
      # Assign properties to the prototype
      @::[key] = value

    obj.included?.apply(@)
    this

# A Model's functions must manually call changed, or set, if we care about propagating it to
# their associated Views.
class Model extends Module
    constructor: ->
        @propertyListeners = {}
    addChangeListener: (property, listener) ->
        @propertyListeners[property] ?= []
        @propertyListeners[property].push listener
    set: (property, newVal) =>

    changed: (property, oldVal, newVal) =>
        console.log "#{property} changed."
        console.log @
        if @propertyListeners[property]?
            listener.inform(property, oldVal, newVal) for listener in @propertyListeners[property]

class View extends Module
    constructor: (@model, @propertyChangedCallbacks) ->
        @registerListeningProperties()

    registerListeningProperties: ->
        for prop, callback of @propertyChangedCallbacks
            console.log "#{@constructor.name} adding #{prop} listener to #{@model.constructor.name}"
            @model.addChangeListener prop, this 

    inform: (property, oldVal, newVal) =>
        callback = @propertyChangedCallbacks[property]
        Tools.Args.checkExists callback, "Callback for #{constructor.name}'s #{property} change"
        callback(oldVal, newVal)
 
##### Actual code #####
class Tools
    @Args: class Args
        @checkExists: (obj, msg="") ->
            throw "Doesn't exist: #{msg}" if !(obj?)
        @checkNull: (obj) ->
            throw "Object null" if obj == null

class Game
    dimensions: []
    # denominator = frames per second
    msPerFrame: 1000/2

    constructor: ->
        @dimensions = [$(window).width() - 20, $(window).height() - 20]
        @viewDimensions = [0,0]
        @canvas = @getCanvas()
        @ctx = @canvas.getContext('2d')

        @time = new Time
        @rootObject = new GameObject(this)
        @bindEvents()

    run: ->
        @intervalID = setInterval @main, @msPerFrame
    
    stop: ->
        clearTimeout @intervalID
        @intervalID = null

    # Fat arrow because we call main from a different context 
    main: =>
        @update()
        console.log "delta time:" + @time.deltaTime

        # Translate the canvas and paint the objects.
        ###
        @ctx.save()
        @ctx.translate(@viewDimensions[0], @viewDimensions[1])
        @rootObject.paint()
        @ctx.restore();
        ###

    getCanvas: ->
        canvas = $("#canvas")[0]
        [canvas.width, canvas.height] = @dimensions
        canvas

    bindEvents: ->
        $(canvas).on 'mousemove' , @rootObject.reactToEvent
        $(canvas).on 'mousedown' , @rootObject.reactToEvent
        $(canvas).on 'mouseup'   , @rootObject.reactToEvent
        $(document).on 'keydown' , @viewDimensionsScroll 
            
    viewDimensionsScroll: (event) =>
        if(String.fromCharCode(event.which) == 'D')
            @viewDimensions[0]+= 10

    update: ->
        @time.update()

class Time
    constructor: ->
        @oldTime = 0
        @curTime = Date.now()
    update: ->
        @oldTime = @curTime
        @curTime = Date.now()
        @deltaTime = @curTime - @oldTime

class TurnBasedGame
    constructor: ->
        @map = []
        @turn = []
        @state = []
        @currentPlayer = "me"
        @players = []

class PathFinder
    constructor: (@map) ->

class Rules
    constructor: ->

# the following are all strictly in model territory

LocationInterface = 
    canAdd: (locatable) ->
    add: (locatable) ->
    remove: (locatable) -> # bool; if locatable has been removed
    contains: (locatable) ->
    # i don't need the getters really
    getLocatables: ->
    getRow: ->
    getCol: ->
    toString: ->

LocatableInterface = 
    setLocation: (newLocation) ->

PropertyChangeSupport = 
    changed: (property, oldVal, newVal) =>
        console.log "#{property} changed."

class AbstractLocation extends Model
    @include LocationInterface 
    constructor: ->
        super()
    getRow: => @row
    getCol: => @col
    locationString: -> "#{@row}, #{@col}"
    toString: -> @locationString()

class Tile extends AbstractLocation

    constructor: (@row, @col, @terrain, @fog = true) ->
        super()
        @locatables = []

    canAdd: (locatable) -> locatable? && !(@contains locatable)
    contains: (locatable) -> locatable in @locatables

    add: (locatable) -> 
        if @canAdd locatable
            @locatables.push locatable
            locatable.setLocation @
        @changed "locatable", null, locatable # move into the if?

    remove: (locatable) -> 
        if (removed = @locatables.remove locatable?)
            @changed "locatable", locatable, null
        removed 

    setTerrain: (newTerrain) ->
        Tools.Args.checkNull(newTerrain)
        oldTerrain = @terrain
        @terrain = newTerrain
        @changed "terrain", oldTerrain, newTerrain

    setFog: (newFog) ->
        oldFog = @fog
        @fog = newFog
        @changed "fog", oldFog, newFog
    
    toString: -> "#{@locationString()}, fog: #{@fog}, terrain: #{@terrain}, locatables: #{@locatables}"
    # fill in some LocationInterface functions

class Terrain extends Module
    @include PropertyChangeSupport

class Map
    constructor: (@name = "", @author = "", @desc = "", @rows, @cols, @size, baseTerrain = "grass") ->
        @tiles = @init()
        @pathFinder = new PathFinder(this)
        @rules = new Rules
        @fill(@rows, @cols, baseTerrain)
    
    @mapFromJson: (url) ->
        $.getJSON(url).success(@parseJsonRequest).error(@parseJsonError)

    @parseJsonRequest: (data) =>
        map = new Map(data.name, data.author, data.desc, data.rows, data.cols, data.size) 
        console.log map
        console.log "gotta get that map back somewhere useful."
        
    @parseJsonError: (data, xhr) =>
        console.log data.statusText
        console.log xhr

    init: ->
        rows = []
        for i in [0..@rows-1]
            cols = []
            cols.push null for j in [0..@cols-1]
            rows.push cols
        rows

    # center tile is not included.
    surroundingTiles: (center, range) ->
        []
    
    setTile: (x, y, tile) ->
        @tiles[x][y] = tile 
    
    fill: (terrain) ->


class GameObject extends Module
    @include PropertyChangeSupport

    # a static hash, acts like an enum
    @State: 
        idle: 0      # default state
        active: 1    # perform input
        destroyed: 2 # can be removed

    constructor: (@game) ->
        @state = GameObject.State.idle
        @parent = null
        @children = []
        
    # Searches children for the first child that accepts the event.
    reactToEvent: (event) =>
        gameObject = @children.findIf((child) -> child.reactToEvent(event))
        gameObject?
        # oh my god coffeescript existence is beautiful

    setState: (newState) ->
        oldState = @state
        @state = newState
        @changed "state", oldState, newState

    isIdle:      -> @state == GameObject.State.idle
    isActive:    -> @state == GameObject.State.active
    isDestroyed: -> @state == GameObject.State.destroyed

    addChild: (child) ->
        @children.push(child)
        child.parent = this

    removeChild: (child) ->
        child.parent = null
        @children.remove(child)

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

class GameController
    constructor: (config) ->
        @map = []

class GameView
    constructor: (@gameController) ->
        @mapView = @createMapView()
    createMapView:
        {}

class Script
    constructor: ->
        @update = ->



class TileView extends View
    constructor: (model) ->
        propertyChangedCallbacks =
            "fog": @fogChange
            "terrain": @terrainChange
        super(model, propertyChangedCallbacks) 

    fogChange: (oldVal, newVal) -> console.log "new fog: #{newVal}"
    terrainChange: (oldVal, newVal) -> console.log "new terrain: #{newVal}"

map = Map.mapFromJson('maps/basic.json')

$ ->
    game = new Game
    #hex = new Hexagon(game)
    sprite = new SpriteObject(game, "http://www-personal.umich.edu/~wittekm/uploads/burgerdog.jpg")
    zoomyScript = new Script
    zoomyScript.update = -> 
        @scale = (@game.time.curTime % 1000) / 10
        @scale = 100 - @scale if(@scale > 50)
        @scale = ( @scale + 10 ) * 1.5 #give it a lowest amount and a default scale

    sprite.scripts.push(zoomyScript)
    game.rootObject.addChild(sprite)
    tile = new Tile(0, 0, "grass", false)
    tileView = new TileView(tile)

    tile.setTerrain "grass"

    console.log tile

    game.run()

    $(canvas).on 'mousedown', (e) => 
        game.stop() if e.which == 3
