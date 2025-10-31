-- GUI management for ∞ Space Platform Automation
-- Screen GUI with Remote View visibility control

local naming = require("naming")
local gui = {}

local PANEL_NAME = "spa_main_panel"
local TOGGLE_BUTTON_NAME = "spa_toggle_button"

--- Get all space locations for dropdown
--- @param player LuaPlayer The player
--- @return table Array of space location names
local function get_space_location_dropdown_items(player)
  local items = {}
  local mapping = {}

  for name, proto in pairs(prototypes.space_location) do
    local display_name = proto.localised_name or name
    table.insert(items, display_name)
    mapping[#items] = name
  end

  return items, mapping
end

--- Get force platforms for copy dropdown
--- @param force LuaForce The force
--- @return table Array of platform names
local function get_platform_dropdown_items(force)
  local items = {{"space-platform-automation.panel-no-copy"}}
  local mapping = {[1] = nil}

  for _, platform in pairs(force.platforms) do
    if platform and platform.valid then
      table.insert(items, platform.name)
      mapping[#items] = platform.index
    end
  end

  return items, mapping
end

--- Blueprint a platform and store it for reuse
--- @param player LuaPlayer The player
--- @param platform_index uint The platform to blueprint
--- @return boolean success Whether blueprint succeeded
local function cache_platform_blueprint(player, platform_index)
  -- Find the platform
  local source_platform = nil
  for _, p in pairs(player.force.platforms) do
    if p.index == platform_index then
      source_platform = p
      break
    end
  end

  if not source_platform or not source_platform.valid then
    return false
  end

  local source_surface = source_platform.surface
  if not source_surface or not source_surface.valid then
    player.print("[∞ Space Platform Automation] Error: Source platform surface not ready")
    return false
  end

  -- Calculate bounding box
  local entities = source_surface.find_entities()
  if #entities == 0 then
    storage.player_data[player.index].cached_blueprint_string = nil
    return true
  end

  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge

  for _, entity in pairs(entities) do
    if entity.valid then
      local pos = entity.position
      min_x = math.min(min_x, pos.x - 2)
      min_y = math.min(min_y, pos.y - 2)
      max_x = math.max(max_x, pos.x + 2)
      max_y = math.max(max_y, pos.y + 2)
    end
  end

  -- Create and export blueprint
  local inventory = game.create_inventory(1)
  if not inventory then return false end

  inventory.insert({name = "blueprint"})
  local blueprint = inventory[1]

  if not blueprint or not blueprint.valid_for_read then
    inventory.destroy()
    return false
  end

  blueprint.create_blueprint{
    surface = source_surface,
    force = source_platform.force,
    area = {{min_x, min_y}, {max_x, max_y}},
    always_include_tiles = true,
    include_entities = true,
    include_modules = true,
    include_station_names = true,
    include_trains = true,
    include_fuel = true
  }

  -- Export to string for storage
  local blueprint_string = blueprint.export_stack()
  inventory.destroy()

  storage.player_data[player.index].cached_blueprint_string = blueprint_string

  local player_data = storage.player_data[player.index]
  if player_data and player_data.debug_logging then
    player.print("[∞ Space Platform Automation] Platform blueprinted successfully")
  end

  return true
end

--- Get status text for display
--- @param player LuaPlayer The player
--- @return LocalisedString Status text
function gui.get_status_text(player)
  local player_data = storage.player_data[player.index]

  if not player_data.copy_platform_index then
    return {"space-platform-automation.status-no-platform"}
  end

  if not player_data.enabled then
    return {"space-platform-automation.status-disabled"}
  end

  -- Count pending platforms
  local pending_count = 0
  for _, pending in pairs(storage.pending_platforms) do
    if pending.force_index == player.force.index and pending.needs_copy then
      pending_count = pending_count + 1
    end
  end

  if pending_count > 0 then
    return {"space-platform-automation.status-pending", pending_count}
  end

  return {"space-platform-automation.status-ready"}
end

--- Create toggle button in top bar
--- @param player LuaPlayer The player
function gui.create_toggle_button(player)
  if player.gui.top[TOGGLE_BUTTON_NAME] then
    return
  end

  player.gui.top.add{
    type = "sprite-button",
    name = TOGGLE_BUTTON_NAME,
    sprite = "item/space-platform-starter-pack",
    style = "slot_button",
    tooltip = {"space-platform-automation.toggle-tooltip"}
  }
end

--- Create the main screen panel GUI (floating, shown in Remote View)
--- @param player LuaPlayer The player
function gui.create_main_panel(player)
  -- Clean up existing
  if player.gui.screen[PANEL_NAME] then
    player.gui.screen[PANEL_NAME].destroy()
  end

  local player_data = storage.player_data[player.index]

  -- Create main frame as floating screen GUI
  local frame = player.gui.screen.add{
    type = "frame",
    name = PANEL_NAME,
    direction = "vertical",
    caption = {"space-platform-automation.panel-title"}
  }

  -- Position to right side of screen
  frame.location = {x = 220, y = 100}

  -- Start closed (respects panel_manually_closed preference)
  frame.visible = false

  -- Enable Auto-Creation section (moved to top, bold)
  local enable_flow = frame.add{
    type = "flow",
    direction = "horizontal"
  }
  enable_flow.style.vertical_align = "center"

  local enable_label = enable_flow.add{
    type = "label",
    caption = {"space-platform-automation.panel-enabled"},
    style = "bold_label"
  }

  -- Colored indicator sprite-button
  local indicator_sprite = player_data.enabled and "utility/check_mark_green" or "utility/not_available"
  enable_flow.add{
    type = "sprite-button",
    name = "spa_enable_indicator",
    sprite = indicator_sprite,
    style = "slot_button"
  }

  -- Debug logging toggle (smaller, less prominent)
  frame.add{
    type = "checkbox",
    name = "spa_debug_checkbox",
    caption = {"space-platform-automation.panel-debug"},
    state = player_data.debug_logging or false
  }

  frame.add{type = "line"}

  -- Platform copy dropdown
  local copy_flow = frame.add{
    type = "flow",
    direction = "horizontal"
  }
  copy_flow.add{
    type = "label",
    caption = {"space-platform-automation.panel-copy"}
  }

  local platform_items, platform_mapping = get_platform_dropdown_items(player.force)
  storage.player_data[player.index].platform_mapping = platform_mapping

  copy_flow.add{
    type = "drop-down",
    name = "spa_copy_platform_dropdown",
    items = platform_items,
    selected_index = 1
  }

  -- Planet dropdown (shortened)
  local planet_flow = frame.add{
    type = "flow",
    direction = "horizontal"
  }
  planet_flow.add{
    type = "label",
    caption = {"space-platform-automation.panel-planet"}
  }

  local planet_items, planet_mapping = get_space_location_dropdown_items(player)
  storage.player_data[player.index].planet_mapping = planet_mapping

  local planet_dropdown = planet_flow.add{
    type = "drop-down",
    name = "spa_planet_dropdown",
    items = planet_items,
    selected_index = 1
  }
  planet_dropdown.style.width = 150

  frame.add{type = "line"}

  -- Naming section
  frame.add{
    type = "label",
    caption = {"space-platform-automation.panel-naming-section"},
    style = "caption_label"
  }

  local naming_flow = frame.add{
    type = "flow",
    direction = "vertical"
  }

  naming_flow.add{
    type = "label",
    caption = {"space-platform-automation.panel-naming-pattern"}
  }

  local pattern_field = naming_flow.add{
    type = "textfield",
    name = "spa_naming_pattern",
    text = player_data.custom_name_pattern or "Platform-{counter}"
  }
  pattern_field.style.width = 250

  local preview_label = naming_flow.add{
    type = "label",
    name = "spa_naming_preview",
    caption = {"space-platform-automation.panel-naming-preview", naming.preview_next_name(player.index)}
  }
  preview_label.style.font_color = {r = 0.5, g = 0.8, b = 1}

  frame.add{type = "line"}

  -- Status
  frame.add{
    type = "label",
    name = "spa_status_label",
    caption = gui.get_status_text(player)
  }

  -- Description at bottom
  local description = frame.add{
    type = "label",
    caption = {"space-platform-automation.panel-description"}
  }
  description.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
end

--- Toggle panel visibility
--- @param player LuaPlayer The player
function gui.toggle_panel(player)
  local panel = player.gui.screen[PANEL_NAME]
  local player_data = storage.player_data[player.index]

  if panel then
    panel.visible = not panel.visible
    -- Track manual close state
    player_data.panel_manually_closed = not panel.visible
  else
    gui.create_main_panel(player)
    player_data.panel_manually_closed = false
  end
end

--- Refresh panel
--- @param player LuaPlayer The player
function gui.refresh_panel(player)
  if player.gui.screen[PANEL_NAME] then
    gui.create_main_panel(player)
  end
end

--- Update panel visibility based on controller type
--- @param player LuaPlayer The player
function gui.update_panel_visibility(player)
  local panel = player.gui.screen[PANEL_NAME]
  local button = player.gui.top[TOGGLE_BUTTON_NAME]
  local player_data = storage.player_data[player.index]
  local is_remote = (player.controller_type == defines.controllers.remote)

  -- Update toggle button visibility (only show in remote view)
  if button then
    button.visible = is_remote
  end

  -- Update panel visibility
  if panel then
    if is_remote then
      -- In remote view: respect user preference
      panel.visible = not player_data.panel_manually_closed
    else
      -- Not in remote view: always force closed
      panel.visible = false
    end
  end
end

--- Update status label only
--- @param player LuaPlayer The player
function gui.update_status(player)
  local panel = player.gui.screen[PANEL_NAME]
  if panel then
    local status_label = panel["spa_status_label"]
    if status_label then
      status_label.caption = gui.get_status_text(player)
    end
  end
end

--- Update enable indicator sprite
--- @param player LuaPlayer The player
function gui.update_enable_indicator(player)
  local panel = player.gui.screen[PANEL_NAME]
  local player_data = storage.player_data[player.index]

  if panel then
    -- Navigate through the flow to find the sprite-button
    local enable_flow = panel.children[1]  -- First element is the enable flow
    if enable_flow and enable_flow.valid and enable_flow.children[2] then
      local indicator = enable_flow.children[2]  -- Second element is the sprite-button
      if indicator and indicator.name == "spa_enable_indicator" then
        indicator.sprite = player_data.enabled and "utility/check_mark_green" or "utility/not_available"
      end
    end
  end
end

--- Initialize GUI for player
--- @param player LuaPlayer The player
function gui.initialize_player(player)
  gui.create_toggle_button(player)
  gui.create_main_panel(player)
end

--- Handle GUI click events
--- @param event EventData The event
function gui.on_gui_click(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  local element = event.element
  if not element or not element.valid then return end

  if element.name == TOGGLE_BUTTON_NAME then
    gui.toggle_panel(player)
  elseif element.name == "spa_enable_indicator" then
    -- Toggle enabled state
    local player_data = storage.player_data[player.index]
    player_data.enabled = not player_data.enabled

    -- Update indicator sprite and status
    gui.update_enable_indicator(player)
    gui.update_status(player)
  elseif element.name == "spa_debug_checkbox" then
    -- Toggle debug logging
    storage.player_data[player.index].debug_logging = element.state
  end
end

--- Handle dropdown selection changes
--- @param event EventData The event
function gui.on_gui_selection_state_changed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  local element = event.element
  if not element or not element.valid then return end

  local player_data = storage.player_data[player.index]

  if element.name == "spa_planet_dropdown" then
    local mapping = player_data.planet_mapping
    if mapping and mapping[element.selected_index] then
      player_data.target_planet = mapping[element.selected_index]
    end

  elseif element.name == "spa_copy_platform_dropdown" then
    local mapping = player_data.platform_mapping
    if mapping and mapping[element.selected_index] then
      player_data.copy_platform_index = mapping[element.selected_index]
      -- Blueprint the source platform immediately
      cache_platform_blueprint(player, player_data.copy_platform_index)
    else
      player_data.copy_platform_index = nil
      player_data.cached_blueprint_string = nil  -- Clear cached blueprint
    end
    -- Just update status, don't rebuild entire panel
    gui.update_status(player)
  end
end

--- Handle text changed events
--- @param event EventData The event
function gui.on_gui_text_changed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  local element = event.element
  if not element or not element.valid then return end

  if element.name == "spa_naming_pattern" then
    local pattern = element.text
    if pattern == "" then
      pattern = nil
    end
    storage.player_data[player.index].custom_name_pattern = pattern

    -- Update preview
    local panel = player.gui.screen[PANEL_NAME]
    if panel then
      local preview = panel["spa_naming_preview"]
      if preview then
        preview.caption = {"space-platform-automation.panel-naming-preview", naming.preview_next_name(player.index)}
      end
    end
  end
end

return gui
