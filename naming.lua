-- Pattern validation and name generation for space platforms

local naming = {}

-- Safe default pattern
local SAFE_DEFAULT = "Platform-{counter}"

-- Valid pattern variables
local VALID_VARIABLES = {"{counter}", "{tick}", "{player}", "{random}"}

--- Validates a naming pattern and returns a safe version
--- @param pattern string The pattern to validate
--- @return boolean valid Whether the pattern is valid
--- @return string validated_pattern The validated/corrected pattern
function naming.validate_pattern(pattern)
  -- Check for nil/empty
  if not pattern or pattern == "" then
    return false, SAFE_DEFAULT
  end

  -- Check for invalid characters (prevent exploits)
  -- Allow: alphanumeric, dash, underscore, space, braces
  if pattern:match("[^%w%-%_ {}]") then
    return false, SAFE_DEFAULT
  end

  -- Check if at least one valid variable exists
  local has_variable = false
  for _, var in ipairs(VALID_VARIABLES) do
    if pattern:find(var, 1, true) then
      has_variable = true
      break
    end
  end

  -- If no variables, add counter to make it unique
  if not has_variable then
    pattern = pattern .. "-{counter}"
  end

  return true, pattern
end

--- Generates a platform name for a player using their configured pattern
--- @param player_index uint The player index
--- @return string The generated platform name
function naming.generate_platform_name(player_index)
  local data = storage.player_data[player_index]
  if not data then
    -- Initialize if needed
    storage.player_data[player_index] = {
      platform_counter = 0
    }
    data = storage.player_data[player_index]
  end

  -- Get pattern from custom or use default
  local pattern = data.custom_name_pattern or SAFE_DEFAULT

  -- Validate pattern
  local valid, validated_pattern = naming.validate_pattern(pattern)
  if not valid then
    pattern = validated_pattern
  else
    pattern = validated_pattern
  end

  -- Increment counter
  data.platform_counter = (data.platform_counter or 0) + 1

  -- Replace variables
  local name = pattern
    :gsub("{counter}", tostring(data.platform_counter))
    :gsub("{tick}", tostring(game.tick))
    :gsub("{player}", game.players[player_index].name)
    :gsub("{random}", tostring(math.random(1000, 9999)))

  return name
end

--- Gets a preview of what the next platform name will be
--- @param player_index uint The player index
--- @return string The preview name
function naming.preview_next_name(player_index)
  local data = storage.player_data[player_index]
  if not data then
    storage.player_data[player_index] = {platform_counter = 0}
    data = storage.player_data[player_index]
  end

  local pattern = data.custom_name_pattern or SAFE_DEFAULT

  local valid, validated_pattern = naming.validate_pattern(pattern)
  pattern = validated_pattern

  -- Preview without incrementing
  local preview = pattern
    :gsub("{counter}", tostring((data.platform_counter or 0) + 1))
    :gsub("{tick}", tostring(game.tick))
    :gsub("{player}", game.players[player_index].name)
    :gsub("{random}", "####")  -- Show placeholder for random

  return preview
end

return naming
