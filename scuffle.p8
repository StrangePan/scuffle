pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- utils

function ternary(cond, x, y)
  if (cond) return x
  return y
end

function sort(tbl, comp)
  -- insertion sort
  if comp == nil
  then
    comp = function(x, y)
      return x > y
    end
  end
  for i=1,#tbl
  do
    local j = i
    while j > 1 and 
          comp(tbl[j-1], tbl[j])
    do
      tbl[j],tbl[j-1] = tbl[j-1],tbl[j]
      j = j - 1
    end
  end
end

-- math helpers

-- is x divisible by d
function divby(d, x)
  return x % d == 0
end

-- sin but -0.5 to 0.5
function nsin(t)
  return sin(t) - 0.5
end

function sign(x)
  if (x < 0) return -1
  return 1
end

function clamp(x, xmin, xmax)
  if (x < xmin) return xmin
  if (x > xmax) return xmax
  return x
end

function in_range(x, xmin, xmax)
  return x >= xmin and x <= xmax
end

function wrap_idx(i, size)
  return i % size + 1
end
  
function rnd_in(tbl)
  return tbl[flr(rnd(#tbl)) + 1]
end

-- push |x| towards target |t|
-- by distance |d|
function push_towards(x, t, d)
  d = abs(d)
  if (abs(t - x) <= d) return t
  if (t < x) return x - d
  return x + d
end

-- class helpers (thanks dan!)

local class = {}

function class.build(superclass)
  local class = {}
  class.__index = class
  class._init = function() end

  local mt = {}
  mt.__call = function(
      self, ...)
    local instance = (
        setmetatable({}, self))
    instance:_init(...)
    return instance
  end

  if superclass then
    mt.__index = superclass
    mt.__metatable = superclass
  end

  return setmetatable(class, mt)
end

-- vector

vec = class.build()

function vec:_init(x, y)
  if type(x) == "table"
  then
    -- copy ctor
    self.x=x.x
    self.y=x.y
  else
    -- value ctor
    self.x=x
    self.y=y
  end
end

-- makes a binary operator for
-- the vector that can take
-- either two vectors or
-- a vector and a number
function _vec_binary_op(op)
  return function(v1, v2)
    if type(v1) == "table" and
       type(v2) == "table"
    then
      -- two vectors
      return vec(op(v1.x, v2.x),
                 op(v1.y, v2.y))
    end

    -- one of the arguments
    -- should be numeric
    if type(v1) == "table"
    then
      -- v2 is numeric
      return vec(op(v1.x, v2),
                 op(v1.y, v2))
    end
  
    -- v1 is numeric
    -- preserving the order of 
    -- operations is important
    return vec(op(v1, v2.x),
               op(v1, v2.y))
  end
end

vec.__add = _vec_binary_op(
    function(x,y) return x+y end)

vec.__sub = _vec_binary_op(
    function(x,y) return x-y end)

vec.__mul = _vec_binary_op(
    function(x,y) return x*y end)

vec.__div = _vec_binary_op(
    function(x,y) return x/y end)

vec.__pow = _vec_binary_op(
    function(x,y) return x^y end)

vec.__unm =
    function(v)
      return vec(-v.x, -v.y)
    end

vec.__eq =
    function(v1, v2)
      return v1.x == v2.x and
             v1.y == v2.y
    end

function vec:mag()
  return sqrt(self:sqr_mag())
end

function vec:sqr_mag()
  return self.x * self.x +
         self.y * self.y
end

function vec:normalized()
  local mag = self:mag()
  if (mag == 0) return vec(0, 0)
  return self / self:mag()
end

function vec:min(v)
  return vec(
      min(self.x, v.x),
      min(self.y, v.y))
end

function vec:max(v)
  return vec(
      max(self.x, v.x),
      max(self.y, v.y))
end

function vec:clamp(vmin, vmax)
  return vec(
      clamp(self.x, vmin.x,
            vmax.x),
      clamp(self.y, vmin.y,
            vmax.y))
end

-- push a vector towards target
-- |t| by delta |d|
function vec:push_towards(t, d)
  if type(d) == "table"
  then
    -- separate x and y deltas
    return vec(
        push_towards(self.x,
                     t.x, d.x),
        push_towards(self.y,
                     t.y, d.y))
  end
  
  local direc = t - self
  local dvec =
      direc:normalized() * d
  
  return vec(
      push_towards(self.x, t.x,
                   dvec.x),
      push_towards(self.y, t.y,
                   dvec.y))
end

-- table helpers

function addall(xs, ys)
  for y in all(ys)
  do
    add(xs, y)
  end
end

-- random helpers

function rndbool()
  return rnd(100) >= 50
end

-- hitbox

hbox = class.build()

function hbox:_init(pos, size)
  self.pos = vec(pos)
  self.size = vec(size)
end

-- get whether vector |v| is
-- inside the hitbox
function hbox:contains(v)
  return in_range(
      v.x,
      self.pos.x,
      self.pos.x + self.size.x
  ) and in_range(
      v.y,
      self.pos.y,
      self.pos.y + self.size.y)
end

function hbox:intersects(hb)
  -- assumes pos is top-left
  local pos1 = self.pos
  local size1 = self.size
  local pos2 = hb.pos
  local size2 = hb.size
      
  local xoverlap = in_range(
      pos1.x,
      pos2.x,
      pos2.x + size2.x
  ) or in_range(
      pos2.x,
      pos1.x,
      pos1.x + size1.x)
  
  local yoverlap = in_range(
      pos1.y,
      pos2.y,
      pos2.y + size2.y
  ) or in_range(
      pos2.y,
      pos1.y,
      pos1.y + size1.y)
               
  return xoverlap and yoverlap 
end

-- animation

anim = class.build()

function anim:_init(
    start_sprid, end_sprid,
    is_loop, duration)
  -- duration is how many ticks
  -- each frame should last
  duration = duration or 1
 
  self.start_sprid = start_sprid
  self.end_sprid = end_sprid
  self.is_loop = is_loop
  self.duration = duration
  self.ticks = 0
    
  self.sprid = start_sprid
  self.done = false
end

-- a single-frame animation
-- useful for passing sprites
-- to functions that expect
-- animations
function anim_single(sprid)
  return anim(
      sprid, sprid,
      --[[is_loop=]]false)
end

function anim:reset()
  self.sprid = self.start_sprid
  self.ticks = 0
  self.done = false
end

function anim:update()
  self.ticks = min(
      self.ticks + 1,
      self.duration)
  
  local done_frame = (
      self.ticks ==
      self.duration)
  local done_last_frame = (
      self.sprid ==
      self.end_sprid) and
      done_frame

  if done_last_frame and
     not self.is_loop
  then
    self.done = true
    return
  end
  
  if (not done_frame) return
  
  self.ticks = 0
  if done_last_frame
  then
    self.sprid = self.start_sprid
  else
    self.sprid += 1
  end
end

-- creates an animation
-- that chains together
-- several animation instances.
anim_chain = class.build()

function anim_chain:_init(
    anims, is_loop)
  self.anims = anims
  self.current = 1
  self.is_loop = is_loop
  self.done = false
  self.sprid = anims[1].sprid
end

function anim_chain:anim()
  return self.anims[
      self.current]
end

function anim_chain:update()
  local anim = self:anim()
  anim:update()
  self.sprid = anim.sprid
    
  if (not anim.done) return
  
  -- we just finished an anim
  local done_last_anim = (
      self.current ==
      #self.anims)
  if not done_last_anim
  then
    -- next anim in chain
    self.current += 1

    self:anim():reset()
  elseif self.is_loop
  then
    -- we're done the last anim
    -- in a loop, so restart
    -- loop
    self.current = 1

    self:anim():reset()
  else
    -- we're done the last anim
    -- and we're not looping,
    -- so this chain is done
    self.done = true
  end
end

-- button helpers

local prev_btn = {
  false,
  false,
  false,
  false,
  false,
  false,
}

-- is a button just pressed?
-- relies on prev_btn being
-- updated at the end of the
-- game loop
-- different from btnp because
-- it doesn't use keyboard-style
-- repeating 
function btnjp(i)
  -- todo: add support for more
  --       than one player
  return btn(i) and
         not prev_btn[i+1]
end

-- update state used by btnjp
-- call this at the end of
-- every update
function update_prev_btn()
  prev_btn[1] = btn(0)
  prev_btn[2] = btn(1)
  prev_btn[3] = btn(2)
  prev_btn[4] = btn(3)
  prev_btn[5] = btn(4)
  prev_btn[6] = btn(5)
end

-- life utils

function filter_alive(xs)
  alive = {}
  for x in all(xs)
  do
    if x.life > 0 then
      add(alive, x)
    end
  end
  return alive 
end
-->8
-- bullets and pickups

-- bullet
local bullet = class.build()

function bullet:_init(
    anim, pos, vel, life,
    is_enemy, left, props)
  props = props or {}
  
  if props.destroy_on_hit == nil
  then
    self.destroy_on_hit = true
  else
  		self.destroy_on_hit =
  		    props.destroy_on_hit
  end
  
  if props.reflectable == nil
  then
    self.reflectable = false
  else
    self.reflectable =
        props.reflectable
  end
  
  -- hitbox size
  self.size = props.size or vec(
      8, 8)
  -- how many ticks before the
  -- bullet becomes deadly?
  self.deadly_start = props.deadly_start or 30000
  -- how many ticks before the
  -- bullet stops being deadly?
	  self.deadly_end = props.deadly_end or -30000

  self.anim = anim
  self.pos = vec(pos)
  self.vel = vec(vel)
  -- lifetime in ticks
  self.life = life
  self.is_enemy = is_enemy
  self.left = left
end

function bullet:update()
  self.pos += self.vel
  self.life -= 1
  self.anim:update()
end

function bullet:collide(other)
  if self.life > self.deadly_start
      or self.life < self.deadly_end
  then
    return
  end

  local bullet_hb = hbox(
      self.pos,
      self.size)
  local other_hb = hbox(
      other.pos,
      other.size or vec(8, 8))
  
  if bullet_hb:intersects(
      other_hb)
  then
    if self.destroy_on_hit
    then
      bullet.life = 0
    end
    other.life -= 1
    return true
  end
  return false
end

function bullet:reflect()
  self.vel = -self.vel
  self.is_enemy = not self.is_enemy
  self.left = not self.left

  -- give a slight speedup
  -- for satisfaction
  self.vel *= 1.4
  -- only allow one reflection
  self.reflectable = false
  -- add some more life so it
  -- lasts longer
  self.life += 50
  
  sfx(24)
end

function bullet:draw()
  spr(self.anim.sprid,
      self.pos.x, self.pos.y,
      1, 1,
      -- flip_x
      self.left)       
end

-- this is game update stuff,
-- but i tossed it in here cuz
-- it was really noisy
function update_bullets(state)
  -- bullets
  for b in all(state.bullets)
  do
    b:update()
    
    -- handle reflections
    for ob in all(state.bullets)
    do
      if b != ob and
         ob.reflectable and
         b.is_enemy != ob.is_enemy and
         -- only reflect bullets
         -- in opposite direction
         b.left != ob.left and
         b:collide(ob)
      then
        ob:reflect()
      end 
    end

    -- handle damage and
    -- pushback
    local pushback =
        ternary(
            b.left,
            vec(-3, 0),
            vec(3, 0))    
    if b.is_enemy
    then
      local p = state.player
      if p.invuln_cooldown <= 0
          and b:collide(p)
      then
        p.invuln_cooldown = 100
        p.walk_cooldown = 20
        p.pos += pushback
        sfx(21)
        
        if p.life <= 0
        then
          -- todo: death sfx

          -- timer so the stage
          -- doesn't restart
          -- if the player spams
          -- x when dying
          state.death_timer =
              200
          music(-1)
        end
      end
    else
      for e in all(
          state.enemies)
      do
        if e.invuln_cooldown <= 0
            and b:collide(e)       
        then
          e.invuln_cooldown =
              40
          e.hitstun_cooldown =
              60
          e.pos += pushback
          e.vel = pushback / 4
          sfx(20)
        end
      end
    end
  end
end

-- health pickup
local health = class.build()

function health:_init(pos)
  self.type = type
  self.pos = pos
  self.life = 400
end

function health:update(player)
  self.life = max(
      0, self.life - 1)
  
  local hb = hbox(
      self.pos,
      --[[size=]]vec(8, 8))
  local phb = hbox(
      player.pos,
      --[[size=]]vec(8, 8))
  
  if self.life > 0 and
     hb:intersects(phb)
  then
    sfx(23)
    self.life = 0
    player.life = min(
        player.max_life,
        player.life + 2)
  end
end

function health:draw()
  -- flicker towards end of life
  local draw =
      self.life > 200 or
      (self.life > 100 and
       self.life % 3 != 0) or
      (self.life % 2 != 0)
  if draw
  then
		  spr(31, self.pos.x,
		      self.pos.y)
  end
end	

-->8
-- enemies, waves, player

local movement_min = vec(
    0, 4 * 8 - 4)
local movement_max = vec(
    30000, 12 * 8 - 8)

-- walks towards the player
-- and beats the living ****
-- out of them
local walker = class.build()

function walker:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.left = false
  self.swing_cooldown = 100
  self.life = 3
  
  self.walk_cooldown = 50
  self.walk_dist = 50
  
  self.invuln_cooldown = 0
  self.hitstun_cooldown = 0
  
  self.anim_idx = 1
  self.anim_len = 60
end

function walker:walk_towards(
    player)
  if self.walk_cooldown > 0
  then
    return
  end
  
  local direc = player.pos -
      self.pos
  local speed = 0.3
  self.vel = (
      direc:normalized() *
      speed)
  local dist = self.vel:mag()
  self.walk_dist -= dist
  
  if self.walk_dist <= 0
  then
    self.walk_dist = 50 +
        rnd(50)
    self.walk_cooldown = 50 +
        rnd(50)
  end
end

function walker:swing(bullets)
  self.swing_cooldown = 100
  local bullet_offset =
      ternary(
          self.left,
          vec(-8, 0),
          vec(8, 0))
  add(bullets,
      bullet(
          anim(16, 20, false,
               6),
          self.pos +
              bullet_offset,
          vec(0, 0),
          30,
          --[[is_enemy]]true,
          self.left,
          {
            destroy_on_hit=false,
            deadly_start=25,
            deadly_end=5,
          }))
end

function walker:run_ai(
    player, bullets)
  -- measure distance
  local direc = player.pos -
      self.pos
  local attack_dist = 8
  local wants_attack =
      direc:mag() <= attack_dist
  
  -- states
  if not wants_attack then
    self:walk_towards(player)
    if self.vel.x < 0 then
      self.left = true
    elseif self.vel.x > 0 then
      self.left = false
    end
  elseif self.swing_cooldown
         <= 0 then
    self:swing(bullets)
  end
end

function walker:update(
    player, bullets)
  if player.life <= 0 then
    return
  end

  self.swing_cooldown = max(0,
      self.swing_cooldown - 1)
  self.walk_cooldown = max(0,
      self.walk_cooldown - 1)
  self.hitstun_cooldown = max(0,
      self.hitstun_cooldown - 1)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  
  self.vel = vec(0, 0)
  
  if self.hitstun_cooldown
     <= 0
  then
    self:run_ai(player, bullets)
  end

  self.pos += self.vel
  self.pos = self.pos:clamp(
      movement_min,
      movement_max)

  if self.vel:mag() > 0 then
    self.anim_idx =
      wrap_idx(
        self.anim_idx + 1,
        self.anim_len)
  else
    self.anim_idx = 1
  end
end

function walker:draw()
  -- shadow
  spr(6,
    self.pos.x -
      ternary(self.left, -1, 1),
    self.pos.y + 2)

  palt(14, true)
  palt(0, false)

  -- selet walk anim frame
  local sprid = ternary(
    self.vel:mag() > 0 and
      self.anim_idx <=
        self.anim_len / 2,
    69,
    68)
  spr(sprid,
    self.pos.x,
    self.pos.y,
    1, 1,
    -- flip_x
    self.left)

  -- overlay dragged sword
  spr(70,
    self.pos.x,
    self.pos.y,
    1, 1,
    self.left)

  palt(14, false)
  palt(0, true)
end

-- imp

local imp = class.build()

function imp:_init(pos, left)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.left = left
  self.life = 1
  self.invuln_cooldown = 0
  
  self.windup_time = 0
  self.attack_pos = nil
  self.throw_cooldown = 0
end

function imp:shoot(bullets)
  local offset = ternary(
      self.left,
      vec(-8, 0),
      vec(8, 0))
  local speed = 1.2
  local vel = ternary(
      self.left,
      vec(-speed, 0),
      vec(speed, 0))
  local bullet = bullet(
      anim_single(14),
      self.pos + offset,
      vel,
      100,
      --[[is_enemy=]]true,
      self.left,
      {
        reflectable=true,
      })
  add(bullets, bullet)
  sfx(22)

  self.throw_cooldown = 50
end

function imp:move_to_attack()
  local speed = 0.5
  self.pos =
      self.pos:push_towards(
          self.attack_pos,
          speed)
      
  if self.pos == self.attack_pos
  then
    self.attack_pos = nil
    self.windup_time = 25
  end
end

function imp:align_with_player(
    player)
  -- move down or up towards
	 -- the player
		local speed = 0.3
		self.pos =
		    self.pos:push_towards(
		        vec(self.pos.x,
		            player.pos.y),
	         speed)
		
		local target_distance = 20
		local direc = player.pos -
		    self.pos
		if abs(direc.y) <= target_distance
		then
		  self.attack_pos = vec(
		      self.pos.x,
		      player.pos.y)
		end
end

function imp:update(
    player, bullets)
  if self.throw_cooldown > 0
  then
    self.throw_cooldown -= 1
    return
  elseif self.windup_time > 0
  then
    self.windup_time -= 1
    if self.windup_time == 0
    then
      self:shoot(bullets)
    end
  elseif self.attack_pos != nil
  then
    self:move_to_attack()
  else
    self:align_with_player(
        player)
  end
end

function imp:draw()
  -- todo: windup sprite
  spr(8, self.pos.x, self.pos.y,
      1, 1,
      self.left)
end

-- slime

-- todo!!!!

-- seeker

local seeker = class.build()

function seeker:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  
  self.life = 4
  self.tail_length = 4
  self.separation = 10
  self.speed = 0.6
  self.invuln_cooldown = 0
  -- not used but necessary
  self.hitstun_cooldown = 0

  -- tail is a list of previous
  -- positions. the last elt
  -- is the furthest position,
  -- the first elt is the
  -- current position
  self.tail = {}
  for i=self:tail_end_idx(),1,-1
  do
    add(self.tail,
        vec(self.pos.x,
            self.pos.y))
  end
end

function seeker:tail_end_idx()
  return self.tail_length * 
      self.separation
end

function seeker:seek(
    player, bullets)
  local direc = player.pos -
      self.pos
  self.vel =
      self.vel:push_towards(
          direc:normalized() *
          self.speed,
          0.025) 
 
  -- to do collisions with the
  -- eye, put a bullet in the
  -- eye for one frame
  add(bullets,
      bullet(
          anim_single(0),
          self.pos,
          --[[vel=]]vec(0, 0),
          --[[life=]]1,
          --[[is_enemy=]]true,
          --[[left=]]false,
          {
            size=vec(4, 4),
          }))
end

function seeker:update(
    player, bullets)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  self.hitstun_cooldown = max(0,
      self.hitstun_cooldown - 1)

  if self.hitstun_cooldown == 0
  then
    self:seek(player, bullets)
  else
    -- drop a bit while taking
    -- damage
    self.vel.y += 0.01
  end
  
    -- push the tail back
  local end_idx =
      self:tail_end_idx()
  for i=end_idx,2,-1
  do
    self.tail[i] =
        self.tail[i-1]
  end
  
  -- put the new position at
  -- the front of the tail
  self.pos += self.vel
  self.tail[1] = self.pos  
end

function seeker:draw()
  local end_idx =
      self:tail_end_idx()
  for i=end_idx,1,-1
  do
    local sprid = 27
    local flip_x = false
    local flip_y = false
    
    local pos = vec(
        self.tail[i])
    
    if i == end_idx
    then
      local last_tail =
          self.tail[end_idx]
      local second_last_tail =
          self.tail[end_idx-1]
      if last_tail.x < second_last_tail.x
      then
        flip_x = true
      else
      end

      if last_tail.y > second_last_tail.y
      then
        flip_y = true
      end
      sprid = 30
    elseif i > 1
    then
      sprid = 29
    elseif self.hitstun_cooldown > 0
    then
      sprid = 28
    else
      sprid = 27
    end

    if i == 1 or 
       divby(self.separation, i)
    then    
	     spr(sprid, pos.x, pos.y,
	         1, 1,
	         flip_x, flip_y)
    end
  end
end

-- enemy waves

local wave = class.build()

function wave:_init(
    startx, enemies, props)
  props = props or {}

  -- camera offset, not player
  self.startx = startx
  self.enemies = enemies
  self.spawned = false
  self.spawn_health = ternary(
      props.spawn_health != nil,
      props.spawn_health, false)
  self.lock_cam = ternary(
      props.lock_cam != nil,
      props.lock_cam, true)
  
  -- add startx to enemy pos
  -- to make calculations
  -- easier
  for e in all(self.enemies)
  do
    e.pos.x += self.startx
  end
end

function wave:done()
  return self.spawned and
      #self.enemies == 0 
end

function wave:update(
    cam, enemies, pickups)
  if (self:done()) return
  
  if not self.spawned and
     cam.pos.x >= self.startx
  then
    self.spawned = true
    for e in all(self.enemies)
    do
      add(enemies, e)
    end
  elseif self.spawned
  then
    old_enemy_count =
        #self.enemies
    self.enemies = filter_alive(
        self.enemies)
    if old_enemy_count > 0 and
       #self.enemies == 0 and
       self.spawn_health
    then
      add(pickups,
          health(
              vec(self.startx + 100,
                  60)))
    end
  end
end

function any_wave_locking_cam(
    waves)
  for w in all(waves)
  do
    if w.spawned and
       not w:done() and
       w.lock_cam
    then
      return true
    end
  end
  return false
end

-- player

local player = class.build()
player.skin_colors = {
  6
  --4, 9, 15
}
player.hair_colors = {
  0, 6, 10
}
player.walk_anim_len = 20

function player:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  self.life = 6
  self.max_life = 6
  self.invuln_cooldown = 100
  self.left = false
  
  self.walk_cooldown = 0
  self.swing_cooldown = 0
  
  self.skin_color =
      rnd_in(player.skin_colors)
  self.hair_color =
      rnd_in(player.hair_colors)

  self.walk_anim_idx = 1
  self.walk_anim_len =
      player.walk_anim_len
end

function player:vulnerable()
  return (
      self.invuln_cooldown
      <= 0)
end

function player:can_walk()
  return (
      self.walk_cooldown
      <= 0)
end

function player:can_swing()
  return (
      self.swing_cooldown
      <= 0)
end

function player:walk()
  local direc = vec(0, 0)

  if (btn(⬅️)) direc.x -= 1
  if (btn(➡️)) direc.x += 1
  if (btn(⬆️)) direc.y -= 1
  if (btn(⬇️)) direc.y += 1
  
  direc = direc:normalized()
  
  if direc.x < 0 then
    self.left = true
  elseif direc.x > 0 then
    self.left = false
  end

  local speed = 0.6
  self.vel = direc * speed
end

function player:swing(bullets)
  self.swing_cooldown = 24
  self.walk_cooldown = 12
  
  local bullet_pos =
      self.pos +
        ternary(
          self.left,
          vec(-6, 0),
          vec(6, 0))
  add(bullets,
      bullet(
        anim_chain {
          anim(64, 65, false, 4),
          anim(66, 66, false, 8),
        },
        bullet_pos,
        vec(0, 0),
        12,
        --[[is_enemy]]false,
        self.left,
        {
          destroy_on_hit=false,
          deadly_start=3,
          deadly_end=1,
        }))
  sfx(25)
end

function player:update(
    cam, cam_locked, bullets)  
  self.swing_cooldown = max(0,
      self.swing_cooldown - 1)
  self.walk_cooldown = max(0,
      self.walk_cooldown - 1)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  self.vel = vec(0, 0)

  if self:can_walk() then
    self:walk()
  end
  
  if self:can_swing() and
      btnjp(❎)
  then
    self:swing(bullets)
  end

  self.pos += self.vel
  self.pos = self.pos:clamp(
      vec(cam.pos.x,
          movement_min.y),
      -- when the camera is
      -- locked, force the
      -- player in-bounds.
      -- otherwise they
      -- can wander off-cam
      -- to end the stage.
      vec(ternary(
              cam_locked,
              cam.pos.x + 120,
              movement_max.x),
          movement_max.y))

  if self.vel:mag() > 0 then
    self.walk_anim_idx =
		    wrap_idx(
        self.walk_anim_idx + 1,
        self.walk_anim_len)
  else
    self.walk_anim_idx = 1
  end

end

function player:draw()
  spr(5,
    self.pos.x,
    self.pos.y + 1)

  if self.invuln_cooldown % 3 != 0
  then
    return
  end
  
  palt(14, true)
  pal(12, self.skin_color)
  pal(11, self.hair_color)
  
  if self.vel:mag() > 0 and
      self.walk_anim_idx
        <= self.walk_anim_len / 2 then
    spr(2,
      self.pos.x,
      self.pos.y - 1,
      1, 1, self.left)
  else
		  spr(1,
      self.pos.x, self.pos.y,
      1, 1, self.left)
  end

  palt(14, false)
  pal(12, 12)
  pal(11, 11)
end

-- departed soul
-- the final boss of the game
-- who you steal the gold from.

local soul = class.build()

function soul:_init(pos)
  self.pos = vec(pos)
  self.vel = vec(0, 0)
  
  self.life = 12
  self.skin_color =
      rnd_in(player.skin_colors)
  self.hair_color = 
      rnd_in(player.hair_colors)
  self.invuln_cooldown = 0
  self.hitstun_cooldown = 0
  
  self.walk_idx = 1
  self.walk_anim_len =
      player.walk_anim_len

  self.left = false
  
  self.unaware = true
  self.confused = false
  self.confused_frames = 0
end

function soul:react_to_player(
    player)
  if abs(player.pos.x - self.pos.x) < 45
  then
    self.unaware = false
    self.confused = true
  end
end

function soul:be_confused(
    player)
  if self.hitstun_cooldown > 0
  then
    -- we got attacked. we're
    -- becoming hostile, start
    -- the tunez.
    self.confused = false
    music(10)
    return
  end

  if player.pos.x < self.pos.x
  then
    self.left = true
  else
    self.left = false
  end
  
  self.confused_frames += 1
end

function soul:update(
    player, bullets)
  self.invuln_cooldown = max(0,
      self.invuln_cooldown - 1)
  self.hitstun_cooldown = max(0,
      self.hitstun_cooldown - 1)

  if self.unaware
  then
    self:react_to_player(player)
  elseif self.confused
  then
    self:be_confused(player)
  else
    -- boss battle!!!!!
  end
  
  if self.vel:mag() > 0 then
    self.walk_anim_idx =
		    wrap_idx(
        self.walk_anim_idx + 1,
        self.walk_anim_len)
  else
    self.walk_anim_idx = 1
  end
end

function soul:draw()
  if self.confused
  then
    local offset = min(
        4,
        self.confused_frames) +
        2
     
    local text_pos =
        self.pos + vec(2,
                       -offset) 
    print(
        "?",
        text_pos.x, text_pos.y,
        6)
  end
  
  player.draw(self)
end
-->8
-- tile generation and drawing

tile_gen = class.build()

function tile_gen:_init()
  self.deets = {}
  local wall_deet_ids = {
      35, 36, 37, 38, 53
  }
  local grnd_deet_ids = {
      39, 40, 54, 55, 56
  }

  local s_width = 16
  for s = 1,flr(128 / s_width) do
    local y = flr(rnd(8 * 8 - 4)) + 4 * 8
    if (y >= 12 * 8 - 4) y += 8
    local x = flr(rnd(s_width)) + s * s_width
    local t = rnd_in(
        ternary(
          y < 12 * 8,
          grnd_deet_ids,
          wall_deet_ids))
          
    add(self.deets, {x = x, y = y, t = t})
  end
end

function tile_gen:draw()
  rectfill(0,0,128*4,4*8-1,9)
  rectfill(0,4*8,128*4,12*8-1,13)
  clip(0,0,128,14*8)
  for d in all(self.deets) do
    spr(d.t, d.x, d.y)
  end
  clip()
end
-->8
-- camera

cam = class.build()

function cam:_init(p)
  self.p = p
  self.give = 16
  self.pos = vec(0, 0)
  self.min = vec(0, 0)
  self.max = vec(128*2, 0)
  self.center =
      vec(128, 128) / 2
end

function cam:update()
  local target =
      self.p.pos - self.center
  local target_cam =
      self.pos
        :clamp(
		        target - self.give,
		        target + self.give)
        :clamp(
          self.min,
          self.max)

  self.pos =
      self.pos:push_towards(
        target_cam,
        1)
end

function cam:draw()
  camera(
      self.pos.x,
      self.pos.y)
end
-->8
-- game

local state = {}

function get_music(
    stage, is_restart)
  -- todo: stage 2, stage 3
  
  if (is_restart) return 5
  return 0
end

-- player xpos that ends the
-- stage
function get_stage_end(
    stage)
  -- todo: stage 2, stage 3
  
  return 128*3 + 16
end
  
function get_waves(stage)
  -- todo: stage 2, stage 3

  return {
    wave(60, {
      walker(vec(110, 30)),
    		walker(vec(10, 60)),
    }),
    wave(110, {
      imp(vec(8, -5),
          --[[left=]]false),
    }),
    wave(130, {
      walker(vec(20, 70)),
    }, {
      lock_cam=false,
    }),
    wave(140, {
      walker(vec(20, 40)),
    }, {
      lock_cam = false,
      spawn_health = true,
    }),
    wave(170, {
      walker(vec(25, 80)),
      walker(vec(35, 40)),
      imp(vec(8, -5),
          --[[left=]]false),
    }),
    wave(220, {
      imp(vec(12, -30),
          --[[left=]]false),
      imp(vec(112, -10),
          --[[left=]]true),
    }),
    wave(128*2, {
      seeker(vec(100, -5)),
    }, {
      spawn_health=true
    }),
  }
end

function get_palette(stage)
  if state.stage == 2
  then
    -- shades of red
    return {
      ground=9,
      outline=5,
      crack=4,
      sky=15,
    }
  end

  return {
    ground=13,
    sky=6,
    crack=2,
    outline=1,
  }
end

function get_intro_life(stage)
  if stage == 2 then
    return 250
  end
  return 1000
end

-- common initialization
-- logic between starting a
-- stage for the first time
-- and restarting
function init_stage(state)
  state.player = player(
      vec(60, 60))
  state.camera = cam(
      state.player)
	
  state.enemies = {}
  state.bullets = {}
  state.particles = {}
  state.pickups = {}
  state.death_timer = 0

  state.stage_end =
      get_stage_end(
          state.stage)
  
  state.waves = get_waves(
      state.stage)
end

-- call this the first time
-- you enter a stage
function start_stage(
    stage, state)
  local song = get_music(
      stage,
      --[[is_restart=]]false)
  music(song)

  state.stage = stage
  
  state.intro_life =
      get_intro_life(stage)
  state.stage_done = false
  
  -- stage 1 has a special
  -- musical intro before
  -- the prompt to move shows
  -- up
  if stage == 1
  then
  		state.music_intro = true
    state.prompt_move_dist = 0
  end
  
  state.stage_done = false
  state.skip_intro = false
  state.intro_done = false
  
  init_stage(state)
end

-- call this instead of
-- start_stage when restarting
-- a stage
function restart_stage(state)
  local song = get_music(
      state.stage,
      --[[is_restart]]true)
  music(song)
  state.skip_intro = true
  
  init_stage(state)
end

function next_stage(state)
  start_stage(state.stage + 1,
              state)
end

function _init()
  -- the music intro is long,
		-- so if the user is spamming
		-- buttons, skip it
		state.skip_intro_presses = 0
		
  start_stage(1, state)
		
  -- uncomment this to
  -- skip long intro
  --restart_stage(state)
  
  random_tiles = tile_gen()
end

-- a bunch of junk to align
-- the start of the game with
-- music
function update_music_intro(
    state)
  if btnjp(❎) or btnjp(🅾️)
  then
    state.skip_intro_presses += 1
    if state.skip_intro_presses
       >= 8
    then
      state.skip_intro = true
      music(5)
    end
  end
  
  local old_music_intro =
      state.music_intro
  state.music_intro =
      stat(24) < 3
  if not state.intro_done and
     ((old_music_intro and
      not state.music_intro)
      or state.skip_intro)
  then
    -- prompt the user to move
    -- forward when the music
    -- pauses
    state.intro_life = 0
    state.intro_done = true
    state.prompt_move_dist = 40
  end
end

function _update60()
  -- stage intro junk
  state.intro_life = max(0,
      state.intro_life - 1)
 
  if state.music_intro
  then
    update_music_intro(state)
  end
  
  if state.intro_life > 0
  then
    update_prev_btn()
    return
  end

  -- stage completion junk
  if not state.stage_done and
     state.player.pos.x >
     state.stage_end
  then
    state.stage_done = true
    music(-1)
    sfx(26)
  end
  
  -- stage restarting junk
  state.death_timer = max(0,
      state.death_timer - 1)
  if state.player.life <= 0 and
     state.death_timer <= 0 and
     btnjp(❎)
  then
    restart_stage(state)
  end
  
  -- waves
  for w in all(state.waves)
  do
    w:update(state.camera,
             state.enemies,
             state.pickups)
  end
  
  -- player
  local cam_locked =
      any_wave_locking_cam(
          state.waves)

  local p = state.player
  if p.life > 0 then
    p:update(state.camera,
             cam_locked,
             state.bullets)
  end
  
  -- camera
  if not cam_locked
  then
    local old_campos = vec(
        state.camera.pos)
    
    state.camera:update()

    -- don't let the camera
    -- go back to the left
    state.camera.min.x =
        state.camera.pos.x
    
    -- stop prompting the player
    -- to move when the camera
    -- moves enough (they get
    -- the point)
    local delta =
        state.camera.pos.x -
        old_campos.x
    state.prompt_move_dist =
        push_towards(
            state.prompt_move_dist,
            0, delta)
  end
   
  -- enemies
  for e in all(state.enemies)
  do
    e:update(p, state.bullets)
  end
  
  -- bullets
  update_bullets(state)
  
  -- pickups
  for pi in all(state.pickups)
  do
    pi:update(p)
  end

  -- particles
  for pr in all(state.particles)
  do
    pr:update()
  end
  
  -- clear dead stuff
  local old_enemy_count =
      #state.enemies
  state.enemies = filter_alive(
      state.enemies)
  state.bullets = filter_alive(
      state.bullets)
  state.particles = filter_alive(
      state.particles)
 
  -- prompt to move when all the
  -- enemies are dead
  if old_enemy_count > 0 and
     #state.enemies == 0
  then
    state.prompt_move_dist = 20
  end

  update_prev_btn()
end

function draw_intro()
  if state.intro_life < 250
  then
		  print("scene 1", 48, 64,
		        6)
		  print("the journey begins",
		        28, 80, 6)
		  return
	 end
	 
	 print(
	     "\"if 'cross styx you",
	     8, 20, 6)
	 print(
	     "wish passage,",
	     12, 28, 6)
	 
	 if state.intro_life < 750
	 then
	   print(
	       "two gold coins you",
	       12, 40, 6)
	   print(
	       "must scavenge.",
	       12, 48, 6)
	 end
	 
	 if state.intro_life < 425
	 then
	   print(
	       "good luck!\"",
	       80, 60, 6)
	 end
end

function draw_ui()
  -- prompt the player to
  -- advance
  if not any_wave_locking_cam(
      state.waves) and
     state.prompt_move_dist > 0
  then
  		spr(15,
    		  114 + nsin(time()) * 1.8,
      		4)
  end
  
  print(state.player.life,
        0, 0, 6)
end

-- gets all entities that can
-- be sorted by y-pos to draw
function all_entities(state)
  local ents = {}
  if state.player.life > 0
  then
    add(ents, state.player)
  end
  for e in all(state.enemies)
  do
    add(ents, e)
  end
  for b in all(state.bullets)
  do
    add(ents, b)
  end
  for pr in all(state.particles)
  do
    add(ents, pr)
  end
  return ents
end

function _draw()
  cls()
  
  if state.intro_life > 0
  then
    draw_intro()
    return
  end

  state.camera:draw()

  local palette = get_palette(
      state.stage)
  
  pal(1, palette.outline)
  pal(2, palette.crack)
  pal(9, palette.sky)
  pal(13, palette.ground)

  random_tiles:draw()
  map(0, 0, 0, 0)
  
  pal(1, 1)
  pal(2, 2)
  pal(9, 9)
  pal(13, 13)
  
  ents = all_entities(state)
  sort(ents, function(x, y)
    return x.pos.y > y.pos.y
  end)
  for ent in all(ents)
  do
    ent:draw()
  end

  for pi in all(state.pickups)
  do
    pi:draw()
  end
  
  -- ui is screen-space, so
  -- reset camera before drawing
  camera(0, 0)
  draw_ui()
end
__gfx__
00000000eeebbeeeeeebbeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eebccceeeebccceeeeeeeeeeeeeeeeee00000000000000000000000000a88a0000000000000000000000000000000000000000000000000000088000
00700700eebccceeeebccceeeeeeeeeeeeeeeeee0000000000000000000000000088800900000000000000000000000000000000000000000000999900088800
00077000eeecceeeeeecceeeeeeeeeeeeeeeeeee0000000000000000000000000088809000000000000000000000000000000000000000000000900088888880
00077000eecccceeeecccceeeeeeeeeeeeeeeeee0000000000000000000000002088009900000000000000000000000000000000000000009999999988888888
00700700eecccceeeecccceeeeeeeeeeeeeeeeee0011110001111110000000000288890000000000000000000000000000000000000000000000900088888880
00000000eecccceeecccccceeeeeeeeeeeeeeeee0111111011111111000000000088000000000000000000000000000000000000000000000000999900088800
00000000eeceeceeeeeeeeeeeeeeeeeeeeeeeeee0011110001111110000000000800800000000000000000000000000000000000000000000000000000088000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880000000000000000000000000000000000000000000000000000000000000000000000000000000000022220000222200000000000000000000020200
00000000088888800000000000000000000000000000000000000000000000000000000000000000000000000288882002222220000220000000222000282820
000000000000000008888880000000000000000000000000000000000000000000000000000000000000000028a66a8222222222002882000002882002888882
000000000000000000000000088888800000000000000000000000000000000000000000000000000000000028a66a8222288222002882000002822002888882
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000288882002222220000220000028200000288820
00000000000000000000000000000000088888800000000000000000000000000000000000000000000000000022220000222200000000000022000000028200
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000
dddddddddddddddd11111ddd02500000250000002dd2100001100000002000000220000000000000000000000000000000000000000000000000000000000000
1ddd111111ddd111111111110250000025000000022100001551000002d200002dd2000000000000000000000000000000000000000000000000000000000000
11111111111d111112dd1111250000000250000005510000055000002ddd20000111000000000000000000000000000000000000000000000000000000000000
1111122ddd11112dd2dddddd25000000025000000050000025520000011110000000000000000000000000000000000000000000000000000000000000000000
dddd222ddd11122dd2dddddd02500000250000000000000002200000000000000000000000000000011111000000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd02500000250000000000000000000000000000000000000011100011111111110000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd0000000000000000000000000000000000000000000000001111111111ddd1110000000000000000000000000000000000000000
dddd222ddddd222dd2dddddd000000000000000000000000000000000000000000000000dd11111ddddddddd0000000000000000000000000000000000000000
dddd222ddddd222dd2ddddddd2dddddddddd222d1000000020000000255552000200200000000000000000000000000000000000000000000000000000000000
ddd2222ddddd2222d2ddddddd2dddddddddd222d1000000000000000022220002525520000000000000000000000000000000000000000000000000000000000
ddd222ddddddd222d2ddddddd2dddddddddd222d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddd222ddddddd222d2ddddddd2dddddddddd222d1000000000000000000000000000000000000000000011000000000000000000000000000000000000000000
ddd222ddddddd222dd2dddddd2dddddddddd222d0000000000000000000000000000000000000000001111000000000000000000000000000000000000000000
ddd2222ddddd2222dd2dddddd2dddddddddd222d00000000000000000000000000000000111111111111d1110000000000000000000000000000000000000000
dddd222ddddd222ddd2dddddd2dddddddddd222d000000000000000000000000000000001111111111ddd1110000000000000000000000000000000000000000
dddd222ddddd222dd2ddddddd2dddddddddd222d00000000000000000000000000000000dddddddddddddddd0000000000000000000000000000000000000000
00000000000007770000077000077770eee555eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee2eeeeeeeeeeeeeeefeeeeeeeeeeeeeeee2eeeeeeeeeeee
00000000000076670000760000777770ee55005eeee555eeeeeeeeeeeee50eeeeeeeeeeeeeeeeeeee222f88feee2f88fe880eeeeeeeeeeeeeee22eeeeeeeeeee
00000000007767770077600000777770ee55005eee55005eeeeeeeeeee500eeeeeeeeeeeeeeeeeee2222800eee22800ef8082eeeefeee222eee22eeeeeeeeeee
44000000476677774760000044677777e555005eee55005eeeeeeeeeee5000eeee50eeeeeeeeeeee2222888eee22888ee88222eee808222eefe222eeeeeeeeee
47700000447777774400000047766777e55555eee555005eeee4eeeeee5555eeee5000eeeeeeeeee222288eeee2228eeee82228ee8022228e80222e8eeeeeeee
00677000007777770000000000677677e55555eee55555eeee764eeee55455eee555555eee5555ee22e2888eee22288eee2222eeef82228ee808228eefeeeeee
00006700007777700000000000006767e55555eee55555eee76eeeee557745ee5555455e5555455e2eee88eeee2e88eeeee2228eeee82228ef882228e802228e
00000670000777700000000000000677555555ee555555ee76eeeeee776eeeee777774ee777774eeeee8e8eeeee8e8eeeeee2eeeeeeeeeeeeeeeeeeeef822228
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2a29393a2929392929292a3a29392a292a29393a392a29393a2929392929292a3a29392a292a29393a392a29393a2929392929292a3a29392a292a29393a390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122212020222021202222212022212220222020202122212020222021202222212022212220222020202122212020222021202222212022212220222020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3033313430323034313332303432313234333031313033313430323034313332303432313234333031313033313430323034313332303432313234333031310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
012000080e00015000150001500013000110000e0000e0000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011800200e0540e0500e0500e0550e0000e0001505415050150501505500000000001805418050180501805500000000001505415050150501505500000000000c0540c0500c0500c05510000000000e0540e050
011800201a0541a0501a0501a0551a0000e0002105421050210502105500000000002405424050240502405500000000002105421050210502105500000000001805418050180501805510000000001a0541a050
011800200e0500e0551000010000110541105011050110550e0000e000130541305013050130550c0000c0000e0540e0500e0500e055130000e00015054150501505015055000001500018054180501805018055
011800001a0501a05510000100001d0541d0501d0501d0550e0001a0001f0541f0501f0501f0550c0000c0001a0541a0501a0501a055130000e00021054210502105021055000001500024054240502405024055
011800000e000000001505415050150501505500000000001105411050110501105500005100001005410050100501005010055000000e0000e0540e0500e0500e0500e0400e0300e0200e015000000000000000
011800200e000000002105421050210502105518000000001d0541d0501d0501d05500005100001c0541c0501c0501c0501c055000000e0001a0541a0501a0501a0501a0401a0301a0201a015000000000000000
010800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0530000000000000000c053000000c00000000
010800200c0530c0000c0530c0000c6750c60000000000000c0530c0000c0530c0000c6750c60000000000000c0530c0000c0530c0000e6750c60000000000000c0530c0000c0530c000186750c6000c65500000
002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00200000000000000000000000000000000000000000000530000000000000000005300000000000000000053000001960000000000531a60000000000000005300000000531a600186531a6531865318653
010a00200005300000000530000024653000000005300000000530000000053000002465300000000530000003053000000005300000246530000000053000000205300000020530000024653246530065500000
011400201855300053025000250018053020530250002500000531105302500025001305309053025000250018553000530250002500180530205302500025000005311053025000250013053090530250002500
01500010003550c300003550000000355000000035503354003550c30000355000000035500000003550c3540c3001a3000e300000001c3000e30000000000000000000000000000000000000000000000000000
011400200e1301105013750110500c0500e050110500c05013050150500e0500c0501105015050090500e0500e050110501305010050110500e050130500e0501005013050100500e0500e05013050150500e050
011400201855300053025520255218053020530255202552000531105302552025521305309053025520255218553000530255202552180530205302552025520005311053025520255213053090530255202552
011400200e155111550e155111550e15510155111550e15511155101550c15511155101550c15513155111550c15511155101550c1551115513155151550c1551115510155131550e1551515510155111550e155
011400201a050000001d050000001f050000001d0501f05021050110001f050000001a050000001d050000001a05000000180500e0001d000000001a000100001a0501a0001a0001a0501a0001a0001a0501f000
011400201a050000001d050000001f050000001d0501f05021050110001f050000001a050000001d050000001a05000000180500e0001d000000001a000100001a0501a0001a0001a0501a0001a000260501f000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000065300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000c65300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200002c1502a1502715025150221502015020150211501d150201501d1501b1501715014150111500715003150001500010002100001000010000100000000000000000000000000000000000000000000000
00030000271502a1502b1502d1502f1502e1503015031150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002d2502d25030250302503225035250352503b250372500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001342013420144201142014420124201d4201b42018420224201f4201e420163501535012350103500f3500e3500d3500b3500a3500735006350043500000000000000000000000000000000000000000
000e00000264302600026430260002633026000262302600026130260002613006000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
012000000e1500e1550e0000e0001515015155150001500018150181551500015000151501515500000000000c1500c15518000180000e1500e15500000000001115011155150001510013150131550e00000000
011000181a740217401f7401a740217401f7401a740217401f7401a740217401a740217401a740217401f740217401f740217401a7401f740217401a740217401f0501a050210501f050210501a050210501f050
012000200c0510c0520c0520c0520c0520c0520c0520c0510e0510e0520e0520e0520e0520e0520e0520e05113051130521305213052130521305213052130511505115052150521505215052150521505215051
__music__
00 01024344
00 03044344
00 05064344
00 07424344
01 08094344
01 08284344
00 0828296a
01 0828292a
00 0828292a
02 0868292a
00 0a424344
00 0b0c4e44
01 0b0c0e10
00 0b0c0e10
00 0b0c0e11
02 0b0c0e12

