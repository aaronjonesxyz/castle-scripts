my.InventoryControl = {
  inventory = {}
}

local inventoryControl = my.InventoryControl

function onCreate()
  local inventoryItems = retrieveBits(deck.variables.inventory_items)
  local inventoryQuantities = retrieve4BitIntegers(deck.variables.inventory_quantities)

  for i, has in ipairs(inventoryItems) do
    print(i, has)
    if (has == 1) then
      inventory[i] = inventoryQuantities[i]
    end
  end
end

function onUpdate(dt)

end

function onMessage(message, triggeringActor)
  if message == "open_inventory" then
    -- create inventory
    return
  end

  if message == "close_inventory" then
    -- remove inventory
    return
  end

  local request = {}
  for str in string.gmatch(message, "[^%s]+") do
    table.insert(request, str)
  end

  local id = tostring(triggeringActor.variables.id)

  if request[1] == "inventory_add_request" then
    local item = tonumber(request[2])
    local qty = (request[3] ~= nil) and tonumber(request[3]) or 1
    print(item, qty)
    if inventory[item] ~= nil and inventory[item] + qty > 15 then
      
      castle.sendTriggerMessage("inventory_item_full"..id)
      return
    end
    addItem(item, qty)
    castle.sendTriggerMessage("inventory_item_added"..id)
    return
  end

  if request[1] == "inventory_remove_request" then
    local item = tonumber(request[2])
    local qty = (request[3] ~= nil) and tonumber(request[3]) or 1
    if inventory[item] == nil or inventory[item] - qty < 0 then
      castle.sendTriggerMessage("insufficient_item"..id)
      return
    end
    removeItem(item, qty)
    castle.sendTriggerMessage("item_removed"..id)
    return
  end
end

function addItem(item, qty)
  if inventory[item] ~= nil then
    inventory[item] = inventory[item] + qty
  else
    inventory[item] = qty
  end
end

function removeItem(item, qty)
  if inventory[item] ~= nil and inventory[item] - qty > 0 then
    inventory[item] = inventory[item] - qty
  else
    table.remove(inventory, item)
  end
end

function storeItems()
  local inventoryQty = highestKey(inventory)
  local inventoryItems = {}
  local inventoryQtys = {}

  for i = 1, inventoryQty do
    if inventory[i] == nil or inventory[i] == 0 then
      table.insert(inventoryItems, 0)
    else
      table.insert(inventoryItems, 1)
      table.insert(inventoryQtys, inventory[i])
    end
  end

  local inventoryItemsPacked = storeBits(inventoryItems)
  local inventoryQtysPacked = store4BitIntegers(inventoryQtys)

  deck.variables.inventory_items = inventoryItemsPacked
  deck.variables.inventory_items_quantities = inventoryQtysPacked
  deck.variables.inventory_items_count = count(inventory)

  print("Stored ", #inventoryQtys, " as integers ", inventoryItemsPacked, " and ", inventoryQtysPacked)
end

function retrieve4BitIntegers(num)
  local count = numberOfBits(num) / 4
  local arr = {}
  for i = 1, count do
    arr[i] = (num // (16 ^ (i - 1))) % 16 -- Extract each 4-bit value
  end
  return arr
end

function store4BitIntegers(arr)
  local num = 0
  for i = 1, #arr do
    if arr[i] ~= nil then
      num = num + arr[i] * (16 ^ (i - 1)) -- Multiply each element by 16^(position)
    end
  end
  return num
end

function storeBits(bits)
  local num = 0
  for i = 1, #bits do
    num = num * 2 + bits[i] -- Shift left and add the current bit
  end
  return num
end

function retrieveBits(num)
  local bits = {}
  local i = 1
  local bitCount = numberOfBits(num)
  while num > 0 do
    bits[bitCount - i + 1] = num % 2 -- Insert the bits in reverse order
    num = math.floor(num / 2)        -- Divide by 2 to move to the next bit
    i = i + 1
  end
  return bits
end

function locate(table, value)
  local len = count(table)
  for i = 1, len do
    if table[i] == value then return i end
  end
  print(value .. ' not found')
  return false
end

function highestKey(tbl)
  local highest = 0
  for k in pairs(tbl) do
    highest = (highest < k) and k or highest
  end
  return highest
end

function count(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

function numberOfBits(num)
  if num == 0 then
    return 1 -- 0 is represented by 1 bit
  end
  return math.floor(math.log(num, 2)) + 1
end

my.getInventoryControl = function(self)
  return self.InventoryControl
end