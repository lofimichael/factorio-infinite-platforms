# ∞ Space Platform Automation

Automatically creates infinite space platforms by copying existing platforms. When starter packs are available in logistics, new platforms are created and populated with the blueprint of your source platform.

## Quick Start

1. Open the panel (platform icon button in toolbar during Remote View)
2. Select a platform to copy
3. Configure target planet and naming pattern
4. Enable auto-creation
5. Platforms will be created automatically when starter packs are available

## How It Works

The mod checks every 5 seconds (configurable) for starter pack availability. When available and auto-creation is enabled, it creates a new platform at your configured planet, copies the blueprint from your source platform, and automatically activates it when construction completes.

## Naming Patterns

Customize platform names using pattern variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `{counter}` | Incremental number (per-player) | 1, 2, 3... |
| `{tick}` | Current game tick | 123456 |
| `{player}` | Your player name | PlayerName |
| `{random}` | Random 4-digit number | 8472 |

**Example Patterns:**
- `Platform-{counter}` → Platform-1, Platform-2, Platform-3...
- `{player}-Scout-{counter}` → PlayerName-Scout-1, PlayerName-Scout-2...
- `Mining-{random}` → Mining-8472, Mining-3391...

Invalid patterns automatically fall back to `Platform-{counter}`.

## Requirements

- Factorio: Space Age (2.0+)
- Source platform to copy
- Starter packs in logistics network or inventory

## License

MIT License - Free to use, modify, and distribute.
