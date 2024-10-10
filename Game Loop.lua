-- deck var game_state:
-- 0: free movement
-- 1: battle mode, restricted to mobility stat

GameControl = {
  GridControl = nil,
  playerActor = nil,
  targetActor = nil,
  gameState = "idle",
  busyFlags = {}
}
my.GameControl = GameControl

function GameControl:setBusy(flag)
  table.insert(self.busyFlags, flag)
end

function GameControl:setDone(flag)
  for i, v in pairs(self.busyFlags) do
    if v == flag then
      table.remove(self.busyFlags, i)
    end
  end
end

function GameControl:isBusy()
  for _, v in pairs(self.busyFlags) do
    return true
  end
  return false
end

function GameControl:handleGridTap(location)
  if self.gameState == "idle" then
    local tile = castle.createActor("Select Tile", location.x, location.y)
    tile.drawing.loopEndFrame = 4
    tile.drawing.framesPerSecond = 6
    tile.drawing.playMode = "play once"
    self.GridControl:routeTrackedActor(self.targetActor.actorId, location)
    self.gameState = "playermove"
  end
end

function init()
  print("gameloop init")
  local classId = deck.variables.character_class
  local class = (classId == 0) and "Paladin" or (classId == 1) and "Mage" or (classId == 2) and "Pyro"
  local spawnLocation = GameControl.GridControl:snapToGrid({x=0,y=0})
  GameControl.playerActor = castle.createActor(class, spawnLocation.x, spawnLocation.y)
  GameControl.targetActor = GameControl.playerActor
  castle.sendTriggerMessage("init")
end

function onCreate()
end

function onUpdate(dt)
  if GameControl:isBusy() then return end
  if GameControl.gameState == "playermove" then
    if GameControl.GridControl.routes[GameControl.playerActor.actorId] == nil then
      GameControl.gameState = "npcmove"
      castle.createTextBox("npc move")
      GameControl.GridControl.moveActors = false
      local actorsToMove = GameControl.GridControl:getActorsInViewport("enemy")
      for _, a in ipairs(actorsToMove) do
        local path = GameControl.GridControl:pathfind(a.layout, GameControl.playerActor.layout, 3)
        print(a, " ",path)
      end
      GameControl.gameState = "idle"
    end
  end
end

function onMessage(message, triggeringActor)
  if message == "grid_control_init" then
    GameControl.GridControl = triggeringActor.Grid
    init()
    return
  end
  if message == "grid_select_event" and not busy then
    my.variables.event_x = triggeringActor.layout.x
    my.variables.event_y = triggeringActor.layout.y
    if triggeringActor.variables.event_id == 0 then
      castle.sendTriggerMessage("move_player")
    else
      castle.sendTriggerMessage("move_id")
    end
    return
  end
  
end