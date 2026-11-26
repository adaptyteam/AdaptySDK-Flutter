#!/bin/bash
# Usage: tool/l2a/ci/android.sh <ci|local> [<output directory>] [--flutter-activity]   (default output, under the
# repository root: build/l2a/android, or build/l2a/android-flutter-activity)
#
# Runs the native probe on an Android emulator before activation: the probe of the channel and the embedded views
# (integration_test_app/integration_test/l2a_{probe,views}_test.dart), each under the egress guard (no packet of
# the app may leave the device) and with the log of the app processes after it. With --flutter-activity the app
# is built with a plain FlutterActivity (Gradle property l2aActivity=flutter) and the views test is replaced by
# l2a_flutter_activity_test.dart: the plugin attaches, its flow view reports the activity it needs, and it keeps
# answering.
# In ci mode it uses the one running emulator (started by the workflow) and flutter, dart and adb from the PATH;
# in local mode it uses emulator-5580 of the AVD L2A_API_36_it, which it starts cold and stops when it is not running,
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
[ "$variant" = flutter-activity ] && [ ${#args[@]} -eq 1 ] && default_out="$(cd "$here/../../.." && pwd)/build/l2a/android-flutter-activity"
l2a_init android "${args[@]}" ${default_out:+"$default_out"}
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

# The emulator: in ci mode the one running; in local mode emulator-5580, started cold when it is not running. A
# quick boot finishes booting in the background after sys.boot_completed and resets the firewall and the log
# buffer under a running test, so a local start never loads the snapshot.
device() {
  local pid=""
  if [ "$L2A_MODE" = ci ]; then
    serial=$("$ADB" devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}')
  else
    serial=emulator-5580
    if ! "$ADB" devices | grep -q "^$serial[[:space:]]device"; then
      local emulator=${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator
      nohup "$emulator" -avd L2A_API_36_it -no-window -no-audio -no-boot-anim -port 5580 -no-snapshot-load \
        -no-snapshot-save > "$L2A_OUT/emulator.log" 2>&1 &
      pid=$!
      echo "$serial $pid" > "$L2A_OUT/started-emulator"
    fi
  fi
  [ -n "$serial" ] || return 1
  echo "$serial" > "$L2A_OUT/serial"
  # alive: the emulator this step started has not died (always true for one it did not start).
  alive() { [ -z "$pid" ] || kill -0 "$pid" 2> /dev/null; }
  local i
  for i in $(seq 180); do
    alive || return 1
    [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ] && break
    sleep 1
  done
  # Root for the guard and a device that stays online; locally the emulator may still be busy with its own adb
  # commands after a cold boot, so the setup gets three attempts there (CI retries the whole step instead).
  local setup_attempts=1
  [ "$L2A_MODE" = local ] && setup_attempts=3
  l2a_set_up_device "$serial" "$pid" "$setup_attempts" || return 1
  # flutter has to list the device.
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
  pids=$(l2a_app_pids "$package" <(echo "$all") | tr '\n' ' ')
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
flow_views=$(l2a_flow_views android "$L2A_OUT/bundle.log") || {
  echo "the bundle did not say how many flow views Android has" >&2
  L2A_FAILED=1
  l2a_finish
}

tests=(probe views)
[ "$variant" = flutter-activity ] && tests=(probe flutter_activity)

# run_test <test>: the test under the egress guard, then its result and the native log of the app.
run_test() {
  local test=$1 counts=()
  "$ADB" -s "$serial" logcat -c
  l2a_start_guard "$serial" "$package" "$L2A_OUT/$test.egress.log"
  l2a_step "$test-guard-ready" infra 1 l2a_guard_ready "$L2A_OUT/$test.egress.log" || l2a_finish
  l2a_step "$test" probe 1 bash -c "cd integration_test_app && '$FLUTTER' test integration_test/l2a_${test}_test.dart -d $serial"
  l2a_stop_guard
  l2a_step "$test-egress" probe 1 l2a_guard_passed "$L2A_OUT/$test.egress.log"
  native_log "$test"
  # The views test sets the log level of the SDK to verbose: each flow view whose params parsed asks for its
  # configuration once.
  [ "$test" = views ] && counts=(--flow-views "$flow_views")
  l2a_step "$test-native-log" probe 1 "$DART" run tool/l2a/native_log_check.dart android "$L2A_OUT/$test.native.log" \
    "${counts[@]}"
}

# A test that did not start because adb lost the emulator for a moment (l2a_start_lost) runs once more, on the device
# set up again and under a new guard, once the first guard has been closed: its app uninstalled, the counters of its
# rules read and the rules removed (l2a_close_first_guard, a probe step: a packet the app sent, or a counter that
# still cannot be read, keeps the test red and it does not run again). Its result is then the one of the second run.
# The first run stays: its output in the log of the test, its guard result (with the counters read afterwards) and
# native log in <test>.egress.first.log and <test>.native.first.log, its steps in the summary, and the reason in
# info.tsv (retried).
for test in "${tests[@]}"; do
  failed=$L2A_FAILED
  run_test "$test"
  lost=$(l2a_start_lost "$L2A_OUT/$test.log" "$L2A_OUT/$test.egress.log" "$L2A_OUT/$test.native.log") || continue
  echo "# $test did not start on the device ($lost): it runs once more unless its app sent a packet" \
    >> "$L2A_OUT/$test.log"
  mv "$L2A_OUT/$test.egress.log" "$L2A_OUT/$test.egress.first.log"
  mv "$L2A_OUT/$test.native.log" "$L2A_OUT/$test.native.first.log"
  l2a_step "$test-device" infra "$L2A_ATTEMPTS" l2a_set_up_device "$serial" "" 1 || l2a_finish
  l2a_step "$test-first-egress" probe 1 l2a_close_first_guard "$serial" "$package" "$L2A_OUT/$test.egress.first.log" ||
    continue
  l2a_info retried "$test ($lost)"
  L2A_FAILED=$failed
  run_test "$test"
done

l2a_finish
