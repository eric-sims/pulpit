#!/bin/bash
# Build, launch and drive SacramentPlanner on the iOS simulator.
#
#   ./driver.sh build              build the app for the simulator
#   ./driver.sh boot               boot a simulator and open Simulator.app
#   ./driver.sh install            install the built app
#   ./driver.sh reset              wipe app data (uninstall + reinstall)
#   ./driver.sh launch             launch the app
#   ./driver.sh shot <name>        screenshot the simulator to artifacts/
#   ./driver.sh flow <name>        run flows/<name>.swift against the installed app
#   ./driver.sh smoke              build + reset + flow outstanding
#
# There is no `simctl tap`, and AppleScript UI scripting needs an assistive-access grant this
# process doesn't have. `flow` is the only way to press anything: it runs an XCUITest bundle that
# has no host app and drives the installed build by bundle id.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"
UITEST_DIR="$SKILL_DIR/uitest"
ARTIFACTS="${ARTIFACTS:-$PROJECT_DIR/.build-artifacts}"
DD="${DD:-$ARTIFACTS/dd}"
BUNDLE_ID="com.ericsims.SacramentPlanner"
APP="$DD/Build/Products/Debug-iphonesimulator/SacramentPlanner.app"
SIM_NAME="${SIM_DEVICE:-iPhone 17}"

mkdir -p "$ARTIFACTS"

# The booted device if there is one, otherwise the named one. Booting an already-booted
# device is an error, so this is checked rather than assumed.
device_udid() {
  local booted
  booted=$(xcrun simctl list devices booted -j | python3 -c '
import json,sys
for runtime in json.load(sys.stdin)["devices"].values():
    for d in runtime:
        print(d["udid"]); raise SystemExit
')
  if [ -n "$booted" ]; then echo "$booted"; return; fi
  xcrun simctl list devices available -j | python3 -c "
import json,sys
for runtime in json.load(sys.stdin)['devices'].values():
    for d in runtime:
        if d['name'] == '''$SIM_NAME''':
            print(d['udid']); raise SystemExit
"
}

cmd_boot() {
  local udid; udid=$(device_udid)
  [ -n "$udid" ] || { echo "no simulator named '$SIM_NAME'; try SIM_DEVICE='iPhone 17 Pro'" >&2; exit 1; }
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  echo "$udid"
}

cmd_build() {
  local udid; udid=$(cmd_boot)
  xcodebuild -project "$PROJECT_DIR/SacramentPlanner.xcodeproj" \
    -scheme SacramentPlanner \
    -destination "id=$udid" \
    -derivedDataPath "$DD" \
    -quiet build
  echo "built $APP"
}

cmd_install() {
  local udid; udid=$(cmd_boot)
  xcrun simctl install "$udid" "$APP"
}

# SwiftData persists in the app container, so a flow that plans a meeting will find last run's
# meetings still there. Reinstalling is the reliable wipe.
cmd_reset() {
  local udid; udid=$(cmd_boot)
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  echo "app data reset"
}

cmd_launch() {
  local udid; udid=$(cmd_boot)
  xcrun simctl launch "$udid" "$BUNDLE_ID"
}

cmd_shot() {
  local udid; udid=$(cmd_boot)
  local name="${1:-shot}"
  xcrun simctl io "$udid" screenshot "$ARTIFACTS/$name.png" >/dev/null 2>&1
  echo "$ARTIFACTS/$name.png"
}

cmd_flow() {
  local name="${1:?usage: driver.sh flow <name>}"
  local src="$SKILL_DIR/flows/$name.swift"
  [ -f "$src" ] || { echo "no such flow: $src" >&2; ls "$SKILL_DIR/flows" >&2; exit 1; }

  local udid; udid=$(cmd_boot)
  # Flow.swift is the one test file the bundle compiles; flows/ is a library outside the
  # synchronized group so only the selected one is built.
  cp "$src" "$UITEST_DIR/SPUITests/Flow.swift"

  local result="$ARTIFACTS/$name.xcresult"
  rm -rf "$result"
  local status=0
  xcodebuild test \
    -project "$UITEST_DIR/SPUITests.xcodeproj" \
    -scheme SPUITests \
    -destination "id=$udid" \
    -resultBundlePath "$result" 2>&1 | grep -E "error:|Test Case|TEST (SUCCEEDED|FAILED)" || status=$?

  # Screenshots and hierarchy dumps land in the result bundle under UUID filenames; the manifest
  # maps them back to the names the flow gave them.
  local out="$ARTIFACTS/$name"
  rm -rf "$out"
  xcrun xcresulttool export attachments --path "$result" --output-path "$out" >/dev/null 2>&1 || true
  python3 - "$out" <<'PY'
import json, os, sys, shutil
out = sys.argv[1]
manifest = os.path.join(out, "manifest.json")
if not os.path.exists(manifest):
    raise SystemExit
for test in json.load(open(manifest)):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        src = os.path.join(out, a["exportedFileName"])
        # Named attachments arrive as "<name>_0_<uuid>.<ext>"; automatic ones are noise.
        if not name or not os.path.exists(src) or "_0_" not in name:
            continue
        stem, _, tail = name.partition("_0_")
        dest = os.path.join(out, stem + os.path.splitext(tail)[1])
        shutil.move(src, dest)
        print("  " + dest)
PY
  echo "artifacts: $out"
  return $status
}

cmd_smoke() {
  cmd_build
  cmd_reset
  cmd_flow outstanding
}

case "${1:?usage: driver.sh <build|boot|install|reset|launch|shot|flow|smoke> [args]}" in
  boot)    cmd_boot ;;
  build)   cmd_build ;;
  install) cmd_install ;;
  reset)   cmd_reset ;;
  launch)  cmd_launch ;;
  shot)    shift; cmd_shot "$@" ;;
  flow)    shift; cmd_flow "$@" ;;
  smoke)   cmd_smoke ;;
  *)       echo "unknown command: $1" >&2; exit 1 ;;
esac
