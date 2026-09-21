#!/bin/bash
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="Captally"
SCHEME="Captally"
BUNDLE_ID="com.misswell.Captally"
XCODEPROJ="$PROJECT_DIR/Captally.xcodeproj"
DERIVED_DATA="$PROJECT_DIR/build"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

usage() {
    echo "Usage: $0 [--device|--simulator]"
    echo ""
    echo "  --device     Build and install to connected iPhone (default if device found)"
    echo "  --simulator  Build and install to Simulator (default if no device found)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Auto-detect: device if connected, else simulator"
    echo "  $0 --simulator      # Force Simulator build"
    echo "  $0 --device         # Force device build (requires signing identity)"
    exit 0
}

FORCE_TARGET=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --device)     FORCE_TARGET="device"; shift ;;
        --simulator)  FORCE_TARGET="simulator"; shift ;;
        -h|--help)    usage ;;
        *)            error "Unknown option: $1. Use --help for usage." ;;
    esac
done

# ──────────────────────────────────────────────
# Step 1: Check prerequisites
# ──────────────────────────────────────────────
info "Checking prerequisites..."

command -v xcodebuild &>/dev/null || error "xcodebuild not found. Install Xcode from App Store."
command -v xcrun &>/dev/null || error "xcrun not found."
command -v xcodegen &>/dev/null || warn "xcodegen not found. If project needs regeneration, install: brew install xcodegen"

if [ ! -d "$XCODEPROJ" ]; then
    info "Generating Xcode project via XcodeGen..."
    xcodegen generate
fi

ok "Prerequisites checked"

# ──────────────────────────────────────────────
# Step 2: Detect connected devices
# ──────────────────────────────────────────────
info "Detecting connected devices..."

DEVICES_JSON="$DERIVED_DATA/devicectl-devices.json"
mkdir -p "$DERIVED_DATA"
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 || true

# xctrace lists the Mac itself under "== Devices ==" and parks a sleeping iPhone under
# "Devices Offline", so neither tells us what we can actually install to. devicectl exposes the
# tunnel state, and only a live tunnel carries an install.
DEVICE_UDID=$(python3 - "$DEVICES_JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
seen = []
for dev in devices:
    hard = dev.get("hardwareProperties") or {}
    conn = dev.get("connectionProperties") or {}
    if hard.get("platform") != "iOS" or conn.get("transportType") == "sameMachine":
        continue  # simulators run on this machine
    seen.append((hard.get("udid"), conn.get("tunnelState")))
    if conn.get("tunnelState") == "connected":
        print(hard.get("udid"))
        sys.exit(0)
for udid, state in seen:
    print(f"paired but tunnelState={state}: {udid}", file=sys.stderr)
PY
)

if [ "$FORCE_TARGET" = "simulator" ]; then
    TARGET_TYPE="simulator"
elif [ "$FORCE_TARGET" = "device" ]; then
    if [ -z "$DEVICE_UDID" ]; then
        error "No iPhone reachable over a live tunnel. Unlock it on the same network, or plug it in over USB, then try again."
    fi
    TARGET_TYPE="device"
elif [ -n "$DEVICE_UDID" ]; then
    TARGET_TYPE="device"
else
    TARGET_TYPE="simulator"
fi

UUID_RE='[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}'

if [ "$TARGET_TYPE" = "simulator" ]; then
    SIM_ID=$(xcrun simctl list devices available | grep "iPhone" | grep "Booted" | head -1 | grep -oE "$UUID_RE" || true)
    if [ -z "$SIM_ID" ]; then
        SIM_ID=$(xcrun simctl list devices available | grep -E "iPhone [0-9]" | head -1 | grep -oE "$UUID_RE" || true)
        [ -n "$SIM_ID" ] || error "No iPhone simulator available."
        info "Booting simulator ($SIM_ID)..."
        xcrun simctl boot "$SIM_ID" 2>/dev/null || true
    fi
    DESTINATION="platform=iOS Simulator,id=$SIM_ID"
    SDK="iphonesimulator"
    ok "Using Simulator: $SIM_ID"
else
    DESTINATION="platform=iOS,id=$DEVICE_UDID"
    SDK="iphoneos"
    ok "Found device: $DEVICE_UDID"
fi

# ──────────────────────────────────────────────
# Step 3: Check signing identity (device only)
# ──────────────────────────────────────────────
if [ "$TARGET_TYPE" = "device" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>&1 | grep "Apple Development" | head -1 || true)

    if [ -z "$SIGNING_IDENTITY" ]; then
        warn "No signing identity found."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  To install on a real device, you need a signing identity."
        echo ""
        echo "  Quick setup (one-time only):"
        echo ""
        echo "  1. Open Xcode:"
        echo "     open $XCODEPROJ"
        echo ""
        echo "  2. Xcode → Settings (⌘,) → Accounts → Click '+' → Sign in with Apple ID"
        echo ""
        echo "  3. In Project Navigator → Captally target → Signing & Capabilities:"
        echo "     ✓ Check 'Automatically manage signing'"
        echo "     ✓ Team: the team that owns your certificate (pinned as DEVELOPMENT_TEAM in project.yml)"
        echo ""
        echo "  4. Wait for Xcode to generate provisioning profile, then re-run this script"
        echo ""
        echo "  Or use Simulator instead:"
        echo "     $0 --simulator"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if [ -t 0 ]; then
            echo ""
            read -p "Open Xcode now to configure signing? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                open "$XCODEPROJ"
                info "After configuring signing in Xcode, press Enter to continue..."
                read -r
            fi

            SIGNING_IDENTITY=$(security find-identity -v -p codesigning 2>&1 | grep "Apple Development" | head -1 || true)
            if [ -z "$SIGNING_IDENTITY" ]; then
                error "Still no signing identity. Run '$0 --simulator' to use Simulator, or complete Xcode signing setup first."
            fi
        else
            error "No signing identity found. Run this script in an interactive terminal, or use '$0 --simulator'."
        fi
    fi

    # DEVELOPMENT_TEAM comes from project.yml. The parentheses in an identity's common name are
    # the Apple ID's issuer, not the team — for this keychain they differ (U8U443D7ZL vs W445UUCQV9),
    # so guessing here produced a team that owns no profile at all.
    XCODE_ACCOUNTS=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | tr -d ' \n{}')
    if [ -z "$XCODE_ACCOUNTS" ]; then
        error "Xcode has no Apple Account signed in, so it cannot register the CloudKit App ID. Open Xcode → Settings → Accounts, add the Apple ID that owns team U8U443D7ZL, then re-run."
    fi
    ok "Xcode Apple Account present; signing team comes from project.yml"
fi

# ──────────────────────────────────────────────
# Step 4: Build
# ──────────────────────────────────────────────
info "Building $PROJECT_NAME for $TARGET_TYPE..."

BUILD_CMD="xcodebuild \
    -project $XCODEPROJ \
    -scheme $SCHEME \
    -sdk $SDK \
    -destination '$DESTINATION' \
    -derivedDataPath $DERIVED_DATA \
    -quiet"

if [ "$TARGET_TYPE" = "device" ]; then
    BUILD_CMD="$BUILD_CMD \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration"
fi

eval $BUILD_CMD 2>&1 | tail -5

if [ "$TARGET_TYPE" = "device" ]; then
    BUILD_RESULT="$DERIVED_DATA/Build/Products/Debug-iphoneos/$PROJECT_NAME.app"
else
    BUILD_RESULT="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$PROJECT_NAME.app"
fi

if [ ! -d "$BUILD_RESULT" ]; then
    error "Build failed. App bundle not found at $BUILD_RESULT"
fi

ok "Build succeeded"

# ──────────────────────────────────────────────
# Step 5: Install & Launch
# ──────────────────────────────────────────────
if [ "$TARGET_TYPE" = "device" ]; then
    info "Installing on $DEVICE_UDID..."
    xcrun devicectl device install app --device "$DEVICE_UDID" "$BUILD_RESULT" 2>&1 || {
        warn "devicectl install failed, trying ios-deploy..."
        if command -v ios-deploy &>/dev/null; then
            ios-deploy --bundle "$BUILD_RESULT" --debug --id "$DEVICE_UDID"
        else
            warn "ios-deploy not found. Install via: brew install ios-deploy"
            info "You can also install manually by opening Xcode and pressing ⌘R"
        fi
    }

    info "Launching app on device..."
    xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" 2>&1 || {
        warn "Auto-launch not available. Please tap the Captally icon on your iPhone."
    }

    ok "App installed on $DEVICE_UDID"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Captally has been installed on your iPhone!"
    echo ""
    echo "  First-time setup: Trust the developer certificate"
    echo "  iPhone → Settings → General → VPN & Device Management"
    echo "  → Tap your developer profile → Trust"
    echo ""
    echo "  Note: Free Apple ID signed apps expire after 7 days."
    echo "  Re-run this script to reinstall."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    info "Installing on Simulator..."
    xcrun simctl install "$SIM_ID" "$BUILD_RESULT"

    info "Launching app..."
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"

    ok "App launched on Simulator"
fi

echo ""
ok "Done! 🎉"
