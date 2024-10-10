Grid = {
  GameControl = nil,
  offsetX = my.variables.grid_offset_x,
  offsetY = my.variables.grid_offset_y,
  gridStep = my.variables.grid_step,
  moveActors = true,
  tracked = {},
  routes = {}
}

local GameControl

function Grid:pathfind(origin, destination, maxSteps)
  print("new route request")
  printTable(origin)
  printTable(destination)
  local queue = {}
  local visited = {}
  local directions = {
    { x = 1, y = 0 },  -- Right
    { x = -1, y = 0 }, -- Left
    { x = 0, y = 1 },  -- Down
    { x = 0, y = -1 }  -- Up
  }

  -- Snap origin and destination to the grid
  origin = self:snapToGrid(origin)
  destination = self:snapToGrid(destination)

  -- Initialize the queue with the origin
  table.insert(queue, { position = origin, steps = 0, path = {} })

  -- Keep track of visited positions
  visited[origin.x .. "," .. origin.y] = true

  -- Start pathfinding loop
  while #queue > 0 do
    local current = table.remove(queue, 1)

    -- Check if destination is reached
    if current.position.x == destination.x and current.position.y == destination.y then
      return current.path -- Return the completed path
    end

    -- If maximum steps are reached, return an empty path. maxSteps: 0 = unlimited
    if maxSteps ~= 0 and current.steps >= maxSteps then
      return {} -- No valid path found within max steps
    end

    -- Explore neighboring tiles
    for _, dir in ipairs(directions) do
      local nextPos = {
        x = current.position.x + dir.x * self.gridStep,
        y = current.position.y + dir.y * self.gridStep
      }

      -- Check if the tile is within bounds, not visited, and not occupied
      if not visited[nextPos.x .. "," .. nextPos.y] and not self:isTileOccupied(nextPos) then
        visited[nextPos.x .. "," .. nextPos.y] = true

        -- Build the new path step
        local newStep = {
          from = { x = current.position.x, y = current.position.y },
          x = nextPos.x,
          y = nextPos.y
        }

        print("From x: ", newStep.from.x, "From y: ", newStep.from.y, "To x: ", newStep.x, "To y: ", newStep.y)
        castle.createActor("Select Tile", newStep.x, newStep.y)

        -- Add the next position to the queue
        table.insert(queue, {
          position = nextPos,
          steps = current.steps + 1,
          path = #current.path == 0 and { newStep } or { table.unpack(current.path), newStep }  -- Ensure new steps are appended correctly
        })
      end
    end
  end

  return {} -- Return an empty table if no path is found
end


function Grid:routeTrackedActor(actorId, destination)
  self.GameControl:setBusy("routing")
  
  -- Get current position of the actor
  local current = self:getTrackedActorLocation(actorId)
  
  -- Use pathfind to get the route
  local route = self:pathfind(current, destination, 0) -- For example, 10 steps max

  printTable(route)

  -- Append the path to the actor's current route if any
  if route then
    local currentRoute = self.routes[actorId] or {}
    for _, step in ipairs(route) do
      table.insert(currentRoute, step)
    end
    self.routes[actorId] = currentRoute
  end

  -- Debugging output
  if my.variables.debug == 1 then
    debug("Route created for actor id: ", actorId)
    for _, pos in ipairs(self.routes[actorId]) do
      debug("From x: ", pos.from.x, "From y: ", pos.from.y, "To x: ", pos.x, "To y: ", pos.y)
    end
  end
end

function Grid:routeTrackedActorOld(actorId, destination)
  self.GameControl:setBusy("routing")
  local route = {}
  local correctedDest = self:snapToGrid(destination)
  local currentRoute = self.routes[actorId]
  local current = (currentRoute ~= nil) and { x = currentRoute[#currentRoute].x, y = currentRoute[#currentRoute].y } or
  self:getTrackedActorLocation(actorId)
  local currentOrigin = { x = current.x, y = current.y }

  while current.x ~= correctedDest.x or current.y ~= correctedDest.y do
    local xDir = (correctedDest.x > current.x) and 1 or (correctedDest.x < current.x) and -1 or 0
    local yDir = (correctedDest.y > current.y) and 1 or (correctedDest.y < current.y) and -1 or 0
    local xNext = current.x + (xDir * self.gridStep)
    local yNext = current.y + (yDir * self.gridStep)
    local xNextDiff = math.abs(correctedDest.x - xNext)
    local yNextDiff = math.abs(correctedDest.y - yNext)

    local newPosition = {}
    if xNextDiff <= yNextDiff and xDir ~= 0 or xDir ~= 0 then
      newPosition = self:snapToGrid({ x = xNext })
    elseif yDir ~= 0 then
      newPosition = self:snapToGrid({ y = yNext })
    end

    current.x = nilOr(newPosition.x, current.x)
    current.y = nilOr(newPosition.y, current.y)

    table.insert(route, { from = { x = currentOrigin.x, y = currentOrigin.y }, x = newPosition.x, y = newPosition.y })
    currentOrigin = {
      x = nilOr(newPosition.x, current.x),
      y = nilOr(newPosition.y, current.y)
    }
  end

  if currentRoute ~= nil then
    for _, v in ipairs(route) do
      table.insert(currentRoute, v)
    end
  else
    self.routes[actorId] = route
  end

  -- Debugging output
  if my.variables.debug == 1 then
    debug("Route created for actor id: ", actorId)
    for i, pos in ipairs(route) do
      debug("From x: ", pos.from.x, "From y: ", pos.from.y, "To x: ", pos.x, "To y: ", pos.y)
    end
  end
end

function Grid:snapToGrid(location)
  local function snapAxisToGrid(value, offset)
    if value == nil then return nil end
    local relativeValue = (value - offset) / self.gridStep
    local closestStep = math.floor(relativeValue + 0.5)
    local closestStep = offset + closestStep * self.gridStep
    return closestStep
  end

  local x = snapAxisToGrid(location.x, self.offsetX)
  local y = snapAxisToGrid(location.y, self.offsetY)

  return { x = x, y = y }
end

function Grid:getSurroundingTiles(position, steps)
  local coordinates = {}
  for dx = -steps, steps do
    for dy = -steps, steps do
      if not (dx == 0 and dy == 0) then -- Skip the centre point
        if math.abs(dx) + math.abs(dy) <= steps then
          local location = {
            x = position.x + (dx * self.gridStep),
            y = position.y + (dy * self.gridStep)
          }
          local coords = self:snapToGrid(location)
          table.insert(coordinates, coords)
        end
      end
    end
  end
  return coordinates
end

function Grid:isTileOccupied(location)
  for _, a in pairs(self.tracked) do
    if (a.actor.layout.x == location.x) and (a.actor.layout.y == location.y) then
      return a.actor
    else
      return false
    end
  end
end

function Grid:trackActor(actor)
  if self.tracked[actor.actorId] ~= nil then
    self:updateActorTracking(actor.actorId, true)
    return
  end
  actor:addTag("tracked")
  actor:addTag("id_" .. actor.actorId)
  self.tracked[actor.actorId] = {actor = actor, inViewport = true}
  debug("Tracking ", actor, "with id: ", actor.actorId)
end

function Grid:untrackActor(actorId)
  self.tracked[actorId] = nil
end

function Grid:updateActorTracking(actorId, inViewport)
  self.tracked[actorId].inViewport = inViewport
end

function Grid:getTrackedActor(id)
  return self.tracked[id].actor
end

function Grid:isTrackedActorInViewport(actorId)
  return tracked[actorId].inViewport
end

function Grid:getActorsInViewport(tag)
  local actors = {}
  for _, a in pairs(self.tracked) do
    if ((tag == nil) and a.inViewport) or 
      (a.inViewport and a.actor:hasTag(tag)) then
      table.insert(actors, a.actor)
    end
  end
  return actors
end

function Grid:getTrackedActorLocation(actorId)
  local actor = self.tracked[actorId].actor
  return { x = actor.layout.x, y = actor.layout.y }
end

function Grid:removeRouteForId(id)
  self.routes[id] = nil
end

function Grid:getPlayerActor()
  local playerActor = castle.actorsWithTag("player")[1]
  if Grid.tracked[playerActor.actorId] == nil then
    Grid:trackActor(playerActor)
  end
  return playerActor
end

function debug(...)
  if my.variables.debug == 1 then
    print(...)
  end
end

function nilOr(a, b)
  return (a ~= nil) and a or b
end

function count(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

local moveTargetId

-- todo: gameloop queue, inventory

-- Track actors by adding tag 'tracked' and adding an "id" variable
--

function onCreate()
  my.Grid = Grid
  castle.sendTriggerMessage("grid_init")
end

function onUpdate()
  if GameControl == nil or Grid.moveActors == false then return end
  -- Check for routes and control actors
  local routeCount = 0
  for id, route in pairs(Grid.routes) do
    routeCount = routeCount + 1
    if #route > 0 then
      local pos = route[1]
      local actor = Grid:getTrackedActor(id)

      local axis = pos.x and "x" or "y"
      local destinationValue = pos[axis]
      local originValue = pos.from[axis]
      local currentPos = actor.layout[axis]
      local diff = destinationValue - currentPos

      -- Use diff to check movement direction
      local enroute = ((diff ~= 0) and (currentPos - originValue) * diff > 0) or originValue == currentPos
      if enroute then
        if math.abs(actor.fixedMotion["v" .. axis]) ~= actor.variables.speed then
          print("setting sail to ", axis, " ", destinationValue)
          actor.fixedMotion["v" .. axis] = (diff >= 0 and 1 or -1) * actor.variables.speed
        end
      else
        print("arrived at ", axis, " ", destinationValue)
        -- Stop motion when close enough and update layout
        actor.fixedMotion["v" .. axis] = 0
        actor.layout[axis] = destinationValue

        -- Remove the current position from the route
        table.remove(route, 1)

        -- Remove route if empty
        if #route == 0 then
          Grid:removeRouteForId(id)
        end
      end
    end
  end
  if routeCount == 0 then
    GameControl:setDone("routing")
  end
end

function onMessage(message, triggeringActor)
  -- simple messages
  if message == "emit" then
    local x = castle.getTouch().x
    local y = castle.getTouch().y
    local location = Grid:snapToGrid({x = x, y = y})
    GameControl:handleGridTap(location)
    return
  end

  if message == "tracking_enter" then
    Grid:trackActor(triggeringActor)
  end

  if message == "tracking_remove" then
    Grid:untrackActor(triggeringActor.actorId)
  end

  if message == "tracking_leave" then
    Grid:updateActorTracking(triggeringActor.actorId, false)
  end

  if message == "game_loop_init" then
    if GameControl ~= nil then return end
    print("got game control")
    GameControl = triggeringActor.GameControl
    Grid.GameControl = GameControl
  end

  -- messages with arguments
  local request = {}
  for str in string.gmatch(message, "[^%s]+") do
    table.insert(request, str)
  end

  if request[1] == "move_select" then
    local currentTargetId = moveTargetId
    if request[2] == "me" then
      moveTargetId = triggeringActor.variables.id
    else
      if request[2] == nil then
        print("move_select requires an argument, either 'me' or a tag")
        return
      end
      moveTargetId = request[2]
    end
    if currentTargetId == moveTargetId then return end
    local moveTarget = Grid:getTrackedActor(moveTargetId)
    createMovementTiles(moveTarget.layout.x, moveTarget.layout.y, moveTargetId, moveTarget.variables.mobility)
    moveTargetId = nil
  end

  if request[1] == "route_request" then
    if request[2] == "me" then
      if #request == 2 then
        initRoute(triggeringActor.layout, nil)
      else
        initRoute(triggeringActor.layout, request[3])
      end
    elseif request[2] == "last" then
      local location = {
        x = my.variables.event_x,
        y = my.variables.event_y
      }
      initRoute(location, request[3])
    elseif request[2] == "event" then
      local location = {
        x = triggeringActor.variables.event_x,
        y = triggeringActor.variables.event_y
      }
      local targetTag
      if request[3] == "event_id" then
        local targetId = triggeringActor.variables.event_id
        targetTag = "id_" .. tostring(targetId)
      elseif request[3] ~= nil then
        targetTag = request[3]
      end
      initRoute(location, targetTag)
    else
      local target = castle.actorsWithTag("move_target")[1]
      initRoute(target.layout, nil)
    end
  end
end

function initRoute(location, tag)
  local observingActors = (tag == nil)
  and castle.actorsWithTag("move_request")
  or castle.actorsWithTag(tag)
  for _, actor in observingActors do
    local trackedId = actor.variables.id
    Grid:routeTrackedActor(trackedId, location)
  end
end

function Grid:createMovementTiles(x, y, targetId, steps)
  local tilePositions = self:getSurroundingTiles({ x = x, y = y }, steps)
  for _, pos in ipairs(tilePositions) do
    self:createSelectTile(pos.x, pos.y, targetId)
  end
end

function Grid:createSelectTile(x, y, targetId)
  if self:isTileOccupied({ x = x, y = y }) then return end
  local tile = castle.createActor("Select Tile", x, y)
  tile.target = targetId
  tile.gridControl = self
  tile.GameControl = GameControl
  tile:moveToFront()
end

function printTable(t)
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(k, ": ")
      printTable(v)
    else
      print(k, v)
    end
  end
end