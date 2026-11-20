#!/bin/bash
# Usage: tool/l2a/ci/ios.sh <ci|local> [<output directory>]   (default output: build/l2a/ios)
#
# Runs the native probe on an iOS simulator before activation: the probe of the channel and the embedded views
# (integration_test_app/integration_test/l2a_{probe,views}_test.dart), with the native log of the wrapper after
# each. In ci mode it creates a simulator ($L2A_IOS_DEVICE, by default an iPhone 17 Pro) on the newest iOS runtime
# of the selected Xcode and uses flutter and dart from the PATH; in local mode it uses the simulator L2A-iPhone-it
# and the Flutter of .fvmrc under ~/fvm. Exit codes: 0 — every step passed; 1 — a step failed (the summary tells
# whether the run did not get to the plugin, infra, or the plugin answered other than expected, probe);
# 2 — wrong arguments.
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
l2a_init ios "$@"
l2a_info xcode "$(xcodebuild -version | tr '\n' ' ')"

if [ "$L2A_MODE" = ci ]; then
  derived_data=${L2A_DERIVED_DATA:-$HOME/l2a-derived-data}
else
  derived_data=${L2A_DERIVED_DATA:-$HOME/Developer/adapty-l2a-cache/dd-$(basename "$L2A_ROOT")}
fi

# The simulator, created in ci mode and found by name in local mode; booted.
device() {
  if [ "$L2A_MODE" = ci ]; then
    local runtime
    runtime=$(xcrun simctl list runtimes -j | jq -r '[.runtimes[] | select(.platform == "iOS" and .isAvailable)]
      | sort_by(.version | split(".") | map(tonumber)) | last | .identifier')
    udid=$(xcrun simctl create L2A-iPhone-ci "${L2A_IOS_DEVICE:-iPhone 17 Pro}" "$runtime") || return 1
  else
    udid=$(xcrun simctl list devices -j | jq -r '.devices[][] | select(.name == "L2A-iPhone-it") | .udid' | head -1)
  fi
  [ -n "$udid" ] || return 1
  echo "$udid" > "$L2A_OUT/udid"
  xcrun simctl boot "$udid" 2> /dev/null
  xcrun simctl bootstatus "$udid" -b
}

# The Swift packages of the app, resolved into the derived data of the check build.
packages() {
  cd integration_test_app &&
    xcodebuild -resolvePackageDependencies FLUTTER_TARGET=lib/main.dart -workspace ios/Runner.xcworkspace \
      -scheme Runner -derivedDataPath "$derived_data"
}

# The check build of the app: flutter test leaves a test listener as FLUTTER_TARGET in Generated.xcconfig, so
# xcodebuild always names the target of the app itself.
build() {
  cd integration_test_app &&
    xcodebuild build FLUTTER_TARGET=lib/main.dart COMPILER_INDEX_STORE_ENABLE=NO -workspace ios/Runner.xcworkspace \
      -scheme Runner -configuration Debug -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$derived_data"
}

# native_log <test> <start>: the log of the wrapper since <start>, into <test>.native.log.
native_log() {
  local predicate='subsystem == "io.adapty.flutter"'
  {
    echo "# command: xcrun simctl spawn $udid log show --start '$2' --predicate '$predicate'"
    xcrun simctl spawn "$udid" log show --start "$2" --predicate "$predicate"
  } > "$L2A_OUT/$1.native.log" 2>&1
}

l2a_step device infra "$L2A_ATTEMPTS" device || l2a_finish
udid=$(cat "$L2A_OUT/udid")
L2A_DEVICE="simulator $udid"
l2a_info device "$(xcrun simctl list devices -j | jq -r --arg u "$udid" '.devices | to_entries[] | .key as $r
  | .value[] | select(.udid == $u) | "\(.name) \($u) \($r | sub(".*SimRuntime."; ""))"')"

l2a_step pub-get infra "$L2A_ATTEMPTS" bash -c "'$FLUTTER' pub get && cd integration_test_app && '$FLUTTER' pub get" ||
  l2a_finish
l2a_step bundle probe 1 "$DART" run tool/l2a/bundle_cases.dart || l2a_finish
onboarding_views=$(l2a_onboarding_views ios "$L2A_OUT/bundle.log") || {
  echo "the bundle did not say how many onboarding views iOS has" >&2
  L2A_FAILED=1
  l2a_finish
}
l2a_step packages infra "$L2A_ATTEMPTS" packages || l2a_finish
l2a_step build probe 1 build || l2a_finish

resolved=integration_test_app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
ios_sha=$(cd "$L2A_ROOT" && jq -r '.pins[] | select(.identity == "adaptysdk-ios") | .state.revision' "$resolved")
l2a_info resolved_ios_sha "${ios_sha:-unknown}"

for test in probe views; do
  start=$(date '+%Y-%m-%d %H:%M:%S')
  l2a_step "$test" probe 1 bash -c "cd integration_test_app && '$FLUTTER' test integration_test/l2a_${test}_test.dart \
    -d $udid --dart-define=L2A_IOS_SHA=$ios_sha"
  native_log "$test" "$start"
done
l2a_step probe-native-log probe 1 "$DART" run tool/l2a/native_log_check.dart ios "$L2A_OUT/probe.native.log"
views_log=$L2A_OUT/views.native.log
l2a_step views-native-log probe 1 "$DART" run tool/l2a/native_log_check.dart ios "$views_log" --onboarding-views "$onboarding_views"

[ "$L2A_MODE" = ci ] && xcrun simctl delete "$udid"
l2a_finish
