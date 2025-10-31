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
    if pending.force_index == player.force.index and pending.needs_blueprint then
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

  -- Start visible if in Remote View
  frame.visible = (player.controller_type == defines.controllers.remote)

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

  -- Planet dropdown
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

  planet_flow.add{
    type = "drop-down",
    name = "spa_planet_dropdown",
    items = planet_items,
    selected_index = 1
  }

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

  -- Enable checkbox
  frame.add{
    type = "checkbox",
    name = "spa_enabled_checkbox",
    caption = {"space-platform-automation.panel-enabled"},
    state = player_data.enabled or false
  }

  -- Status
  frame.add{
    type = "label",
    name = "spa_status_label",
    caption = gui.get_status_text(player)
  }
end

--- Toggle panel visibility
--- @param player LuaPlayer The player
function gui.toggle_panel(player)
  local panel = player.gui.screen[PANEL_NAME]
  if panel then
    panel.visible = not panel.visible
  else
    gui.create_main_panel(player)
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
  if panel then
    panel.visible = (player.controller_type == defines.controllers.remote)
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
  elseif element.name == "spa_enabled_checkbox" then
    storage.player_data[player.index].enabled = element.state
    gui.update_status(player)
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
    else
      player_data.copy_platform_index = nil
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
