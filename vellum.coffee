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


##### MVC BOILERPLATE #####

# A Model's functions must manually call changed, or set, if we care about propagating it to
# their associated Views.
class Model extends Module
    constructor: ->
        @propertyListeners = {}
    addChangeListener: (property, listener) ->
        @propertyListeners[property] ?= []
        @propertyListeners[property].push listener

    # Swaps the old value for the new value; then calls @changed
    set: (property, newVal) =>
        oldVal = @[property]
        @[property] = newVal
        @changed property, oldVal, newVal

    changed: (property, oldVal, newVal) =>
        console.log "#{property} changed."
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
        Tools.Args.checkExists callback, "#{constructor.name}'s #{property} change callback"
        callback(oldVal, newVal)
 
##### Actual code #####
class Tools
    @CallbackSet: (property, val) ->
        @[property] = val
    @Args: class Args
        @intMax: 9007199254740992
        @checkExists: (obj, msg="") ->
            throw "Doesn't exist: #{msg}" if !(obj?)
        @checkNull: (obj) ->
            throw "Object null" if obj == null
        @validateMinMax: (val, min, max, msg) ->
            throw "Not within bounds: #{msg}" if !(min <= val <= max)
        @betweenZeroAndIntMax: (amt) ->
            return 0 if amt < 0
            return Tools.Args.intMax if amt > Tools.Args.intMax
        @assert: (bool, msg) ->
            throw "Assert failed: #{msg}" if !msg
        @assertNot: (bool, msg) ->
            throw "Assert failed: #{msg}" if msg


        

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


# TODO: come back ater i make Turn
class TurnBasedGame extends Model

    # a static hash, acts like an enum
    @State: 
        idle: 0      # default state
        started: 1    # perform input
        gameOver: 2 # can be removed

    map: null
    players: []
    turn: null
    currentPlayer: null
    state: null

    constructor: (@map, @players, daysLimit) ->
        Tools.Args.checkNull @map
        Tools.Args.checkNull @players
        @turn = new Turn(daysLimit)
        @state = TurnBasedGame.State.idle
    startGame: (startingPlayer) ->
        @startGameValidate startingPlayer
        for player in @players
            player.state = GameObject.State.active
            @detectUnitFacingDirection player
            for unit in player.units
                unit.setDefaultOrientation()
        @setCurrentPlayer startingPlayer
        @setState TurnBasedGame.State.started
        @startTurn @currentPlayer
        console.log "Starting game with map #{map.name} has started"
        # TODO got to the end of startGame.

    setCurrentPlayer: (player) ->
        @set "currentPlayer", player

    setState: (state) ->
        @set "state", state
        
    detectUnitFacingDirection: (player) ->
        #TODO

    startGameValidate: (startingPlayer) ->
        throw "Game in illegal state" if @state != TurnBasedGame.State.idle 
        throw "Game in illegal state: Turn limit reached" if turn.limitReached()
        throw "Game in illegal state: unkown player" if !(@players.contains startingPlayer)
        @validatePlayers()
        @map.validate()
    validatePlayers: ->
        # number of players must equal map's number of players
        # each player must be unique
        # no player can be null
        # no neutral players in player list
        # compare with others:
            # no same colors
            # no same IDs

class GameObject extends Model
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
        @set "state", newState

    isIdle:      -> @state == GameObject.State.idle
    isActive:    -> @state == GameObject.State.active
    isDestroyed: -> @state == GameObject.State.destroyed

    addChild: (child) ->
        @children.push(child)
        child.parent = this

    removeChild: (child) ->
        child.parent = null
        @children.remove(child)



class Player extends GameObject
    @neutralPlayerID: -1
    @neutralTeam: -1
    @dummyCOName: "Commander Shepard"
    name: ""
    id: 0
    color: null # TODO: color.black or something
    team: 0
    ai: false
    headquarters: null
    commandingOfficer: null
    unitFacingDirection: null #Unit.DEFAULT_ORIENTATION

    budget: 0
    units: []
    structures: []
    madeFirstUnit: false
    coZone: [] # collection of locations

    constructor: (@name="", @id=0, @color=null, 
        @team=0, @ai=false, @commandingOfficer=null, @budget=0) ->

    initWithUnnamedHumanPlayer:(@id, @color) ->
        @name = "Anonymous"
        @commandingOfficer = Player.createDummyCO()
        @
    initWithDummyCO: ->
        @commandingOfficer = Player.createDummyCO()
        @
    @createNeutralPlayer: (color) ->
        new Player("Neutral", Player.neutralPlayerID, color, 
            Player.neutralTeam, false, Player.createDummyCO(), 0)

    # TODO move into COFactory
    @createDummyCO: ->
        null; # TODO: new BasicCO(dummy CO name)
    # TODO: copy constructor
    startTurn: ->
        unit.startTurn(@) for unit in @units
        structure.startTurn(@) for structure in @structures
    endTurn: ->
        unit.endTurn(@) for unit in @units
        structure.endTurn(@) for structure in @structures

    destroy: (conqueror) ->
        @setState GameObject.State.destroyed
        @destroyUnits()
        @changeStructureOwnersTo conqueror
        console.log "#{name} destroyed, #{conqueror.name} takes all their cities"

    # TODO refactor so we remove it in here imo
    destroyUnits: ->
        while @units.length != 0
            lastUnit = @units[@units.length - 1]
            lastUnit.destroy true # why does it accept a bool?

    changeStructureOwnersTo: (player) ->
        player.addStructure structure for structure in @structures
        @structures = []

    setBudget: (budget) ->
        budget = Tools.Args.betweenZeroAndIntMax budget
        @set "budget", budget
    increaseBudgetBy: (incr) -> @setBudget(@budget + incr)

    addStructure: (structure) ->
        Tools.Args.checkNull structure, "Can't add a null structure"
        Tools.Args.assertNot structure.contains structure, "Can't add structure twice"
        @structures.push structure
        structure.setOwner @
        @headquarters = structure if structure.isHQ()
        @changed "structures", null, structure
    
    hasStructure: (structure) -> structures.contains structure
    removeStructure: (structure) ->
        if (removed = @structures.remove structure)?
            hq = null if structure.isHQ()
            @changed "structures", removed, null
        else console.log "Removing #{structure.toString()} failed..."
        removed

    getStructures: -> structures.clone() # TODO: do I even need to have this
        
    addUnit: (unit) ->
        Tools.Args.checkNull unit, "Can't add a null unit"
        Tools.Args.assertNot units.contains unit, "Can't add same unit twice!"
        @madeFirstUnit = true if @units.length == 0
        @units.push unit
        unit.setOwner @
        @changed "units", null, unit

    hasUnit: (unit) -> units.contains unit
    removeUnit: (unit) -> 
        if (removed = @units.remove unit)?
            @changed "units", removed, null
        else console.log "Removing #{unit.toString()} failed..."
        removed

    getUnits: -> units.clone() # TODO: this too

    ##### TODO: add CO stuff? nah imo #####
    
    setName: (name) -> @set "name", name
    setHQ: (hq) -> @hq = hq
    setUnitFacingDirection: (dir) ->
        @unitFacingDirection = dir
        #TODO: fire off a set?
    setCOZone: (coZone) -> # TODO: what the hell is a CO Zone anyway
        @coZone = coZone
    numUnits: -> units.length
    numStructures: -> structures.length
    isNeutral: -> @team == Player.neutralTeam
    isUnitless: -> @createdFirstUnit && (@numUnits() == 0) # areAllUnitsDestroyed

    # TODO: am I adding Civ-like temporary treaties? Think about it. 
    # Maybe have list of allies.
    isAlly: (player) -> player.team == @team 
    isWithinBudget: (amt) -> @budget - amt >= 0

    # CO Zone stuff
    isInCOZone: (loc) -> isCOLoaded() && (co.isInCOZone getCOUnit(), loc)
    isCOLoaded: -> getCOUnit() != null
    getCOUnit: -> 
        return unit for unit in @units when unit.isCOOnBoard()
        null
    getCOZone: -> @coZone.clone()

    toString: -> "Name: #{@name} ID: #{@id} State: #{@state} Color: #{@color.toString()}
        Budget: #{@budget} Team: #{team} CO: #{co.getName()}"
    printStats: -> "#{@color.toString()}, units: #{@numUnits()}, 
        structures: #{@numStructures()}, HQ: #{if hq? then hq.toString() else hq}"





class Turn extends Model
    @unlimitedTurns: -1
    daysLimit: -1 
    turn: 0
    day: 1
    date: null

    constructor: (@daysLimit, @turn = 0, @day = 1, @date = Date.now()) ->
        Tools.Args.validateMinMax @daysLimit, -1, 1024, "Day Limit must be [0-1024] or UnlimitedTurns"
    nextTurn: -> @turn++
    nextDay:  -> @day++ # TODO: fix this
    limitReached: -> false # TODO: fix this


class PathFinder
    constructor: (@map) ->

class Rules
    constructor: ->

LocationInterface = 
    canAdd: (locatable) ->
    add: (locatable) ->
    remove: (locatable) -> # TODO: decide if this returns obj/null or true/false
    contains: (locatable) ->
    # i don't need the getters really...
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
    @extend LocationInterface 
    constructor: ->
        super()
    getRow: -> @row
    getCol: -> @col
    locationString: -> "#{@row}, #{@col}"
    toString: -> @locationString()

class Tile extends AbstractLocation
    constructor: (@row, @col, @terrain, @fog = true) ->
        super()
        @locatables = []

    canAdd:   (locatable) -> locatable? && !(@contains locatable)
    contains: (locatable) -> locatable in @locatables

    add: (locatable) -> 
        if @canAdd locatable
            @locatables.push locatable
            locatable.setLocation @
            @changed "locatable", null, locatable
        @

    remove: (locatable) -> 
        if (removed = @locatables.remove locatable)? # TODO: play with parens here maybe
            @changed "locatable", locatable, null
        removed 

    setTerrain: (newTerrain) ->
        Tools.Args.checkNull(newTerrain)
        @set "terrain", newTerrain

    setFog: (newFog) ->
        @set "fog", newFog
    
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
    
    @loadMapFromJson: (url, setterFunction) ->
        $.getJSON(url)
             # sets it to result of parsing the data
            .success (data) => 
                setterFunction @parseJsonMap data

            .error @parseJsonError

    @parseJsonMap: (data) =>
        map = new Map(data.name, data.author, data.desc, data.rows, data.cols, data.size) 
      
        
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

map = null
Map.loadMapFromJson 'maps/basic.json', (val) => 
    map = val
    @loaded()

@loaded = ->
    console.log "loaded #{map}!"
    tbgame = new TurnBasedGame(window.map, ["us", "them"], 5)
    window.map = map
    console.log tbgame

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

    console.log tile.toString()

    #game.run()

    $(canvas).on 'mousedown', (e) => 
        game.stop() if e.which == 3
