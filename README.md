# ∞ Space Platform Automation

A Factorio: Space Age mod that automatically creates infinite space platforms and pastes blueprints onto them. **Fully integrated into the game's native GUI with left-panel interface.**

## Features

- **Automatic Platform Creation**: Platforms are created automatically when starter packs are available in your logistics network or inventory
- **Native GUI Integration**: Fully integrated left-panel interface with toggle button in top bar
- **Blueprint Auto-Paste**: Selected blueprints are automatically pasted onto new platforms when they're ready
- **Platform Copying**: Alternative to blueprints - copy existing platform structures
- **Per-Force Blueprint System**: Each team shares one blueprint template (configurable by any team member)
- **Native Dropdowns**: Proper Factorio dropdowns for planets, starter packs, and quality levels
- **Customizable Platform Naming**: Use pattern variables like `{counter}`, `{tick}`, `{player}`, and `{random}` to create unique platform names
- **Per-Player Configuration**: Each player controls their own settings via the integrated GUI
- **Resource-Based Activation**: Only creates platforms when starter packs are actually available

## Quick Start

1. **Install the mod** and load your Space Age save
2. **Look for the platform icon button** in the top toolbar
3. **Click the button** to open the ∞ Platform Automation panel in the left sidebar
4. **Select a blueprint** OR choose an existing platform to copy
5. **Configure your settings** using the dropdowns:
   - Select target planet/location
   - Choose starter pack type and quality
   - Customize platform naming pattern
6. **Enable auto-creation** with the checkbox
7. Platforms will now be created automatically when starter packs are available!

## GUI Interface

The mod adds a **permanent panel in the left sidebar** (visible during Remote View and normal gameplay):

### Panel Sections

**Platform Template:**
- **Blueprint Selector**: Choose-elem-button to select any blueprint from your inventory
- **OR Copy From**: Dropdown to select an existing platform to copy

**Configuration:**
- **Planet**: Dropdown of all available space locations
- **Starter Pack**: Dropdown of all starter pack types
- **Quality**: Dropdown of quality levels (normal, uncommon, rare, epic, legendary)

**Platform Naming:**
- **Pattern**: Textfield for custom naming patterns
- **Preview**: Live preview of next platform name

**Enable Auto-Creation**: Checkbox to toggle automatic platform creation

**Status**: Real-time status indicator showing configuration state and pending platforms

## How It Works

1. **Every check interval** (default 5 seconds), the mod checks each player
2. **Requirements checked**:
   - Player has auto-creation enabled
   - Team has a blueprint configured OR player has selected a platform to copy
   - Starter pack is available in logistics or inventory
3. **Platform created** with your custom name at your configured location
4. **Platform tracked** until it reaches a ready state
5. **Template applied** automatically (blueprint or platform copy)
6. **Done!** Platform is ready to use

## Platform Templates

### Blueprint Method
1. Create or import a blueprint of your desired platform layout
2. Click the blueprint selector button in the panel
3. Select your blueprint from the picker
4. Blueprint is stored for your entire team

### Platform Copy Method
1. Build a platform with your desired layout
2. Open the ∞ Platform Automation panel
3. Select your platform from the "Copy from" dropdown
4. New platforms will clone this platform's structure

**Note**: Blueprint method is shared per-force. Copy method is per-player.

## Naming Patterns

Pattern variables are replaced when generating platform names:

| Variable | Replaced With | Example |
|----------|---------------|---------|
| `{counter}` | Incremental number (per-player) | 1, 2, 3... |
| `{tick}` | Current game tick | 123456 |
| `{player}` | Your player name | PlayerName |
| `{random}` | Random 4-digit number | 8472 |

### Example Patterns
- `Platform-{counter}` → Platform-1, Platform-2, Platform-3...
- `Mining-{counter}` → Mining-1, Mining-2, Mining-3...
- `{player}-Scout-{counter}` → PlayerName-Scout-1, PlayerName-Scout-2...
- `Auto-{tick}` → Auto-123456, Auto-789012...
- `{player}-{random}` → PlayerName-8472, PlayerName-3391...

**Invalid patterns** (containing special characters or no variables) automatically fall back to `Platform-{counter}`.

## Multiplayer

- **Blueprint**: Shared per-force (one per team)
- **Platform Copy**: Individual per-player
- **Settings**: Individual per-player (via GUI)
- **Naming**: Each player has their own counter
- **Permissions**: Any team member can set the team blueprint (trust-based, like vanilla)

## Configuration

### GUI Configuration (Left Panel)
All player-specific settings are configured via the integrated left-panel GUI:
- Target planet/space location (dropdown)
- Starter pack type (dropdown)
- Starter pack quality (dropdown)
- Platform naming pattern (textfield with live preview)
- Enable/disable auto-creation (checkbox)

### Global Settings (Options > Mod Settings > Map)
- **Check Interval**: How often to check for starter packs (in ticks)
  - Default: 300 ticks (5 seconds)
  - Lower = more frequent checks but more CPU usage

## Important Notes

- **Template Required**: Auto-creation is disabled if no blueprint is configured AND no copy platform is selected
- **Resource Requirement**: Platforms are only created when starter packs are available
- **No Hard Limits**: The mod can create unlimited platforms (truly infinite!)
- **State Validation**: Invalid naming patterns automatically use safe defaults
- **GUI Always Available**: Panel can be toggled via button in top toolbar

## Troubleshooting

**Platforms aren't being created:**
- Check that you have auto-creation enabled (checkbox in panel)
- Verify your team has a blueprint configured OR you've selected a platform to copy
- Ensure starter packs are available in logistics or your inventory
- Check that starter pack type/quality matches your dropdown selections

**Blueprint isn't being pasted:**
- Wait for the platform to reach a ready state (may take a few moments)
- Verify the blueprint is valid (try manually pasting it first)
- Check the platform hasn't been deleted or moved

**Platform copy isn't working:**
- Ensure the source platform still exists and is valid
- Check that the source platform has entities to copy
- Verify you have proper permissions for the force

**Can't see the panel:**
- Click the platform icon button in the top toolbar
- Panel appears in the left sidebar (same area as other mod GUIs)

## Remote Interface

Other mods can interact with this mod via remote calls:

```lua
-- Set blueprint for a force
remote.call("space_platform_automation", "set_force_blueprint", force_index, blueprint_string)

-- Get blueprint for a force
local blueprint = remote.call("space_platform_automation", "get_force_blueprint", force_index)
```

## Compatibility

- **Requires**: Factorio: Space Age (2.0+)
- **Compatible with**: All Space Age mods
- **Multiplayer**: Fully supported
- **GUI**: Native Factorio interface integration

## Version History

### 2.0.0 - Major GUI Overhaul
- Complete GUI integration into left panel
- Native Factorio dropdowns for all settings
- Platform copying feature (alternative to blueprints)
- Choose-elem-button for blueprint selection
- Real-time status display
- Removed hotkey system in favor of toggle button
- Settings moved from mod settings to GUI

### 1.0.0 - Initial Release
- Automatic platform creation
- Per-force blueprint system
- Customizable naming patterns
- Hotkey-based GUI

## License

MIT License - Free to use, modify, and distribute.

## Credits

Created for Factorio: Space Age automatic platform management with native GUI integration.
