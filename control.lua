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
      copy_platform_index = nil,
      cached_blueprint_string = nil,
      panel_manually_closed = true,
      debug_logging = false
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
    copy_platform_index = nil,
    cached_blueprint_string = nil,
    panel_manually_closed = true,
    debug_logging = false
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

  -- Get target planet surface where platform will be launched from
  -- This works regardless of where the player is currently viewing from (Remote View, space, etc.)
  local player_data = storage.player_data[player.index]
  local planet_name = player_data.target_planet or "nauvis"
  local planet = game.planets[planet_name]

  if not planet or not planet.surface then
    return false
  end

  local target_surface = planet.surface
  local surface_name = target_surface.name

  -- force.logistic_networks is a dictionary[string → array[LuaLogisticNetwork]] grouped by surface name
  -- Access networks for the target surface directly using surface name as key
  local networks = force.logistic_networks[surface_name]

  if networks then
    for _, network in pairs(networks) do
      local available = network.get_item_count({name = starter_pack_name, quality = quality_name})
      if available > 0 then
        return true
      end
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

--- Apply cached blueprint to target platform
--- @param player_index uint The player index
--- @param target_platform LuaSpacePlatform The target platform
--- @return boolean success Whether copy succeeded
local function copy_platform_structure(player_index, target_platform)
  local player = game.players[player_index]
  local player_data = storage.player_data[player_index]
  local blueprint_string = player_data.cached_blueprint_string

  if not blueprint_string then
    if player and player_data and player_data.debug_logging then
      player.print("[∞ SPA] DEBUG: No cached blueprint string")
    end
    return false
  end

  local target_surface = target_platform.surface
  if not target_surface or not target_surface.valid then
    if player and player_data and player_data.debug_logging then
      player.print("[∞ SPA] DEBUG: Target surface not valid")
    end
    return false
  end

  if player and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Creating blueprint inventory...")
  end

  -- Create temporary blueprint from stored string
  local inventory = game.create_inventory(1)
  if not inventory then
    if player then
      player.print("[∞ SPA] ERROR: Failed to create inventory")
    end
    return false
  end

  inventory.insert({name = "blueprint"})
  local blueprint = inventory[1]

  if not blueprint or not blueprint.valid_for_read then
    if player then
      player.print("[∞ SPA] ERROR: Blueprint item not valid")
    end
    inventory.destroy()
    return false
  end

  if player and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Importing blueprint...")
  end

  -- Import the cached blueprint - CHECK RETURN VALUE!
  local import_result = blueprint.import_stack(blueprint_string)
  if import_result ~= 0 then
    if player then
      player.print("[∞ SPA] ERROR: Blueprint import failed with code: " .. tostring(import_result))
    end
    inventory.destroy()
    return false
  end

  if player and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Building blueprint on platform...")
  end

  -- Build on target
  local built_entities = blueprint.build_blueprint{
    surface = target_surface,
    force = target_platform.force,
    position = {x = 0, y = 0},
    build_mode = defines.build_mode.superforced,
    raise_built = true
  }

  inventory.destroy()

  if not built_entities then
    if player then
      player.print("[∞ SPA] ERROR: build_blueprint returned nil")
    end
    return false
  end

  if #built_entities == 0 then
    if player then
      player.print("[∞ SPA] WARNING: build_blueprint returned 0 entities")
    end
    return false
  end

  if player and player_data and player_data.debug_logging then
    player.print("[∞ SPA] SUCCESS: Built " .. #built_entities .. " entities on platform")
  end

  -- Pause platform to prevent movement during construction
  target_platform.paused = true

  -- Count initial ghost entities
  local ghost_count = target_surface.count_entities_filtered{name = "entity-ghost"}

  if player and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Platform paused with " .. ghost_count .. " ghosts pending construction")
  end

  return true
end

--- Activate a platform (unpause) after construction completes
--- @param platform LuaSpacePlatform The platform to activate
--- @param player_index uint The player index
--- @param reason string Reason for activation (e.g., "construction complete", "timeout")
local function activate_platform(platform, player_index, reason)
  if not platform or not platform.valid then
    return false
  end

  -- Unpause to enable automatic mode
  platform.paused = false

  local player = game.players[player_index]
  local player_data = storage.player_data[player_index]
  if player and player.valid and player_data and player_data.debug_logging then
    player.print("[∞ Space Platform Automation] Platform activated: " .. platform.name .. " (reason: " .. reason .. ")")
  end

  -- Clean up pending entry if nothing else is pending
  local pending = storage.pending_platforms[platform.index]
  if pending then
    pending.needs_activation = false

    -- Remove from pending if no other flags are set
    if not pending.needs_copy and not pending.needs_activation then
      storage.pending_platforms[platform.index] = nil
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

  -- Must have cached blueprint
  if not player_data.cached_blueprint_string then
    return false, "No platform blueprinted"
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

    local player_data = storage.player_data[player.index]
    if player_data and player_data.debug_logging then
      player.print("[∞ Space Platform Automation] Created platform: " .. platform_name)
    end
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

  -- Check pending platforms every 60 ticks (~1 second) for blueprint application
  if event.tick % 60 == 0 then
    for platform_index, pending in pairs(storage.pending_platforms) do
      if pending.needs_copy then
        -- Find the platform
        local platform = nil
        local force = game.forces[pending.force_index]
        if force and force.valid then
          for _, p in pairs(force.platforms) do
            if p.index == platform_index and p.valid then
              platform = p
              break
            end
          end
        end

        if platform then
          -- Check if surface and hub are ready
          if platform.surface and platform.surface.valid and platform.hub and platform.hub.valid then
            local player = game.players[pending.player_index]
            local player_data = storage.player_data[pending.player_index]
            if player and player.valid and player_data and player_data.debug_logging then
              player.print("[∞ SPA] DEBUG: Periodic check found ready platform, attempting copy...")
            end

            -- Try to apply blueprint
            local success = copy_platform_structure(pending.player_index, platform)

            if success then
              local player = game.players[pending.player_index]
              local player_data = storage.player_data[pending.player_index]
              if player and player.valid and player_data and player_data.debug_logging then
                player.print("[∞ Space Platform Automation] Platform structure copied to: " .. platform.name)
              end

              -- Mark copy complete and set up activation tracking
              pending.needs_copy = false
              pending.needs_activation = true
              pending.last_ghost_count = platform.surface.count_entities_filtered{name = "entity-ghost"}
              pending.no_progress_ticks = 0
            end
          end
        end
      end
    end
  end

  -- Monitor construction progress and activate platforms every 120 ticks (~2 seconds)
  if event.tick % 120 == 0 then
    for platform_index, pending in pairs(storage.pending_platforms) do
      if pending.needs_activation then
        -- Find the platform
        local platform = nil
        local force = game.forces[pending.force_index]
        if force and force.valid then
          for _, p in pairs(force.platforms) do
            if p.index == platform_index and p.valid then
              platform = p
              break
            end
          end
        end

        if platform and platform.surface and platform.surface.valid then
          -- Count current ghost entities
          local current_ghosts = platform.surface.count_entities_filtered{name = "entity-ghost"}

          -- Construction complete - activate immediately
          if current_ghosts == 0 then
            activate_platform(platform, pending.player_index, "construction complete")

          -- Check for construction progress
          elseif current_ghosts == pending.last_ghost_count then
            -- No progress made - increment stall counter
            pending.no_progress_ticks = pending.no_progress_ticks + 120

            -- Timeout after 5 minutes (18,000 ticks) of no progress
            if pending.no_progress_ticks >= 18000 then
              activate_platform(platform, pending.player_index, "timeout - construction stalled")
            end

          else
            -- Progress made - reset stall counter and update ghost count
            pending.no_progress_ticks = 0
            pending.last_ghost_count = current_ghosts
          end
        end
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

  -- DEBUG: Log state changes
  local player = game.players[pending.player_index]
  local player_data = storage.player_data[pending.player_index]
  if player and player.valid and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Platform state changed to: " .. tostring(event.new_state))
  end

  -- Check if platform is in a ready state (including post-creation states)
  local ready_states = {
    defines.space_platform_state.no_schedule,
    defines.space_platform_state.no_path,
    defines.space_platform_state.waiting_at_station,
    defines.space_platform_state.on_the_path,
    defines.space_platform_state.waiting_for_departure,
    defines.space_platform_state.paused
  }

  local is_ready = false
  for _, state in ipairs(ready_states) do
    if event.new_state == state then
      is_ready = true
      break
    end
  end

  if not is_ready then
    if player and player.valid and player_data and player_data.debug_logging then
      player.print("[∞ SPA] DEBUG: Platform not in ready state yet")
    end
    return
  end

  -- CRITICAL: Check if surface actually exists and hub is ready
  if not platform.surface or not platform.surface.valid then
    if player and player.valid and player_data and player_data.debug_logging then
      player.print("[∞ SPA] DEBUG: Surface not valid yet")
    end
    return
  end

  if not platform.hub or not platform.hub.valid then
    if player and player.valid and player_data and player_data.debug_logging then
      player.print("[∞ SPA] DEBUG: Hub not valid yet")
    end
    return
  end

  if player and player.valid and player_data and player_data.debug_logging then
    player.print("[∞ SPA] DEBUG: Platform ready! Attempting to copy...")
  end

  -- Apply cached blueprint to platform
  local success = copy_platform_structure(pending.player_index, platform)

  if success then
    local player = game.players[pending.player_index]
    local player_data = storage.player_data[pending.player_index]
    if player and player.valid and player_data and player_data.debug_logging then
      player.print("[∞ Space Platform Automation] Platform structure copied to: " .. platform.name)
    end

    -- Mark copy complete and set up activation tracking
    pending.needs_copy = false
    pending.needs_activation = true
    pending.last_ghost_count = platform.surface.count_entities_filtered{name = "entity-ghost"}
    pending.no_progress_ticks = 0
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
