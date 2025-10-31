-- ∞ Space Platform Automation - Main Control Script

local naming = require("naming")
local gui = require("gui")

--- Initialize mod data on first load
script.on_init(function()
  storage.player_data = {}
  storage.pending_platforms = {}

  -- Initialize for existing players
  for _, player in pairs(game.players) do
    storage.player_data[player.index] = {
      custom_name_pattern = nil,
      platform_counter = 0,
      enabled = false,
      target_planet = "nauvis",
      copy_platform_index = nil
    }

    -- Initialize GUI
    gui.initialize_player(player)
  end
end)

--- Initialize new players
script.on_event(defines.events.on_player_created, function(event)
  storage.player_data[event.player_index] = {
    custom_name_pattern = nil,
    platform_counter = 0,
    enabled = false,
    target_planet = "nauvis",
    copy_platform_index = nil
  }

  local player = game.players[event.player_index]
  if player and player.valid then
    gui.initialize_player(player)
  end
end)

--- Get check interval from settings
--- @return uint Tick interval
local function get_check_interval()
  return settings.global["spa-check-interval"].value
end

--- Get source platform for a player
--- @param player LuaPlayer The player
--- @return LuaSpacePlatform|nil The source platform
local function get_source_platform(player)
  local player_data = storage.player_data[player.index]
  local source_index = player_data.copy_platform_index

  if not source_index then
    return nil
  end

  for _, platform in pairs(player.force.platforms) do
    if platform.index == source_index and platform.valid then
      return platform
    end
  end

  return nil
end

--- Get starter pack from source platform with safe fallback
--- @param player LuaPlayer The player
--- @return table Starter pack specification {name, quality}
local function get_source_platform_starter_pack(player)
  local source = get_source_platform(player)

  -- Fallback to default if no source or no starter pack
  if not source or not source.starter_pack then
    return {
      name = "space-platform-starter-pack",
      quality = "normal"
    }
  end

  return source.starter_pack
end

--- Check if a starter pack is available in logistics for a player
--- @param force LuaForce The force to check
--- @param player LuaPlayer The player requesting creation
--- @param starter_pack table The starter pack specification {name, quality}
--- @return boolean available Whether starter pack is available
local function has_starter_pack_available(force, player, starter_pack)
  local starter_pack_name = starter_pack.name
  local quality_name = starter_pack.quality

  -- Check if player has item in inventory
  local character = player.character
  if character then
    local inventory = character.get_main_inventory()
    if inventory then
      local count = inventory.get_item_count({name = starter_pack_name, quality = quality_name})
      if count > 0 then
        return true
      end
    end
  end

  -- Check logistics network at player location
  local surface = player.surface
  local position = player.position
  local networks = surface.find_logistic_networks_by_construction_area(position, force)

  for _, network in pairs(networks) do
    local available = network.get_item_count({name = starter_pack_name, quality = quality_name})
    if available > 0 then
      return true
    end
  end

  return false
end

--- Get player's configured planet/space location name
--- @param player LuaPlayer The player
--- @return string The space location name
local function get_player_planet(player)
  local player_data = storage.player_data[player.index]
  local planet_name = player_data.target_planet or "nauvis"

  -- Validate planet exists
  if game.planets[planet_name] then
    return planet_name
  end

  -- Fallback to nauvis
  return "nauvis"
end

--- Copy entities from source platform to target platform
--- @param source_platform LuaSpacePlatform The source platform
--- @param target_platform LuaSpacePlatform The target platform
--- @return boolean success Whether copy succeeded
local function copy_platform_structure(source_platform, target_platform)
  local source_surface = source_platform.surface
  local target_surface = target_platform.surface

  if not source_surface or not source_surface.valid then
    return false
  end

  if not target_surface or not target_surface.valid then
    return false
  end

  -- Get all entities on source platform
  local entities = source_surface.find_entities()

  -- Clone each entity to target platform
  for _, entity in pairs(entities) do
    if entity.valid and entity.name ~= "space-platform-hub" then
      entity.clone{
        position = entity.position,
        surface = target_surface,
        force = target_platform.force
      }
    end
  end

  return true
end

--- Check if platform can be created for a player
--- @param player_index uint The player index
--- @return boolean can_create Whether platform can be created
--- @return string|nil reason Reason if cannot create
local function can_create_platform(player_index)
  local player_data = storage.player_data[player_index]
  local player = game.players[player_index]

  if not player or not player.valid then
    return false, "Player invalid"
  end

  -- Check if player has auto-creation enabled
  if not player_data.enabled then
    return false, "Player has auto-creation disabled"
  end

  -- Must have copy platform configured
  if not player_data.copy_platform_index then
    return false, "No platform selected"
  end

  -- Get source platform
  local source_platform = get_source_platform(player)
  if not source_platform then
    return false, "Source platform no longer exists"
  end

  -- Check starter pack availability (using source platform's pack with safe fallback)
  local starter_pack = get_source_platform_starter_pack(player)
  if not has_starter_pack_available(player.force, player, starter_pack) then
    return false, "No starter packs available"
  end

  return true
end

--- Create a space platform for a player
--- @param player LuaPlayer The player
--- @return LuaSpacePlatform|nil The created platform
local function create_platform(player)
  local planet = get_player_planet(player)
  if not planet then
    player.print("[∞ Space Platform Automation] Error: Could not find target planet")
    return nil
  end

  local source_platform = get_source_platform(player)
  if not source_platform then
    player.print("[∞ Space Platform Automation] Error: Source platform no longer exists")
    return nil
  end

  local platform_name = naming.generate_platform_name(player.index)

  -- Create platform using source platform's starter pack with safe fallback (includes quality!)
  local starter_pack = get_source_platform_starter_pack(player)
  local platform = player.force.create_space_platform{
    name = platform_name,
    planet = planet,
    starter_pack = starter_pack
  }

  if platform then
    storage.pending_platforms[platform.index] = {
      force_index = player.force.index,
      player_index = player.index,
      created_tick = game.tick,
      needs_copy = true,
      copy_source_index = source_platform.index
    }

    player.print("[∞ Space Platform Automation] Created platform: " .. platform_name)
  end

  return platform
end

--- Periodic check for platform creation opportunities and GUI visibility
script.on_event(defines.events.on_tick, function(event)
  local interval = get_check_interval()

  -- Check platform creation at configured interval
  if event.tick % interval == 0 then
    for player_index, player in pairs(game.players) do
      if player.valid and player.connected then
        local can_create, reason = can_create_platform(player_index)

        if can_create then
          create_platform(player)
        end
      end
    end
  end

  -- Update GUI visibility every 30 ticks (~0.5 seconds)
  if event.tick % 30 == 0 then
    for player_index, player in pairs(game.players) do
      if player.valid and player.connected then
        gui.update_panel_visibility(player)
      end
    end
  end
end)

--- Handle platform state changes for copy application
script.on_event(defines.events.on_space_platform_changed_state, function(event)
  local platform = event.platform
  if not platform or not platform.valid then
    return
  end

  local pending = storage.pending_platforms[platform.index]
  if not pending or not pending.needs_copy then
    return
  end

  -- Check if platform is in a ready state
  local ready_states = {
    defines.space_platform_state.waiting_at_station,
    defines.space_platform_state.on_the_path,
    defines.space_platform_state.waiting_for_departure
  }

  local is_ready = false
  for _, state in ipairs(ready_states) do
    if event.new_state == state then
      is_ready = true
      break
    end
  end

  if not is_ready then
    return
  end

  -- Find source platform and copy structure
  local source_platform = nil
  for _, p in pairs(platform.force.platforms) do
    if p.index == pending.copy_source_index then
      source_platform = p
      break
    end
  end

  if not source_platform or not source_platform.valid then
    return
  end

  local success = copy_platform_structure(source_platform, platform)

  if success then
    local player = game.players[pending.player_index]
    if player and player.valid then
      player.print("[∞ Space Platform Automation] Platform structure copied to: " .. platform.name)
    end

    -- Mark as complete
    pending.needs_copy = false
    storage.pending_platforms[platform.index] = nil
  end
end)

--- Handle GUI click events
script.on_event(defines.events.on_gui_click, function(event)
  gui.on_gui_click(event)
end)

--- Handle GUI selection state changed (dropdowns)
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  gui.on_gui_selection_state_changed(event)
end)

--- Handle GUI text changed events
script.on_event(defines.events.on_gui_text_changed, function(event)
  gui.on_gui_text_changed(event)
end)
