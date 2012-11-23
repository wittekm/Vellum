##### General CoffeeScript improvements #####
Array::remove = (elem) -> 
    @[t..t] = [] if (t = @indexOf elem) > -1

# analogous to c++'s std::find_if(itr, itr, pred)
findIf = (arr, predicate) ->
    return elem for elem in arr when predicate(elem)
    return null

# Magical bitwise stuff from the Little Book of CoffeeScript
Array::contains = (obj) -> !!~ this.indexOf obj

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

# shit I should eventually wrap in a globals or something
SX = 0
SY = 1
EX = 2
EY = 3

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

  log: (str) ->
    # return
    console.log "[#{@.constructor.name}]: #{str}"


##### MVC BOILERPLATE #####

# A Model's functions must manually call changed, or set, if we care about propagating it to
# their associated Controllers.
class Model extends Module
    constructor: ->
        @propertyListeners = {}
    addChangeListener: (property, listener) ->
        @propertyListeners[property] ?= []
        @propertyListeners[property].push listener

    removeChangeListener: (property, listener) ->
        @propertyListeners[property].remove listener

    # Swaps the old value for the new value; then calls @changed
    set: (property, newVal) =>
        oldVal = @[property]
        @[property] = newVal
        @changed property, oldVal, newVal

    changed: (property, oldVal, newVal) =>
        @validateModel() # TODO: eventually delete this line for production
        console.log "#{property} changed."
        if @propertyListeners[property]?
            listener.inform(property, oldVal, newVal) for listener in @propertyListeners[property]

    validateModel: ->
        throw "@propertyListeners isn't set. Call super()." if !@propertyListeners?

class View
    constructor: (@model) ->
    draw: ->
        throw "Draw not initialized yet"

class Controller extends Module
    constructor: (@model, @view, @propertyChangedCallbacks) ->
        @registerListeningProperties()

    registerListeningProperties: ->
        for prop, callback of @propertyChangedCallbacks
            console.log "#{@constructor.name} adding #{prop} listener to #{@model.constructor.name}"
            @model.addChangeListener prop, this 

    inform: (property, oldVal, newVal) =>
        callback = @propertyChangedCallbacks[property]
        Tools.Args.checkExists callback, "#{constructor.name}'s #{property} change callback"
        callback(oldVal, newVal)

    # Generates a mapping from properties "a" and "bee" 
    # to member function "aChanged", "beeChanged"
    generateCallbackMap: (properties...) ->
        map = {}
        map[prop] = @[prop + "Changed"] for prop in properties
        map
 
##### Actual code #####
class Tools
    @CallbackSet: (property, val) ->
        @[property] = val
    @Args: class Args
        @intMax: 9007199254740992
        @checkExists: (obj, msg="") ->
            throw new Err.BadArg "Doesn't exist: #{msg}" if !(obj?)
        @checkNull: (obj) ->
            throw new Err.BadArg "Object null" if obj == null
        @validateMinMax: (val, min, max, msg) ->
            throw new Err.BadArg "Not within bounds: #{msg}" if !(min <= val <= max)
        @betweenZeroAndIntMax: (amt) ->
            return 0 if amt < 0
            return Tools.Args.intMax if amt > Tools.Args.intMax
        @assert: (bool, throwable) ->
            throw throwable if !bool
        @assertNot: (bool, throwable) ->
            throw throwable if bool

class Err
    @BaseException: class BaseException
        constructor: (@msg) ->
    @Assertion:   class Assertion   extends Err.BaseException
    @State:       class State       extends Err.BaseException
    @BadArg:      class BadArg      extends Err.BaseException
    @NotYourTurn: class NotYourTurn extends Err.BaseException


class Game
    dimensions: []
    # denominator = frames per second
    msPerFrame: 1000/2

    constructor: ->
        @dimensions = [$(window).width()*0.85 , $(window).height()*0.85]
        @viewDimensions = [0,0]
        @canvas = @getCanvas()
        @outputDiv = @getOutputDiv()
        @ctx = @canvas.getContext('2d')

        @time = new Time
        @rootObject = new GameObject(this)
        @bindEvents()
        @drawables = []

    run: ->
        @intervalID = setInterval @main, @msPerFrame
    
    stop: ->
        clearTimeout @intervalID
        @intervalID = null

    # Fat arrow because we call main from a different context 
    main: =>
        @update()
        console.log "delta time:" + @time.deltaTime
        for drawable in @drawables
            drawable.draw()
        # Translate the canvas and paint the objects.
        ###
        @ctx.save()
        @ctx.translate(@viewDimensions[0], @viewDimensions[1])
        @ctx.restore();
        ###

    getCanvas: ->
        canvas = $("#canvas")[0]
        [canvas.width, canvas.height] = @dimensions
        canvas

    getOutputDiv: -> 
        $("#output")

    output: (str) ->
        @outputDiv.html("#{@outputDiv.html()}<br />#{str}")

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
        super()

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
        @log "Starting game with map #{map.name} has started"
        # TODO got to the end of startGame.

    setCurrentPlayer: (player) ->
        @log "Set current player: #{player.name}"
        @set "currentPlayer", player

    setState: (state) ->
        @set "state", state
        
    detectUnitFacingDirection: (player) ->
        #TODO
    
    endTurn: (player = @currentPlayer) ->
        @endTurnValidate player
        nextPlayer = @getNextCurrentPlayer player
        @increaseTurn()
        player.endTurn()
        @map.endTurn(player)
        @startTurn nextPlayer

    increaseTurn: ->
        oldTurnNumber = @turn.turn
        @turn.nextTurn()

        @turn.nextDay() if (@turn.turn % @getNumCurrentPlayers() == 0)

        @setState TurnBasedGame.State.gameOver if @turn.limitReached()

        # TODO: maybe change these to turn objects instead of the turn number
        @changed "turn", oldTurnNumber, @turn.turn

    startTurn: (player) ->
        console.log "Day #{@turn.day}, starting turn for #{player.name}"
        player.startTurn()
        @map.startTurn player
        @setCurrentPlayer player

    changePlayerName: (oldName, newName) ->
        p = @getPlayerByName oldName
        p.setName newName
    
    getPlayerByID: (id) ->
        return p for p in @players when p.id == id 
        throw "Unknown Player ID: #{id}"

    getPlayerByName: (name) ->
        return p for p in @players when p.name == name
        throw "Unknown Player Name: #{name}"

    getCurrentPlayers: -> p for p in @players when p.isActive()
    getNumCurrentPlayers: -> @getCurrentPlayers().length

    getNextCurrentPlayer: (player) ->
        nextPlayer = @getNextPlayer player
        skippedCount = 0
        while !nextPlayer.isActive()
            nextPlayer = @getNextPlayer nextPlayer
            if !@isWithinPlayerBounds ++skippedCount
                throw new Error.AssertionError "All players skipped"
        nextPlayer

    getNextPlayer: (player) ->
        nextPlayerIndex = ((@players.indexOf player)+1) % @players.length
        @players[nextPlayerIndex]
        
    isIdle: -> @state == TurnBasedGame.State.idle
    isStarted: -> @state == TurnBasedGame.State.started
    isGameOver: -> @state == TurnBasedGame.State.gameOver
    isWithinPlayerBounds: (index) -> 0 <= index < @players.length

# Validation

    startGameValidate: (startingPlayer) ->
        throw "Game in illegal state" if @state != TurnBasedGame.State.idle 
        throw "Game in illegal state: Turn limit reached" if @turn.limitReached()
        throw "Game in illegal state: unknown player" if !(@players.contains startingPlayer)
        @playersValidate()
        @map.validate()

    endTurnValidate: (player) ->
        Tools.Args.checkNull player, "Can't end turn with a null player"
        Tools.Args.assert @isStarted(), new Err.State "Game must be started to end a turn!"
        Tools.Args.assertNot @isGameOver(), new Err.State "Can't end turn of a finished Game"
        Tools.Args.checkNull @currentPlayer, "Current player can't be null"

        nextPlayer = @getNextCurrentPlayer @currentPlayer
        Tools.Args.checkNull nextPlayer, "No next player"

        Tools.Args.assert player == @currentPlayer, 
            new Err.NotYourTurn "You aren't the current player, can't end turn!"


    playersValidate: ->
        # number of players must equal map's number of players
        #Tools.Args.assert @players.length == @map.getNumPlayers(), "Incorrect # of players"

        # each player must be unique
        uniquePlayers = []
        uniquePlayers.push p for p in @players when !uniquePlayers.contains p
        Tools.Args.assert @players.length == uniquePlayers.length, 
            "Each player must be unique"

        # no player can be null; no neutral players in player list
        for player in @players
            Tools.Args.checkNull player, "Can't have a null player"
            Tools.Args.assertNot player.isNeutral(), 
                "Can't have a neutral player in player list"

            # compare with others:
            # no same colors
            # no same IDs
            for otherPlayer in @players
                continue if otherPlayer == player 
                Tools.Args.assertNot otherPlayer.color == player.color, 
                    "Two players have the same color"
                Tools.Args.assertNot otherPlayer.id == player.id, 
                    "Two players have same ID"
    
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

class Script
    constructor: ->
        @update = ->

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

    toString: -> "Name: #{@name} ID: #{@id} State: #{@state} Color: #{@color}
        Budget: #{@budget} Team: #{@team} CO: #{@co.getName() if @co?}"
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

# TODO: this @extend may not work right
LocationInterface = 
    canAdd: (locatable) ->
    add: (locatable) ->
    remove: (locatable) -> # TODO: decide if this returns obj/null or true/false
    contains: (locatable) ->
    # i don't need the getters really...
    getLocatables: -> @locatables

    getRow: -> @row
    getCol: -> @col
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
    constructor: (@col, @row, @terrain, @fog = false) ->
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

    toggleFog: ->
        @setFog !@fog

    getLastLocatable: -> 
        size = @locatables.length
        if size == 0 then return null else return @locatables[size-1]
    
    toString: -> "#{@locationString()}, fog: #{@fog}, terrain: #{@terrain}, locatables: #{@locatables}"
    isEven: -> @row%2 == 0
    isOdd: -> @row%2 == 1
    # fill in some LocationInterface functions

class TileView 
    constructor: (model) ->
        @ctx = window.game.ctx
        size = window.tbgame.map.size
        @dimensions = [model.getCol() * size, model.getRow() * size,
            size - 5, size - 5]
        if model.isOdd()
            @dimensions[0] += size/2

        @bounds = [
            @dimensions[0],
            @dimensions[1],
            @dimensions[0] + @dimensions[2],
            @dimensions[1] + @dimensions[3]
        ] # sx, sy, ex, ey

        @setFogColor(model.fog)

    setFogColor: (fog) ->
        @fogColor = if fog then "#FF00FF" else "#000000"

    draw: ->
        @ctx.fillStyle = @fogColor
        @ctx.fillRect.apply @ctx, @dimensions
        @ctx.fillStyle = "#000000"

class TileController extends Controller
    constructor: (model, view) ->
        propertyChangedCallbacks =
            "fog": @fogChange
            "terrain": @terrainChange
        super(model, view, propertyChangedCallbacks) 

    withinViewBounds: (evt) ->
        @view.bounds[SX] <= evt.pageX < @view.bounds[EX] &&
        @view.bounds[SY] <= evt.pageY < @view.bounds[EY]

    reactToEvent: (evt) =>
        switch event.type
            when "mousedown"
                alert "over here!" if @withinViewBounds evt
            when "mouseup"
                @draw = false
            when "mousemove"
                [@dx, @dy] = [event.pageX, event.pageY]
            else
                return false
        true

    reactTo: (clix) =>
        @model.toggleFog()
        window.game.output("(#{@model.row}, #{@model.col}) fog: #{@model.fog}")
        for tile in window.tbgame.map.surroundingTiles @model, 1, 1
            tile.toggleFog()

    getClix: ->
        @clix ||= new Clix(@reactTo).initWithBounds(@view.bounds)

    fogChange: (oldVal, newVal) => 
        console.log "new fog: #{newVal}"
        @view.setFogColor newVal

    terrainChange: (oldVal, newVal) -> 
        console.log "new terrain: #{newVal}"



class Terrain extends Module
    @include PropertyChangeSupport

class MapTools
    @HexDirections:
        "E"  : 0
        "SE" : 1
        "SW" : 2
        "W"  : 3
        "NW" : 4
        "NE" : 5

    @HexDirsEven:
        "E"  : [1,0]
        "W"  : [-1,0]
        "SE" : [0,1]
        "SW" : [-1,1]
        "NW" : [-1,-1]
        "NE" : [0,-1]

    @HexDirsOdd:
        "E"  : [1,0]
        "W"  : [-1,0]
        "SE" : [1,1]
        "SW" : [0,1]
        "NW" : [0,-1]
        "NE" : [1,-1] # what the shit that aint right

    constructor: (@map) ->

    surroundingTiles: (location, minRange, maxRange) ->
        if (!@map.isValid location) || (minRange == 0) || (maxRange == 0)
            return []

        if maxRange == 1
            @adjacentTiles location
        else
            @tilesInRange location, minRange, maxRange

    adjacentTiles: (location) ->
        tiles = []
        for dir, val of MapTools.HexDirections
            tile = @getNeighborTile location, dir
            tiles.push tile if tile != null
        tiles

    # Distance is equal to the greatest of the absolute values of: 
    # + the difference along the x-axis
    # + the difference along the y-axis
    # + the difference of these two differences.
    #       http://3dmdesign.com/development/hexmap-coordinates-the-easy-way

    # TODO: START FROM HERE
    distBetween: (locA, locB) ->
      xDelta = Math.abs(locA.getRow() - locB.getRow())
      yDelta = Math.abs(locA.getCol() - locB.getCol())
      xDelta + yDelta
      # TODO: add the difference of these two differences?



    # TODO: works great for (_, 1, 3) but not (_, 2, 3)
    tilesInRange: (location, minRange, maxRange) ->
        tiles = []
        x = location.getCol()
        y = location.getRow()
        [minCol, maxCol] = [x - maxRange, x + maxRange]

        # Do everything in the original row
        for i in [minCol..maxCol]
            tiles.push (@map.getTile i,y) if (i != x) and (@map.isWithinBounds i, y)

        for yOffset in [minRange..maxRange]
            if (y + yOffset)%2 == 1 then maxCol-- else minCol++
            for i in [minCol..maxCol]
                above = y-yOffset
                below = y+yOffset
                tiles.push (@map.getTile i, below) if (@map.isWithinBounds i, below)
                tiles.push (@map.getTile i, above) if (@map.isWithinBounds i, above)

        tiles



        ###
        tilesToScan = [location]
        tiles = []
        while minRange <= maxRange
            nextTilesToScan = []
            for tile in tilesToScan
                adjacents = @adjacentTiles tile
                nextTilesToScan = _.union nextTilesToScan, 
                tiles = _.union tiles, 
        ###

            
    getNeighborTile: (location, dir) ->
        dirsMap = if location.isEven() then MapTools.HexDirsEven else MapTools.HexDirsOdd
        dirXY = dirsMap[dir] # {1, 0} or something

        [x, y] = [location.getCol() + dirXY[0], location.getRow() + dirXY[1]]
        if @map.isWithinBounds x, y
            @map.getTile x, y
        else
            null

class Map
    constructor: (@name = "", @author = "", @desc = "", @rows, @cols, @size, baseTerrain = "grass") ->
        @tiles = @init()
        @pathFinder = new PathFinder(this)
        @rules = new Rules
        @fill(@rows, @cols, baseTerrain)
        @mapTools = new MapTools(@)
    
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
    surroundingTiles: (location, minRange, maxRange) -> 
        @mapTools.surroundingTiles location, minRange, maxRange

    # TODO
    startTurn: (player) ->

    # TODO
    endTurn: (player) ->


    getTile: (x, y) -> @tiles[x][y]

    setTile: (x, y, tile) ->
        @tiles[x][y] = tile 
    
    fill: (terrain) ->
        for row in [0..@rows-1]
            for col in [0..@cols-1]
                tile = new Tile row, col, terrain #, fog = true
                @setTile row, col, tile

    unitOn: (location) ->
        locatable = location.getLastLocatable()
        if locatable instanceof Unit then return locatable else return null

    structureOn: (location) ->
        terrain = location.terrain
        if terrain instanceof Structure then return terrain else return null

    forEachTile: (func) ->
        for row in @tiles
            for tile in row
                func.call(@,tile)

    getUniquePlayers: ->
        players = {}
        @forEachTile (tile) =>
            unit = @unitOn tile
            structure = @structureOn tile
            if unit != null && !unit.owner.isNeutral()
                players[unit.owner] = true
            if structure != null && !structure.owner.isNeutral()
                players[structure.owner] = true
        
    getNumPlayers: ->
        @getUniquePlayers().length

    # Validation
    validate: -> 
        @forEachTile (tile) ->
            structure = @structureOn tile
            unit = @unitOn tile
            loc = tile.locationString()

            if structure != null
                Tools.Args.checkNull structure.location, "Structure has no location"
                Tools.Args.assert structure.location == tile, "Wrong location for structure"
                Tools.Args.checkNull structure.owner, "Structure on #{loc} is ownerless"

            if unit != null
                # TODO diverged a bit from the original here
                Tools.Args.assert tile.locatables.length == 1, "Wrong # locatables on #{loc}"
                Tools.Args.checkNull unit.location, "Unit has no location"
                Tools.Args.assert unit.location == tile, "Wrong location for structure"
                Tools.Args.checkNull unit.owner, "Unit on #{loc} is ownerless"

    isValid: (location) -> @isLocationInBounds location
    isLocationInBounds: (location) -> 
        location != null and @isWithinBounds location.getRow(), location.getCol()
    isWithinBounds: (col, row) -> (0 <= row < @rows) and (0 <= col < @cols)
    
    initWithOtherMap: (other) ->
        [@name, @author, @desc] = [other.name, other.author, other.desc]
        [@rows, @cols, @size] = [other.rows, other.cols, other.size]
        @tiles = @init()
        @fill (other.getTile 0,0).terrain
        @rules = new Rules().initWithOtherRules other.rules
        # TODO: fog of war?
        # TODO: copyMapData(otherMap)
        # TODO: copyPlayers()
        @

    # Fog of war. A unit is unhidden if:
    # + Member of current player's units
    # + Adjacent to current player's units or structures
    # TODO: perhaps add more? dunno.
    handleUnitHide: (unit, player) ->
        if unit.canHide()
            allied = unit.isAlliedWith player
            adjacentAlly = @hasAdjacentAlly unit.location, player

            # Don't hide if either of these are the case.
            unit.setHidden !(allied || adjacentAlly)

    # TODO
    hasAdjacentAlly: (location, player) -> true

class Unit
class Structure


###
# the Clix system is inspired by Sid Meier's Civilization. As described
# by him: 
"Clix system
InitClix()
AddClix(clix, x, y, dx, dy) (a rect)
GetClix(x, y) will tell you which ClixID you're over.
I really like that. Simple. Does it for 3d units as well.
reinitializes all clixes every frame in his version." 
###

class ClixManager
    constructor: ->
        @reset()
    reset: ->
        @clixes = []
    addClix: (clix) -> 
        console.log @
        @clixes.push clix
    getClix: (x, y) => 
        clix = @clixes.findIf( (clix) => @withinBounds(clix, x, y))
        clix
    withinBounds: (clix, x, y) ->
        clix.startX <= x < clix.endX and
        clix.startY <= y < clix.endY


class Clix
    constructor: (@callback, @startX, @startY, @endX, @endY) ->
    initWithRect: (@startX, @startY, sizeX, sizeY) ->
        [@endX, @endY] = [@startX + sizeX, @startY + sizeY]
        @
    initWithBounds: (bounds) ->
        [@startX, @startY, @endX, @endY] = [bounds[SX], bounds[SY], bounds[EX], bounds[EY]]
        @

class TurnBasedGameView extends View
    constructor: (model) ->
        super(model) # required?

class TurnBasedGameController extends Controller
    constructor: (model, view) ->
        callbacks = @generateCallbackMap "currentPlayer", "turn" # equivalent
        super(model, view, callbacks)
    currentPlayerChanged: (oldVal, newVal) =>
        @log "Player changed to #{newVal.name or "none"}"
    turnChanged: (oldVal, newVal) =>
        @log "Turn changed to #{newVal}"
    generateClix: ->


@loaded = (map)->
    console.log "loaded #{map}!"
    window.map = map
    playerMax = new Player "Max", 1, "#880088", 1, false, null, 20
    playerThem = new Player "Them", 2, "#008800", 2, false, null, 20

    tbgame = new TurnBasedGame(window.map, [playerMax, playerThem], 5)
    tbgameView = new TurnBasedGameView(tbgame)
    tbgameController = new TurnBasedGameController(tbgame, tbgameView)
    window.tbgame = tbgame
    tbgame.startGame tbgame.players[0]
    tbgame.endTurn()
    tbgame.endTurn()

    # TODO: Playing around with Clix system
    # TODO: Organize Clix by Z-order?
    clixManager = new ClixManager
    window.clixManager = clixManager

    $(canvas).on 'mousedown', (evt) ->
        clix = clixManager.getClix evt.pageX, evt.pageY
        console.log "Is there a Clix here? #{clix?}"
        clix?.callback.call(clix, evt)

    controllers = []
    tbgame.map.forEachTile (tile) =>
        tileView = new TileView(tile)
        tileController = new TileController(tile, tileView)
        controllers.push tileController
        clix = tileController.getClix()
        console.log "clix: "
        console.log clix
        clixManager.addClix clix

    for controller in controllers
        window.game.drawables.push controller.view
        controller.view.draw()

    surr = tbgame.map.surroundingTiles tbgame.map.getTile(4,4), 1, 3
    for tile in surr
        tile.setFog true
    window.game.run()

$ ->
    window.game = new Game

    $(canvas).on 'mousedown', (e) => 
        game.stop() if e.which == 3

    Map.loadMapFromJson 'maps/basic.json', (map) => 
        window.loaded(map)

