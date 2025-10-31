#!/bin/bash
# Factorio Mod Packaging Script
# Creates a properly structured zip file for Factorio mod distribution
# Requirements: jq (for JSON parsing)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Factorio Mod Packager${NC}"
echo "================================"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

# Parse info.json
if [ ! -f "info.json" ]; then
    echo -e "${RED}Error: info.json not found in current directory${NC}"
    exit 1
fi

MOD_NAME=$(jq -r '.name' info.json)
MOD_VERSION=$(jq -r '.version' info.json)

if [ -z "$MOD_NAME" ] || [ -z "$MOD_VERSION" ]; then
    echo -e "${RED}Error: Could not read name or version from info.json${NC}"
    exit 1
fi

# Create zip filename and folder name
ZIP_NAME="${MOD_NAME}_${MOD_VERSION}.zip"
FOLDER_NAME="${MOD_NAME}_${MOD_VERSION}"

echo "Mod Name:    $MOD_NAME"
echo "Version:     $MOD_VERSION"
echo "Output:      $ZIP_NAME"
echo ""

# Clean up any existing temp directory or zip
if [ -d "$FOLDER_NAME" ]; then
    echo "Removing existing temp directory..."
    rm -rf "$FOLDER_NAME"
fi

if [ -f "$ZIP_NAME" ]; then
    echo "Removing existing zip file..."
    rm "$ZIP_NAME"
fi

# Create temporary directory
echo "Creating temporary directory structure..."
mkdir -p "$FOLDER_NAME"

# Copy mod files (excluding development files)
echo "Copying mod files..."

# Lua files
cp *.lua "$FOLDER_NAME/"

# JSON files
cp info.json "$FOLDER_NAME/"

# Documentation
cp changelog.txt "$FOLDER_NAME/"
cp README.md "$FOLDER_NAME/"

# Graphics
if [ -f "thumbnail.png" ]; then
    cp thumbnail.png "$FOLDER_NAME/"
fi

if [ -f "desc.jpeg" ]; then
    cp desc.jpeg "$FOLDER_NAME/"
fi

# Locale directory
if [ -d "locale" ]; then
    cp -r locale "$FOLDER_NAME/"
fi

# Create zip file
echo "Creating zip file..."
zip -r "$ZIP_NAME" "$FOLDER_NAME" > /dev/null

# Clean up temp directory
echo "Cleaning up..."
rm -rf "$FOLDER_NAME"

# Get file size
FILE_SIZE=$(du -h "$ZIP_NAME" | cut -f1)

echo ""
echo -e "${GREEN}✓ Success!${NC}"
echo "Created: $ZIP_NAME ($FILE_SIZE)"
echo ""
echo "To install:"
echo "  1. Copy $ZIP_NAME to your Factorio mods folder"
echo "  2. Do NOT unzip it - Factorio loads zip files directly"
echo ""
echo "Mods folder locations:"
echo "  macOS:   ~/Library/Application Support/factorio/mods/"
echo "  Linux:   ~/.factorio/mods/"
echo "  Windows: %appdata%\\Factorio\\mods\\"
