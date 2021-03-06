//
//  Entities.swift
//  Asteroids
//
//  Created by Sean Hickey on 12/6/16.
//  Copyright © 2016 Sean Hickey. All rights reserved.
//

import Darwin
import simd

/****************************************
 * Renderable Struct for Vertex Data
 ****************************************/

typealias EntityId = U64
let InvalidEntityId = U64.max

typealias RenderableId = U64

/*= BEGIN_REFSTRUCT =*/
struct Renderable {
    var vertexCount : Int /*= GETSET =*/
    var vertexBuffer : RawPtr /*= GETSET =*/
    
    var boundingBox : Rect /*= GETSET =*/
    var boundingBoxBuffer : RawPtr /*= GETSET =*/
}
/*= END_REFSTRUCT =*/


func createRenderable(_ zone: MemoryZoneRef, _ gameState: GameStateRef, _ gameMemory: GameMemory, _ vertices: [Float]) -> RenderableRef {
    
    // TODO : This function assumes a vertex buffer layout of [x, y, z, w, r, g, b, a]
    assert(vertices.count % 8 == 0)
    
    let renderablePtr = allocateTypeFromZone(zone, Renderable.self)
    let renderable = RenderableRef(renderablePtr)
    
    renderable.vertexBuffer = gameMemory.platformCreateVertexBuffer!(vertices)
    renderable.vertexCount = vertices.count / 8
    
    // Compute bounding box
    var minX : Float = 0.0
    var maxX : Float = 0.0
    var minY : Float = 0.0
    var maxY : Float = 0.0
    for (i, v) in vertices.enumerated() {
        if i % 8 == 0 {
            if v < minX {
                minX = v
            }
            else if v > maxX {
                maxX = v
            }
        }
        else if i % 8 == 1 {
            if v < minY {
                minY = v
            }
            else if v > maxY {
                maxY = v
            }
        }
    }
    
    renderable.boundingBox = Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY)
    
    let boundingBoxVerts : [Float] = [
        minX, minY, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        minX, maxY, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        maxX, maxY, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        maxX, minY, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        minX, minY, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
    ]
    renderable.boundingBoxBuffer = gameMemory.platformCreateVertexBuffer!(boundingBoxVerts)
    
    return renderable
}

/****************************************
 * Entity Base
 ****************************************/

/*= BEGIN_REFSTRUCT =*/
struct EntityBase {
    // An Entity ID is unique at any given time, but can be reused once the entity is destroyed
    var id : EntityId /*= GETSET =*/
    var renderableId : RenderableId /*= GETSET =*/
    
    // Position and Velocity
    var p  : Vec2 /*= GETSET =*/
    var dP : Vec2 /*= GETSET =*/
    
    // Rotation and Angular Velocity
    var rot  : Float /*= GETSET =*/
    var dRot : Float /*= GETSET =*/
    
    var scale : Float /*= GETSET =*/
}
/*= END_REFSTRUCT =*/

protocol Entity {
    var base : EntityBaseRef { get set }
    
    // Entity Base Properties
    var id : EntityId { get set }
    var renderableId : RenderableId { get }
    var p  : Vec2 { get set }
    var dP : Vec2 { get set }
    var rot  : Float { get set }
    var dRot : Float { get set }
    var scale : Float { get set }
}

extension Entity {
    var id : EntityId { get { return self.base.id } set(val) { self.base.id = val} }
    var renderableId : RenderableId { get { return base.renderableId } }
    
    var p  : Vec2 { get { return base.p } set(val) { base.p = val} }
    var dP : Vec2 { get { return base.dP } set(val) { base.dP = val} }
    
    var rot  : Float { get { return base.rot } set(val) { base.rot = val} }
    var dRot : Float { get { return base.dRot } set(val) { base.dRot = val} }
    
    var scale : Float { get { return base.scale } set(val) { base.scale = val} }
}

class EntityRef<T: Entity> : Ref<T>, Entity {
    var base : EntityBaseRef { get { return self.ptr.pointee.base } set(val) { self.ptr.pointee.base = val }}
}

/****************************************
 * Entity Functions
 ****************************************/


func createEntityBase(_ zone: MemoryZoneRef, _ gameState: GameStateRef) -> EntityBaseRef {
    let (entityBasePtr, locator) = bucketArrayNewElement(gameState.world.entities)
    let entityBase = EntityBaseRef(entityBasePtr)
    entityBase.scale = 1.0
    entityBase.id = (locator.bucket * 64) + locator.index // TODO: This assumes bucket sizes of 64
    return entityBase
}

func destroyEntity(_ gameState: GameStateRef, _ entity: Entity) {
    let locator : BucketLocator = (entity.id / 64, entity.id % 64)
    bucketArrayRemove(gameState.world.entities, locator)
}

func entityTransform(_ entity: Entity) -> Transform {
    return translateTransform(entity.p.x, entity.p.y) * rotateTransform(entity.rot) * scaleTransform(entity.scale, entity.scale)
}

/****************************************
 * Ship
 ****************************************/


/*= BEGIN_REFSTRUCT =*/
struct Ship : Entity {
    var base : EntityBaseRef /*= GETSET =*/
    var alive : Bool /*= GETSET =*/
}
/*= END_REFSTRUCT =*/

func createShip(_ gameMemory: GameMemory, _ zone: MemoryZoneRef, _ gameState: GameStateRef) -> ShipRef {
    let shipPtr = allocateTypeFromZone(zone, Ship.self)
    var ship = ShipRef(shipPtr)
    
    let entityBase = createEntityBase(zone, gameState)
    entityBase.renderableId = Ship.renderableId
    ship.base = entityBase
    
    ship.p = Vec2()
    ship.dP = Vec2()
    ship.alive = true
    
    if gameState.renderables[Ship.renderableId] == nil {
        let verts : [Float] = [
            0.0,  0.7, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0,
            0.5, -0.7, 0.0, 1.0, 0.7, 1.0, 0.4, 1.0,
            -0.5, -0.7, 0.0, 1.0, 0.7, 1.0, 0.4, 1.0
        ]
        let renderable = createRenderable(zone, gameState, gameMemory, verts)
        gameState.renderables[Ship.renderableId] = renderable
    }
    
    return ship
}


/****************************************
 * World
 ****************************************/

func createWorld(_ zone: MemoryZoneRef) -> WorldRef {
    let worldPtr = allocateTypeFromZone(zone, World.self)
    return WorldRef(worldPtr)
}


/****************************************
 * Asteroid
 ****************************************/

/*= BEGIN_REFSTRUCT =*/
struct Asteroid : Entity {
    var base : EntityBaseRef /*= GETSET =*/
    var asteroidLocator : BucketLocator /*= GETSET =*/
    
    enum AsteroidSize {
        case small
        case medium
        case large
    }
    
    var size : Asteroid.AsteroidSize /*= GETSET =*/
}
/*= END_REFSTRUCT =*/

func createAsteroid(_ gameMemory: GameMemory, _ zone: MemoryZoneRef, _ gameState: GameStateRef, _ size: Asteroid.AsteroidSize) -> AsteroidRef {
    let (asteroidPtr, locator) = bucketArrayNewElement(gameState.world.asteroids)
    var asteroid = AsteroidRef(asteroidPtr)
    asteroid.asteroidLocator = locator
    
    let entityBase = createEntityBase(zone, gameState)
    entityBase.renderableId = Asteroid.renderableId
    asteroid.base = entityBase
    
    asteroid.size = size
    asteroid.scale = scaleForAsteroidSize(size)
    
    
    if gameState.renderables[Asteroid.renderableId] == nil {
        let verts : [Float] = [
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            1.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos((FLOAT_TWO_PI) / 6.0), sin((FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos((FLOAT_TWO_PI) / 6.0), sin((FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(2.0 * (FLOAT_TWO_PI) / 6.0), sin(2.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(2.0 * (FLOAT_TWO_PI) / 6.0), sin(2.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            -1.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            -1.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(4.0 * (FLOAT_TWO_PI) / 6.0), sin(4.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(4.0 * (FLOAT_TWO_PI) / 6.0), sin(4.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(5.0 * (FLOAT_TWO_PI) / 6.0), sin(5.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            
            0.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            cos(5.0 * (FLOAT_TWO_PI) / 6.0), sin(5.0 * (FLOAT_TWO_PI) / 6.0), 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,
            1.0,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0
        ]
        let renderable = createRenderable(zone, gameState, gameMemory, verts)
        gameState.renderables[Asteroid.renderableId] = renderable
    }
    
    return asteroid
}

func scaleForAsteroidSize(_ size: Asteroid.AsteroidSize) -> Float {
    switch size {
    case .large:
        return 2.0
    case .medium:
        return 1.5
    case .small:
        return 1.0
    }
}

func randomizeAsteroidLocationInWorld(_ asteroidRef: AsteroidRef, _ world: WorldRef) {
    var asteroid = asteroidRef
    
    var location = Vec2()
    repeat {
        location.x = randomInRange(-world.size.w / 2.0, world.size.w / 2.0)
        location.y = randomInRange(-world.size.w / 2.0, world.size.w / 2.0)
    } while distance(location, world.ship.p) < (scaleForAsteroidSize(.large) * 2.0) // Prevent an asteroid from spawning right on top of the ship
    asteroid.p = location
}

func randomizeAsteroidRotationAndVelocity(_ asteroidRef: AsteroidRef) {
    var asteroid = asteroidRef
    asteroid.rot = randomInRange(-FLOAT_PI, FLOAT_PI)
    asteroid.dRot = randomInRange(FLOAT_TWO_PI / 15.0, FLOAT_TWO_PI / 10.0)
    var velocityScale : Float = 1.2
    if asteroid.size == .medium {
        velocityScale = 2.4
    }
    else if asteroid.size == .small {
        velocityScale = 3.6
    }
    asteroid.dP.x = randomInRange(-velocityScale, velocityScale)
    asteroid.dP.y = randomInRange(-velocityScale, velocityScale)
}


/****************************************
 * Laser
 ****************************************/

/*= BEGIN_REFSTRUCT =*/
struct Laser : Entity {
    var base : EntityBaseRef /*= GETSET =*/
    
    var timeAlive : Float /*= GETSET =*/
    var lifetime : Float /*= GETSET =*/
    var alive : Bool /*= GETSET =*/
}
/*= END_REFSTRUCT =*/

func createLaser(_ gameMemory: GameMemory, _ zone: MemoryZoneRef, _ gameState: GameStateRef, _ ship: ShipRef) -> LaserRef {
    let laserPtr = allocateTypeFromZone(zone, Laser.self)
    var laser = LaserRef(laserPtr)
    
    let entityBase = createEntityBase(zone, gameState)
    entityBase.renderableId = Laser.renderableId
    laser.base = entityBase
    
    laser.p = ship.p

    laser.dP.x = sin(ship.rot) * 12.0
    laser.dP.y = cos(ship.rot) * 12.0
    
    laser.timeAlive = 0.0
    laser.lifetime = 1.0
    laser.alive = true
    
    if gameState.renderables[Laser.renderableId] == nil {
        let verts : [Float] = [
            1.0,  1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            -1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            
            1.0,  1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            -1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0
        ]
        let renderable = createRenderable(zone, gameState, gameMemory, verts)
        gameState.renderables[Laser.renderableId] = renderable
    }
    
    return laser
}



func rotateEntity(_ entity: Entity, _ radians: Float) {
    var ref = entity
    ref.rot += radians
    ref.rot = normalizeToRange(entity.rot, Float(-M_PI), Float(M_PI))
}
