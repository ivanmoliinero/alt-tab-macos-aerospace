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
SCHEME="Debug"
DO_CLEAN=false
DO_INSTALL=false
USE_BEAUTIFY=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      CONFIGURATION="Release"
      SCHEME="Release"
      shift
      ;;
    --debug)
      CONFIGURATION="Debug"
      SCHEME="Debug"
      shift
      ;;
    --clean)
      DO_CLEAN=true
      shift
      ;;
    --install)
      DO_INSTALL=true
      shift
      ;;
    --verbose|--no-beautify)
      USE_BEAUTIFY=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Build AltTab with AeroSpace integration locally from terminal."
      echo ""
      echo "Options:"
      echo "  --debug          Build Debug configuration (default, faster incremental compilation)"
      echo "  --release        Build Release configuration (optimized binary)"
      echo "  --clean          Clean DerivedData before building"
      echo "  --install        Install to /Applications after successful build"
      echo "  --verbose        Show raw xcodebuild output instead of formatting with xcbeautify"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      echo "Run '$0 --help' for usage instructions." >&2
      exit 1
      ;;
  esac
done

echo "=================================================="
echo " Building AltTab ($CONFIGURATION)"
echo " Repository root: $REPO_ROOT"
echo "=================================================="

# Step 1: Validate build prerequisites
echo "--> Checking prerequisites..."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: 'xcodebuild' command not found." >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  CURRENT_DEV_DIR="$(xcode-select -p 2>/dev/null || echo "unknown")"
  echo "Error: 'xcodebuild' requires the full Xcode application, but current developer path is:" >&2
  echo "       $CURRENT_DEV_DIR" >&2
  if [[ "$CURRENT_DEV_DIR" == *"CommandLineTools"* ]]; then
    echo "" >&2
    echo "       To fix this, point xcode-select to your Xcode.app installation:" >&2
    echo "         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    echo "" >&2
  fi
  exit 1
fi

XCODE_VERSION="$(xcodebuild -version | head -n 1)"
echo "    Found $XCODE_VERSION"

AEROSPACE_PATH="/opt/homebrew/bin/aerospace"
if [[ -x "$AEROSPACE_PATH" ]]; then
  echo "    Found AeroSpace binary at $AEROSPACE_PATH"
else
  echo "    [WARNING] AeroSpace binary not found at $AEROSPACE_PATH."
  echo "    Compilation will succeed, but workspace filtering requires AeroSpace installed."
fi

# Step 2: Validate or generate self-signed code signing certificate
echo "--> Checking code signing identity..."
CERT_NAME="Local Self-Signed"

if security find-identity -v -p codesigning | grep -q "\"$CERT_NAME\""; then
  echo "    Found identity '$CERT_NAME' in keychain."
else
  echo "    Certificate '$CERT_NAME' not found in keychain. Generating self-signed certificate..."
  "$REPO_ROOT/scripts/codesign/setup_local.sh"

  if ! security find-identity -v -p codesigning | grep -q "\"$CERT_NAME\""; then
    echo "Error: Failed to register '$CERT_NAME' certificate in Keychain." >&2
    exit 1
  fi
  echo "    Successfully created and trusted '$CERT_NAME'."
fi

# Step 3: Validate or create config/local.xcconfig
echo "--> Checking local xcconfig overrides..."
LOCAL_XCCONFIG="$REPO_ROOT/config/local.xcconfig"

if [[ ! -f "$LOCAL_XCCONFIG" ]]; then
  echo "    Creating $LOCAL_XCCONFIG..."
  cat > "$LOCAL_XCCONFIG" << 'EOF'
// Local build configuration overrides
CURRENT_PROJECT_VERSION = aerospace-fork
CODE_SIGN_IDENTITY = Local Self-Signed
EOF
  echo "    Created $LOCAL_XCCONFIG."
else
  echo "    Using existing $LOCAL_XCCONFIG."
  # Ensure CODE_SIGN_IDENTITY is set so Release builds also use Local Self-Signed
  if ! grep -q "CODE_SIGN_IDENTITY" "$LOCAL_XCCONFIG"; then
    echo "    Adding CODE_SIGN_IDENTITY = Local Self-Signed to $LOCAL_XCCONFIG..."
    echo "CODE_SIGN_IDENTITY = Local Self-Signed" >> "$LOCAL_XCCONFIG"
  fi
fi

# Step 4: Clean DerivedData if requested
if [[ "$DO_CLEAN" == true ]]; then
  echo "--> Cleaning DerivedData..."
  rm -rf "$REPO_ROOT/DerivedData"
  echo "    DerivedData cleaned."
fi

# Step 5: Execute build with xcodebuild
echo "--> Compiling with xcodebuild (Scheme: $SCHEME, Config: $CONFIGURATION)..."

BUILD_CMD=(
  xcodebuild
  -project "$REPO_ROOT/alt-tab-macos.xcodeproj"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$REPO_ROOT/DerivedData"
)

if [[ "$USE_BEAUTIFY" == true && -x "$REPO_ROOT/scripts/xcbeautify" ]]; then
  set -o pipefail && "${BUILD_CMD[@]}" | "$REPO_ROOT/scripts/xcbeautify"
else
  "${BUILD_CMD[@]}"
fi

# Step 6: Verify output application bundle
APP_OUTPUT="$REPO_ROOT/DerivedData/Build/Products/$CONFIGURATION/AltTab.app"

if [[ ! -d "$APP_OUTPUT" ]]; then
  echo "Error: Build completed but application bundle was not found at: $APP_OUTPUT" >&2
  exit 1
fi

echo "=================================================="
echo " Build successful!"
echo " Application bundle: $APP_OUTPUT"
echo "=================================================="

# Step 7: Optional install
if [[ "$DO_INSTALL" == true ]]; then
  echo ""
  "$REPO_ROOT/scripts/install_local.sh" --config "$CONFIGURATION"
fi
