#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and ensure pipeline failures propagate.
set -euo pipefail

# Determine repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Default configuration settings
CONFIGURATION="Debug"
RESTART_APP=true
FORCE_REBUILD=false
RESET_PERMISSIONS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIGURATION="$2"
      shift 2
      ;;
    --release)
      CONFIGURATION="Release"
      shift
      ;;
    --debug)
      CONFIGURATION="Debug"
      shift
      ;;
    --no-restart)
      RESTART_APP=false
      shift
      ;;
    --rebuild)
      FORCE_REBUILD=true
      shift
      ;;
    --reset-permissions)
      RESET_PERMISSIONS=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Install local AltTab build to /Applications."
      echo ""
      echo "Options:"
      echo "  --debug              Use Debug build (default)"
      echo "  --release            Use Release build"
      echo "  --rebuild            Force rebuilding before installing"
      echo "  --reset-permissions  Reset TCC permissions database for AltTab"
      echo "  --no-restart         Do not automatically start AltTab after installation"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      echo "Run '$0 --help' for usage instructions." >&2
      exit 1
      ;;
  esac
done

BUILT_APP="$REPO_ROOT/DerivedData/Build/Products/$CONFIGURATION/AltTab.app"
DESTINATION="/Applications/AltTab.app"

# If the app has not been built or rebuild was forced, run build_local.sh
if [[ "$FORCE_REBUILD" == true || ! -d "$BUILT_APP" ]]; then
  echo "--> Built application not found or rebuild requested. Building first ($CONFIGURATION)..."
  if [[ "$CONFIGURATION" == "Release" ]]; then
    "$REPO_ROOT/scripts/build_local.sh" --release
  else
    "$REPO_ROOT/scripts/build_local.sh" --debug
  fi
fi

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Error: Built application does not exist at: $BUILT_APP" >&2
  exit 1
fi

echo "=================================================="
echo " Installing AltTab to $DESTINATION"
echo " Source: $BUILT_APP"
echo "=================================================="

# Stop running AltTab instance if active
if pgrep -x "AltTab" >/dev/null 2>&1; then
  echo "--> Stopping running AltTab instance..."
  killall "AltTab" 2>/dev/null || pkill -x "AltTab" 2>/dev/null
  while pgrep -x "AltTab" >/dev/null 2>&1; do
    sleep 0.5
  done
  echo "    AltTab stopped."
fi

# Remove previous /Applications/AltTab.app
if [[ -d "$DESTINATION" ]]; then
  echo "--> Removing previous installation at $DESTINATION..."
  rm -rf "$DESTINATION"
fi

# Copy built application to /Applications
echo "--> Copying new build to $DESTINATION..."
cp -R "$BUILT_APP" "$DESTINATION"

# Clear quarantine and extended attributes to satisfy Gatekeeper
echo "--> Clearing quarantine attributes (xattr -cr)..."
xattr -cr "$DESTINATION"

# Verify code signature
echo "--> Verifying code signature..."
codesign --verify --deep --strict "$DESTINATION"
echo "    Code signature verified successfully."

# Reset TCC database entries if requested
if [[ "$RESET_PERMISSIONS" == true ]]; then
  echo "--> Resetting TCC permissions database for com.lwouis.alt-tab-macos..."
  tccutil reset Accessibility com.lwouis.alt-tab-macos
  tccutil reset ScreenCapture com.lwouis.alt-tab-macos
  echo "    TCC database reset for Accessibility and ScreenCapture."
fi

# Launch AltTab if requested
if [[ "$RESTART_APP" == true ]]; then
  echo "--> Launching $DESTINATION..."
  open "$DESTINATION"
fi

echo "=================================================="
echo " Installation complete!"
echo ""
echo " IMPORTANT (macOS Permissions):"
echo " If AltTab was previously installed with official Developer ID signing,"
echo " macOS TCC maintains the old signature requirement, causing a permission loop."
echo " To fix this, either:"
echo "   A) Run: ./scripts/install_local.sh --reset-permissions"
echo "   B) Or in System Settings -> Privacy & Security -> Accessibility / Screen Recording:"
echo "      Select 'AltTab' and click '-' to DELETE it (do not just toggle OFF/ON)."
echo "      Then re-grant permission when prompted."
echo "=================================================="
