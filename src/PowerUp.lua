PowerUp = Class{}

gLockPowerUp = false

function PowerUp:init()
    self.spawn = false
    self.icon = GeneratePowerUp(gTextures['main'])
    self.x = VIRTUAL_WIDTH/2 - (1/math.random(4,6)) * (VIRTUAL_WIDTH/2)
    self.y = 0
    self.dy = 10
    self.counter = 0

    self.powerUpBalls = {
        [1] = Ball(2),
        [2] = Ball(4)
    }
    for k,ball in pairs(self.powerUpBalls) do
        ball.dx = math.random(-200,200)
        ball.dy = math.random(-50,-60)
    end

    self.lockPowerUpIcon = self.icon[10]    
end

function PowerUp:update(dt)
    if self.spawn then
        self.y = self.y + self.dy * dt
    end
end

function PowerUp:paddleHit(paddle)
    for i, ball in pairs(self.powerUpBalls) do
        if ball:collides(paddle) then 
            ball.y = paddle.y - ball.height
            ball.dy = - ball.dy

            if ball.x < paddle.x + paddle.width/2 and paddle.dx < 0 then
                ball.dx = -50 + -(8 * (paddle.x + paddle.width/2 - ball.x))
            elseif ball.x > paddle.x+ paddle.width/2 and paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(paddle.x + paddle.width/2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end
end

function PowerUp:collides(target)
    if self.y + 16 > target.y  and target.x < self.x  and self.x < target.x + target.width then
        self.spawn = false
        return true
    end
end  


function PowerUp:render()
    if self.spawn and not gLockedBrickExist then
        love.graphics.draw(gTextures['main'],self.icon[1],self.x,self.y)
    elseif self.spawn and gLockedBrickExist then
        love.graphics.draw(gTextures['main'],self.lockPowerUpIcon,self.x,self.y)
    end
end

function PowerUp:updateBall(brick)
    for i, ball in pairs(self.powerUpBalls) do
        if ball:collides(brick) then
            if ball.x + 2 < brick.x and ball.dx > 0 then
                ball.dx = -ball.dx
                ball.x = brick.x - ball.width
            elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                ball.dx = -ball.dx
                ball.x = brick.x + brick.width
            elseif ball.y < brick.y and ball.dy > 0 then
                ball.dy = - ball.dy
                ball.y = brick.y - ball.height
            else 
                ball.y = brick.y + brick.width
                ball.dy = -ball.dy    
            end
            if math.abs(ball.dy) < 150 then 
                ball.dy = ball.dy * 1.02
            end
        end
    end
end   
