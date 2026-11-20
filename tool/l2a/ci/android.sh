#!/bin/bash
# Usage: tool/l2a/ci/android.sh <ci|local> [<output directory>] [--flutter-activity]   (default output:
# build/l2a/android, or build/l2a/android-flutter-activity)
#
# Runs the native probe on an Android emulator before activation: the probe of the channel and the embedded views
# (integration_test_app/integration_test/l2a_{probe,views}_test.dart), each under the egress guard (no packet of
# the app may leave the device) and with the log of the app processes after it. With --flutter-activity the app
# is built with a plain FlutterActivity (Gradle property l2aActivity=flutter) and the views test is replaced by
# l2a_flutter_activity_test.dart: the plugin attaches without its views and keeps answering.
# In ci mode it uses the one running emulator (started by the workflow) and flutter, dart and adb from the PATH;
# in local mode it uses emulator-5580 of the AVD L2A_API_36_it, which it starts and stops when it is not running,
# the Flutter of .fvmrc under ~/fvm, and the Gradle and Java of the local cache unless GRADLE_USER_HOME and
# JAVA_HOME are set. Exit codes: 0 — every step passed; 1 — a step failed (the summary tells whether the run did
# not get to the plugin, infra, or the plugin answered other than expected, probe); 2 — wrong arguments.
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
variant=fragment
args=()
for arg in "$@"; do
  if [ "$arg" = --flutter-activity ]; then variant=flutter-activity; else args+=("$arg"); fi
done
default_out=""
[ "$variant" = flutter-activity ] && [ ${#args[@]} -eq 1 ] && default_out=build/l2a/android-flutter-activity
l2a_init android "${args[@]}" $default_out
l2a_info variant "$variant activity"
package=com.adapty.flutter.adapty_l2a
trap l2a_cleanup EXIT
trap 'exit 130' INT TERM

if [ "$L2A_MODE" = ci ]; then
  ADB=${ADB:-adb}
else
  ADB=${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}
  export GRADLE_USER_HOME=${GRADLE_USER_HOME:-$HOME/Developer/adapty-l2a-cache/gradle}
  export JAVA_HOME=${JAVA_HOME:-$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home}
fi
[ "$variant" = flutter-activity ] && export ORG_GRADLE_PROJECT_l2aActivity=flutter

# The emulator: in ci mode the one running; in local mode emulator-5580, started from a quick boot when needed.
device() {
  if [ "$L2A_MODE" = ci ]; then
    serial=$("$ADB" devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}')
  else
    serial=emulator-5580
    if ! "$ADB" devices | grep -q "^$serial[[:space:]]device"; then
      local emulator=${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator
      nohup "$emulator" -avd L2A_API_36_it -no-window -no-audio -no-boot-anim -port 5580 > "$L2A_OUT/emulator.log" 2>&1 &
      echo "$serial $!" > "$L2A_OUT/started-emulator"
    fi
  fi
  [ -n "$serial" ] || return 1
  echo "$serial" > "$L2A_OUT/serial"
  "$ADB" -s "$serial" wait-for-device
  local i
  for i in $(seq 120); do
    [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed | tr -d '\r')" = 1 ] && break
    sleep 1
  done
  # The guard needs root for iptables; the google_apis images allow it.
  "$ADB" -s "$serial" root && "$ADB" -s "$serial" wait-for-device || return 1
  # A quick boot restores sys.boot_completed from its snapshot before the device is ready: wait until flutter lists it.
  for i in $(seq 30); do
    "$FLUTTER" devices 2> /dev/null | grep -q "$serial" && return 0
    sleep 2
  done
  return 1
}

# native_log <test>: the lines of the app processes in the log of the emulator, into <test>.native.log.
native_log() {
  local all pids
  all=$("$ADB" -s "$serial" logcat -d)
  pids=$(echo "$all" | grep -o "Start proc [0-9]*:$package" | grep -o '[0-9]*' | sort -u | tr '\n' ' ')
  {
    echo "# command: adb -s $serial logcat -d, lines of the app processes ($pids)"
    echo "$all" | awk -v pids=" $pids" 'BEGIN { n = split(pids, a, " "); for (i = 1; i <= n; i++) p[a[i]] = 1 } ($3 in p)'
  } > "$L2A_OUT/$1.native.log"
}

l2a_step device infra "$L2A_ATTEMPTS" device
[ -f "$L2A_OUT/started-emulator" ] && read -r L2A_STARTED_EMULATOR L2A_EMULATOR_PID < "$L2A_OUT/started-emulator"
[ -f "$L2A_OUT/serial" ] || l2a_finish
serial=$(cat "$L2A_OUT/serial")
L2A_DEVICE="emulator $serial"
l2a_info device "$serial, $("$ADB" -s "$serial" shell getprop ro.build.fingerprint | tr -d '\r')"
[ "$L2A_FAILED" = 0 ] || l2a_finish

l2a_step pub-get infra "$L2A_ATTEMPTS" bash -c "'$FLUTTER' pub get && cd integration_test_app && '$FLUTTER' pub get" ||
  l2a_finish
l2a_step bundle probe 1 "$DART" run tool/l2a/bundle_cases.dart || l2a_finish

tests=(probe views)
[ "$variant" = flutter-activity ] && tests=(probe flutter_activity)
for test in "${tests[@]}"; do
  "$ADB" -s "$serial" logcat -c
  l2a_start_guard "$serial" "$package" "$L2A_OUT/$test.egress.log" || {
    echo "the egress guard did not uninstall the app within 60 s" >&2
    L2A_FAILED=1
  }
  l2a_step "$test" probe 1 bash -c "cd integration_test_app && '$FLUTTER' test integration_test/l2a_${test}_test.dart -d $serial"
  l2a_stop_guard
  l2a_step "$test-egress" probe 1 l2a_guard_passed "$L2A_OUT/$test.egress.log"
  native_log "$test"
  l2a_step "$test-native-log" probe 1 "$DART" run tool/l2a/native_log_check.dart android "$L2A_OUT/$test.native.log"
done

l2a_finish
