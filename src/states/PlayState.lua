--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Manav Sinha
    manavsinha111@gmail.com

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.level = params.level
    self.powerUp = PowerUp()
    self.recoverPoints = 5000
    self.serveReset = false
    self.powerUpActive = false
    self.keyPowerUp = false
    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)
    self.currentPowerUp = 0
    self.enlargePaddlePoints = params.enlargePaddlePoints
end

function PlayState:update(dt)

    -- change size of paddle after each 500 points
    if self.score  >= self.enlargePaddlePoints then
        self.paddle.size = math.min(4, self.paddle.size + 1 )
        self.enlargePaddlePoints = 2 * self.enlargePaddlePoints
    end

    if math.random(1,2000) == 1314 and self.powerUpActive==false and self.keyPowerUp==false then
        self.powerUp.spawn = true
    end

    if gLockedBrickExist and #self.bricks < 10 and self.powerUpActive == false 
        and self.powerUp.spawn == false and self.keyPowerUp == false 
         and self.currentPowerUp < 10 then
        self.powerUp.spawn = true
    end 

    if self.powerUp.spawn then
        self.powerUp:update(dt)
    end
 
    if self.powerUpActive == false and self.keyPowerUp == false then
        if self.powerUp:collides(self.paddle) then
            if gLockedBrickExist then
                self.keyPowerUp = true
            else 
                self.powerUpActive = true
                self.powerUp.powerUpBalls[1].x =self.paddle.x +4
                self.powerUp.powerUpBalls[2].x =self.paddle.x +self.paddle.width -4
                self.powerUp.powerUpBalls[1].y =self.paddle.y + self.paddle.height 
                self.powerUp.powerUpBalls[2].y =self.paddle.y + self.paddle.height
                self.powerUp.spawn = false
                self.currentPowerUp = 1 
                self.powerUp.y = -10
            end
        end
    end

    if self.keyPowerUp then 
        if self.powerUp:collides(self.paddle) then
            gLockPowerUp = true
            self.keyPowerUp = false
            self.currentPowerUp = 10
            self.powerUp.y = -10
        end
    end

    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.ball:update(dt)

    -- update postion of powerUpBalls if active
    if self.powerUpActive then
        for k,ball in pairs(self.powerUp.powerUpBalls) do
            ball:update(dt)
        end
    end

    if self.ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        self.ball.y = self.paddle.y - 8
        self.ball.dy = -self.ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

        -- if we hit the paddle on its left side while moving left...
        if self.ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
            self.ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.ball.x))
        
        -- else if we hit the paddle on its right side while moving right...
        elseif self.ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
            self.ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.ball.x))
        end

        gSounds['paddle-hit']:play()
    end

    -- check whether powerUpBalls hit the paddle
    if self.powerUpActive then
        self.powerUp:paddleHit(self.paddle)
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        -- only check collision if we're in play
        if brick.inPlay and (self.ball:collides(brick) or (self.powerUpActive and( 
                            self.powerUp.powerUpBalls[1]:collides(brick) or 
                            self.powerUp.powerUpBalls[2]:collides(brick)))) then
            if brick.color < 6 then 
                -- add to score 
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
            elseif brick.color == 6 and gLockPowerUp then
                self.score = self.score + 5000                
            end

            -- trigger the brick's hit function, which removes it from play
            brick:hit()

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                -- play recover sound effect
                gSounds['recover']:play()
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.ball,
                    recoverPoints = self.recoverPoints,
                    enlargePaddlePoints =self.enlargePaddlePoints
                })
            end

            if self.ball:collides(brick) then

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if self.ball.x + 2 < brick.x and self.ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.ball.dx = -self.ball.dx
                    self.ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif self.ball.x + 6 > brick.x + brick.width and self.ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.ball.dx = -self.ball.dx
                    self.ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif self.ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    self.ball.dy = -self.ball.dy
                    self.ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    self.ball.dy = -self.ball.dy
                    self.ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(self.ball.dy) < 150 then
                    self.ball.dy = self.ball.dy * 1.02
                end
            
            end
            
            if self.powerUpActive and (self.powerUp.powerUpBalls[1]:collides(brick) 
                                or self.powerUp.powerUpBalls[2]:collides(brick)) then
                self.powerUp:updateBall(brick)
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end

    if self.powerUpActive then
        self.serveReset = self.ball:isOutOfBound() and self.powerUp.powerUpBalls[1]:isOutOfBound()
                            and self.powerUp.powerUpBalls[2]:isOutOfBound()
    else
        self.serveReset = self.ball:isOutOfBound()
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if self.serveReset then
        self.health = self.health - 1

        gLockPowerUp = false
        --decrease size of paddle on losing health
        self.paddle.size = math.max(1,self.paddle.size-1)

        self.powerUpActive = false
        self.currentPowerUp = 0

        gSounds['hurt']:play()

        if self.health == 0 then
            gLockedBrickExist = false
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            self.powerUp.spawn = false
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints,
                enlargePaddlePoints = self.enlargePaddlePoints
            })
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    self.ball:render()

    if self.powerUpActive then
        for k,ball in pairs(self.powerUp.powerUpBalls) do
            ball:render()
        end
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
    self.powerUp:render()
    self:displayPowerUp()
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end
    return true
end

function PlayState:displayPowerUp()
    if self.currentPowerUp == 1 then
        love.graphics.draw(gTextures['main'],self.powerUp.icon[1],VIRTUAL_WIDTH - 120,4)
    elseif self.currentPowerUp == 10 then
        love.graphics.draw(gTextures['main'],self.powerUp.lockPowerUpIcon,VIRTUAL_WIDTH-140,4)
    end
end