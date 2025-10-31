#!/bin/bash
# Local deployment script for ∞ Space Platform Automation mod
# Automatically packages and installs the mod to Factorio mods folder on macOS

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MOD_NAME="space-platform-automation"
FACTORIO_MODS_DIR="$HOME/Library/Application Support/Factorio/mods"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}∞ Space Platform Automation - Local Installer${NC}"
echo ""

# Validate mod structure
if [ ! -f "$SCRIPT_DIR/info.json" ]; then
    echo -e "${RED}✗ Error: info.json not found. Are you in the mod directory?${NC}"
    exit 1
fi

# Extract version from info.json
MOD_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$SCRIPT_DIR/info.json" | cut -d'"' -f4)
if [ -z "$MOD_VERSION" ]; then
    echo -e "${RED}✗ Error: Could not extract version from info.json${NC}"
    exit 1
fi

ZIP_NAME="${MOD_NAME}_${MOD_VERSION}.zip"
TEMP_BUILD_DIR="/tmp/${MOD_NAME}_build"

echo -e "${GREEN}✓${NC} Mod: ${MOD_NAME}"
echo -e "${GREEN}✓${NC} Version: ${MOD_VERSION}"
echo ""

# Create temporary build directory
echo -e "${YELLOW}Creating mod archive...${NC}"
rm -rf "$TEMP_BUILD_DIR"
mkdir -p "$TEMP_BUILD_DIR/$MOD_NAME"

# Copy mod files (exclude development files)
rsync -a \
    --exclude='.git' \
    --exclude='.claude' \
    --exclude='.gitignore' \
    --exclude='*.sh' \
    --exclude='*.zip' \
    --exclude='.DS_Store' \
    --exclude='README.md' \
    "$SCRIPT_DIR/" "$TEMP_BUILD_DIR/$MOD_NAME/"

# Create zip archive
cd "$TEMP_BUILD_DIR"
zip -r -q "$ZIP_NAME" "$MOD_NAME"

if [ ! -f "$ZIP_NAME" ]; then
    echo -e "${RED}✗ Error: Failed to create zip archive${NC}"
    rm -rf "$TEMP_BUILD_DIR"
    exit 1
fi

echo -e "${GREEN}✓${NC} Archive created: $ZIP_NAME"
echo ""

# Ensure Factorio mods directory exists
if [ ! -d "$FACTORIO_MODS_DIR" ]; then
    echo -e "${YELLOW}Creating Factorio mods directory...${NC}"
    mkdir -p "$FACTORIO_MODS_DIR"
    echo -e "${GREEN}✓${NC} Directory created: $FACTORIO_MODS_DIR"
fi

# Remove old versions of the mod
echo -e "${YELLOW}Installing to Factorio...${NC}"
rm -f "$FACTORIO_MODS_DIR/${MOD_NAME}_"*.zip

# Copy to Factorio mods directory
cp "$ZIP_NAME" "$FACTORIO_MODS_DIR/"

if [ ! -f "$FACTORIO_MODS_DIR/$ZIP_NAME" ]; then
    echo -e "${RED}✗ Error: Failed to copy to Factorio mods directory${NC}"
    rm -rf "$TEMP_BUILD_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_BUILD_DIR"

echo -e "${GREEN}✓${NC} Mod installed: $FACTORIO_MODS_DIR/$ZIP_NAME"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Installation complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}→ Restart Factorio to load the updated mod${NC}"
echo ""
