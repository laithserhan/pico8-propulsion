local bumpWorld
local entities
local bullets
local switches
local cameraShake
local locks
local GRAVITY = 0.25

local Entity = Object:extend()

function Entity:new(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    bumpWorld:add(self, self.x, self.y, self.width, self.height)
    self.isDestroyed = false
end

function Entity:getPlayerCollisionType()
    return 'slide'
end

function Entity:getBulletCollisionType()
    return self:getPlayerCollisionType()
end

function Entity:update()
    --
end

function Entity:draw()
    --
end

function Entity:destroy()
    bumpWorld:remove(self, self.y, self.y, self.width, self.height)
    self.isDestroyed = true
end


local SWITCH_COLORS = {
    RED = 8,
}

local Switch = Entity:extend()

function Switch:new(x, y, color)
    Switch.super.new(self, x, y, 8, 8)
    self.color = color
    self.isDisabled = false
end

function Switch:draw()
    local colorCode = self.color
    if self.isDisabled then
        colorCode = 6
    end
    circfill(self.x + 4, self.y + 4, 4, colorCode)
end

function Switch:getPlayerCollisionType()
    return 'cross'
end

function Switch:getBulletCollisionType()
    return 'cross'
end

local Lock = Entity:extend()

function Lock:new(x, y)
    Switch.super.new(self, x, y, 8, 8)
    self.isDisabled = false
end

function Lock:draw()
    local colorCode = 14
    if self.isDisabled then
        colorCode = 13
    end
    circfill(self.x + 4, self.y + 4, 4, colorCode)
end

function Lock:getPlayerCollisionType()
    return 'cross'
end

function Lock:getBulletCollisionType()
    return 'cross'
end


local Wall = Entity:extend()

function Wall:draw()
    rectfill(self.x, self.y, self.x + self.width - 1, self.y + self.height - 1, 7)
end


local Fence = Wall:extend()

function Fence:getBulletCollisionType()
    return nil
end

function Fence:draw()
    rectfill(self.x, self.y, self.x + self.width - 1, self.y + self.height - 1, 5)
end


local SwitchWall = Wall:extend()

function SwitchWall:new(x, y, width, height, color)
    SwitchWall.super.new(self, x, y, width, height)
    self.color = color
end

function SwitchWall:isDisabled()
    for switch in all(switches) do
        if switch.isDisabled and switch.color == self.color then
            return true
        end
    end
    return false
end

function SwitchWall:getPlayerCollisionType()
    if self:isDisabled() then
        return nil
    end
    return 'slide'
end

function SwitchWall:draw()
    if not self:isDisabled() then
        rectfill(self.x, self.y, self.x + self.width - 1, self.y + self.height - 1, self.color)
    end
end


local Bullet = Entity:extend()
Bullet.SPEED = 1
Bullet.MAX_BOUNCES = 4
Bullet.DEATH_TIMER_MAX = 30
Bullet.TRAIL_LENGTH = 8

function Bullet:new(x, y, angle)
    Bullet.super.new(self, x, y, 4, 4)
    self.velX = cos(angle)
    self.velY = sin(angle)
    self.bounces = 0
    self.lastPositions = {}
    self.deathTimer = 0
end

function Bullet:destroy()
    Bullet.super.destroy(self)
    del(bullets, self)
end

function Bullet:getPlayerCollisionType()
    return nil
end

function Bullet:moveFilter(other)
    return other:getBulletCollisionType()
end

function Bullet:getBulletCollisionType()
    -- Don't collide with other bullets
    return nil
end

function Bullet:update()
    if self.bounces < Bullet.MAX_BOUNCES then
        local goalX = self.x + Bullet.SPEED * self.velX
        local goalY = self.y + Bullet.SPEED * self.velY
        self.x, self.y, collisions, _ = bumpWorld:move(self, goalX, goalY, self.moveFilter)
        for _, collision in ipairs(collisions) do
            if collision.other:is(Wall) then
                self.bounces = self.bounces + 1
                if collision.normal.y ~= 0 then
                    self.velY = self.velY * -1
                end
                if collision.normal.x ~= 0 then
                    self.velX = self.velX * -1
                end
            end
            if collision.other:is(Switch) and not collision.other.isDisabled then
                collision.other.isDisabled = true
            end
            if collision.other:is(Lock) and not collision.other.isDisabled then
                collision.other.isDisabled = true
            end
        end
        -- Keep track of previous positions for a trail effect, but no more than necessary.
        add(self.lastPositions, { x = self.x, y = self.y })
        while #self.lastPositions > Bullet.TRAIL_LENGTH do
            del(self.lastPositions, self.lastPositions[1])
        end
    else
        self.deathTimer = self.deathTimer + 1
        if self.deathTimer >= Bullet.DEATH_TIMER_MAX then
            self:destroy()
        end
        -- Keep updating the trail, just don't add anything new.
        if #self.lastPositions > 0 then
            del(self.lastPositions, self.lastPositions[1])
        end
    end
end

function Bullet:draw()
    for i=1,Bullet.TRAIL_LENGTH,2 do
        if i <= #self.lastPositions then
            local lastPosition = self.lastPositions[#self.lastPositions - i + 1]
            circfill(
                lastPosition.x + 2,
                lastPosition.y + 2,
                self.width/4,
                flr(rnd(16))
            )
        end
    end
    if self.bounces < Bullet.MAX_BOUNCES then
        circfill(
            self.x + 2,
            self.y + 2,
            self.width/2,
            flr(rnd(16))
        )
    else
        for i=1,4 do
            local angle = i/4 + 0.4 * self.deathTimer/Bullet.DEATH_TIMER_MAX
            circfill(
                self.x + 2 + 32 * cos(angle) * self.deathTimer/Bullet.DEATH_TIMER_MAX,
                self.y + 2 + 32 * sin(angle) * self.deathTimer/Bullet.DEATH_TIMER_MAX,
                self.width/4,
                flr(rnd(16))
            )
        end
    end
end

local Player = Entity:extend()
Player.SPEED = 1

function Player:new(x, y, bullets)
    Player.super.new(self, x, y, 8, 8)
    self.bullets = bullets
    self.velY = 0
    self.onGround = false
    self.angle = 0
end

function Player:moveFilter(other)
    return other:getPlayerCollisionType()
end

function Player:getBulletCollisionType()
    return nil
end

function Player:update()
    local goalX = self.x
    local goalY = self.y

    if btn(5) then
        if btn(0) then
            self.angle = self.angle + 0.005
        elseif btn(1) then
            self.angle = self.angle - 0.005
        end
        self.angle = self.angle % 1
    else
        if btn(0) then
            goalX = goalX - Player.SPEED
        elseif btn(1) then
            goalX = goalX + Player.SPEED
        end
    end

    if btnp(2) then
        if self.onGround then
            self.velY = -4
        end
    end

    if btnp(4) and self.bullets > 0 then
        add(bullets, Bullet(self.x + 3, self.y + 3, self.angle))
        cameraShake = 1
        self.bullets = self.bullets - 1
    end

    goalY = goalY + self.velY
    self.velY = self.velY + GRAVITY

    local collisions
    -- Attempt to move player to goal position.
    self.x, self.y, collisions, _ = bumpWorld:move(self, goalX, goalY, self.moveFilter)
    -- Consider player to be on ground if not moving up (i.e. jumping) or
    -- not moving down beyond 1 pixel per frame (gives player a few frames to
    -- jump after falling off edge)
    if self.velY < 0 or self.velY >= 1 then
        self.onGround = false
    end

    -- Check collisions from player movement. We can ignore the wall collisions (except for
    -- controlling gravity) since bump has already handled them, but coin collisions are
    -- still important.
    for _, collision in ipairs(collisions) do
        if collision.other:is(Wall) then
            -- Player has either landed or bonked wall above.
            if collision.normal.y ~= 0 then
                self.velY = 0
            end
            -- Player has landed!
            if collision.normal.y == -1 then
                self.onGround = true
            end
        end
    end
end

function Player:draw()
    local colorCode = 12
    if btn(5) then
        colorCode = 10
    end
    rectfill(self.x, self.y, self.x + self.width - 1, self.y + self.height - 1, 4)
    line(
        self.x + 4,
        self.y + 4,
        self.x + 4 + 16 * cos(self.angle),
        self.y + 4 + 16 * sin(self.angle),
        colorCode
    )
end

-- START MAIN
local player
local WALL_TILES = {
    1, 2, 3, 4, 5, 6,
    18, 19, 20, 21,
}

local function isLevelComplete()
    for lock in all(locks) do
        if not lock.isDisabled then
            return false
        end
    end
    return true
end

local function resetLevel()
    bumpWorld = bump.newWorld(8)
    player = Player(32, 32, 4)
    entities = {}
    switches = {}
    locks = {}
    add(entities, Wall(16, 48, 32, 8))
    add(entities, Wall(8, 80, 80, 8))
    add(entities, Wall(64, 0, 8, 48))
    add(entities, Wall(0, 0, 128, 8))
    add(entities, Wall(0, 0, 8, 128))
    add(entities, Wall(120, 0, 8, 128))
    add(entities, Wall(0, 120, 128, 8))
    add(entities, SwitchWall(56, 56, 16, 16, SWITCH_COLORS.RED))
    add(switches, Switch(16, 16, SWITCH_COLORS.RED))
    add(entities, Fence(80, 64, 64, 8))
    add(locks, Lock(96, 32))
    bullets = {}
end

function _init()
    -- Disable button repeating
    poke(0x5f5c, 255)
    cameraShake = 0
    resetLevel()
end

function updateSelf(self)
    self:update()
end

function _update60()
    if not isLevelComplete() then
        player:update()
    end
    foreach(entities, updateSelf)
    foreach(bullets, function(bullet)
        if bullet.isDestroyed then
            del(bullets, bullet)
        else
            bullet:update()
        end
    end)
    if cameraShake > 0 then
        cameraShake = cameraShake - 0.1
    else
        cameraShake = 0
    end

    if #bullets == 0 and player.bullets == 0 then
        resetLevel()
    end
end

function drawSelf(self)
    self:draw()
end

function _draw()
    cls()
    camera(cameraShake * (rnd(4) - 2), cameraShake * (rnd(4) - 2))
    foreach(entities, drawSelf)
    foreach(switches, drawSelf)
    foreach(locks, drawSelf)
    foreach(bullets, drawSelf)
    player:draw()
    camera()
    print('bullets: '..tostring(player.bullets), 4, 4, 3)
    if isLevelComplete() then
        print('level complete', 4, 32, 10)
    end
end
-- END MAIN
