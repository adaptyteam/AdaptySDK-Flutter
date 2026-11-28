# shellcheck shell=bash
# Shared by ios.sh and android.sh (sourced, not run): the output directory of a run, its steps, the egress guard
# and the summary.
#
# A run writes into its output directory:
#   steps.tsv     one line per step: <name> <infra|probe> <exit code> <attempts> <seconds>, tab-separated; a step
#                 that runs again gets one more line, and the summary counts its last one;
#   info.tsv      <key> <value> lines: platform, mode, commit, device, xcode or variant, and retried for each test
#                 that ran once more because it did not start on the device;
#   <step>.log    the output of each step under a header: the command, the commit, the device and the start;
#   <test>.native.log and, on Android, <test>.egress.log: the native log of each test and the guard result (of the
#                 first run of a test that ran again: <test>.native.first.log, <test>.egress.first.log).
# tool/l2a/summary.dart reads the directory.

# l2a_init <platform> <ci|local> [<output directory>]
l2a_init() {
  L2A_PLATFORM=$1
  L2A_MODE=${2:-}
  case $L2A_MODE in
    ci | local) ;;
    *)
      echo "usage: tool/l2a/ci/$L2A_PLATFORM.sh <ci|local> [<output directory>]" >&2
      exit 2
      ;;
  esac
  L2A_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
  L2A_OUT=${3:-$L2A_ROOT/build/l2a/$L2A_PLATFORM}
  mkdir -p "$L2A_OUT"
  L2A_OUT=$(cd "$L2A_OUT" && pwd)
  : > "$L2A_OUT/steps.tsv"
  : > "$L2A_OUT/info.tsv"
  L2A_FAILED=0
  # In CI a step that prepares the run (a device, a download) gets three attempts; the probe gets one anywhere.
  L2A_ATTEMPTS=1
  if [ "$L2A_MODE" = ci ]; then
    L2A_ATTEMPTS=3
    FLUTTER=${L2A_FLUTTER:-flutter}
    DART=${L2A_DART:-dart}
  else
    local version
    version=$(jq -r .flutter "$L2A_ROOT/.fvmrc")
    FLUTTER=${L2A_FLUTTER:-$HOME/fvm/versions/$version/bin/flutter}
    DART=${L2A_DART:-$HOME/fvm/versions/$version/bin/dart}
  fi
  local tree=clean
  [ -z "$(git -C "$L2A_ROOT" status --porcelain)" ] || tree=DIRTY
  L2A_COMMIT="$(git -C "$L2A_ROOT" rev-parse --short HEAD), working tree $tree"
  l2a_info platform "$L2A_PLATFORM"
  l2a_info mode "$L2A_MODE"
  l2a_info commit "$L2A_COMMIT"
}

# l2a_info <key> <value>: records what the summary shows about the run.
l2a_info() {
  printf '%s\t%s\n' "$1" "$2" >> "$L2A_OUT/info.tsv"
}

# l2a_step <name> <infra|probe> <attempts> <command...>: runs the command from the repository root up to
# <attempts> times, appends its output to <name>.log under a header, and records the step. Returns its exit code.
l2a_step() {
  local name=$1 kind=$2 attempts=$3
  shift 3
  local log="$L2A_OUT/$name.log" rc=1 try=0 start=$SECONDS
  {
    echo "# command (repository $(basename "$L2A_ROOT") @ $L2A_COMMIT): $*"
    echo "# device: ${L2A_DEVICE:-none}"
    echo "# started: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$log"
  while [ $try -lt "$attempts" ]; do
    try=$((try + 1))
    (cd "$L2A_ROOT" && "$@") >> "$log" 2>&1
    rc=$?
    [ $rc -eq 0 ] && break
    [ $try -lt "$attempts" ] && echo "# attempt $try ended with rc=$rc, trying again" >> "$log"
  done
  local seconds=$((SECONDS - start))
  echo "# finished: rc=$rc ${seconds}s" >> "$log"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$rc" "$try" "$seconds" >> "$L2A_OUT/steps.tsv"
  echo "$name: rc=$rc, $try attempts, ${seconds}s"
  [ $rc -eq 0 ] || L2A_FAILED=1
  return $rc
}

# l2a_onboarding_views <platform> <output of bundle_cases.dart>: the number of onboarding views of the platform in
# the bundle; fails when the output does not say.
l2a_onboarding_views() {
  local count
  count=$(sed -n "s/^onboarding views:.* $1 \([0-9][0-9]*\).*/\1/p" "$2")
  [ -n "$count" ] || return 1
  echo "$count"
}

# l2a_flow_views <platform> <output of bundle_cases.dart>: the number of flow views of the platform in the bundle;
# fails when the output does not say.
l2a_flow_views() {
  local count
  count=$(sed -n "s/^flow views:.* $1 \([0-9][0-9]*\).*/\1/p" "$2")
  [ -n "$count" ] || return 1
  echo "$count"
}

# l2a_params_cases <platform> <output of bundle_cases.dart>: the number of cases of the platform the bundle expects
# the plugin to refuse as bad params; fails when the output does not say.
l2a_params_cases() {
  local count
  count=$(sed -n "s/^params cases:.* $1 \([0-9][0-9]*\).*/\1/p" "$2")
  [ -n "$count" ] || return 1
  echo "$count"
}

# l2a_app_pids <package> <logcat file>: the pids the activity manager started the processes of the package with,
# one per line.
l2a_app_pids() {
  sed -n 's/.*Start proc \([0-9][0-9]*\):'"$1"'\/.*/\1/p' "$2" | sort -u
}

# l2a_start_guard <serial> <package> <result file>: starts the egress guard of the app in the background.
l2a_start_guard() {
  : > "$3"
  rm -f "$3.ready" "$3.armed"
  bash "$(dirname "${BASH_SOURCE[0]}")/egress_guard.sh" "$@" &
  L2A_GUARD_PID=$!
}

# l2a_guard_ready <result file>: waits until the guard has uninstalled the app (up to $L2A_GUARD_READY_SECONDS,
# 60 by default), so that its uninstall cannot remove the app a test is installing; fails when it did not get there.
l2a_guard_ready() {
  local i=0 limit=$((${L2A_GUARD_READY_SECONDS:-60} * 5))
  until [ -f "$1.ready" ]; do
    [ $i -ge $limit ] && return 1
    sleep 0.2
    i=$((i + 1))
  done
}

# l2a_stop_guard: stops the running guard and waits until it has written its result. Run it in the shell that
# started the guard: a subshell cannot wait for it.
l2a_stop_guard() {
  [ -n "${L2A_GUARD_PID:-}" ] || return 0
  kill -TERM "$L2A_GUARD_PID" 2> /dev/null
  wait "$L2A_GUARD_PID" 2> /dev/null
  L2A_GUARD_PID=""
}

# l2a_guard_passed <result file>: prints the result of a stopped guard; succeeds only when it is PASS, so a missing
# or empty result fails.
l2a_guard_passed() {
  cat "$1" 2> /dev/null
  grep -q '^PASS' "$1" 2> /dev/null
}

# l2a_set_up_device <serial> <emulator pid or empty> <attempts>: restarts adbd as root (the guard needs it for
# iptables) and waits until the device stays online for $L2A_STABLE_SECONDS (5) seconds in a row. Right after a cold
# boot the emulator runs adb commands of its own, which can close the connection under adb root: a failed attempt
# is tried again after $L2A_SET_UP_PAUSE (5) seconds, up to <attempts> times, each attempt logged. Gives up at once
# when the emulator process (when given) is gone.
l2a_set_up_device() {
  local serial=$1 pid=$2 attempts=$3 attempt i online stable=${L2A_STABLE_SECONDS:-5}
  for attempt in $(seq "$attempts"); do
    [ -z "$pid" ] || kill -0 "$pid" 2> /dev/null || return 1
    echo "# device setup attempt $attempt of $attempts"
    if "$ADB" -s "$serial" root && "$ADB" -s "$serial" wait-for-device; then
      online=0
      for i in $(seq $((stable * 12))); do
        [ -z "$pid" ] || kill -0 "$pid" 2> /dev/null || return 1
        if [ "$("$ADB" -s "$serial" get-state 2> /dev/null)" = device ]; then online=$((online + 1)); else online=0; fi
        [ $online -ge "$stable" ] && return 0
        sleep 1
      done
    fi
    [ "$attempt" -lt "$attempts" ] && sleep "${L2A_SET_UP_PAUSE:-5}"
  done
  return 1
}

# l2a_cleanup: the EXIT trap of a run script: stops a guard still running and an emulator the script started
# (L2A_STARTED_EMULATOR, process L2A_EMULATOR_PID). The emulator saves its quick boot snapshot before it exits, which
# takes a while: the cleanup waits for its process (up to 90 s), so that the next run does not start the same AVD
# beside it.
l2a_cleanup() {
  l2a_stop_guard
  if [ -n "${L2A_STARTED_EMULATOR:-}" ]; then
    "$ADB" -s "$L2A_STARTED_EMULATOR" emu kill > /dev/null 2>&1
    local i=0
    while [ -n "${L2A_EMULATOR_PID:-}" ] && kill -0 "$L2A_EMULATOR_PID" 2> /dev/null && [ $i -lt 90 ]; do
      sleep 1
      i=$((i + 1))
    done
    L2A_STARTED_EMULATOR=""
  fi
  return 0
}

# l2a_finish: prints the summary of the run and exits, with 1 when a step failed or the summary is red.
l2a_finish() {
  (cd "$L2A_ROOT" && "$DART" run tool/l2a/summary.dart "$L2A_OUT")
  local summary=$?
  [ "$L2A_FAILED" = 0 ] && [ $summary = 0 ] && exit 0
  exit 1
}

# What flutter and adb print when a test could not start because adb lost the device for a moment: flutter could not
# install the app, start it or start its Dart Development Service, or did not find the device.
L2A_LOST_DEVICE="Failed to start Dart Development Service|Error waiting for a debug connection|Unable to start the app \
on the device|(adb|error): device offline|No supported devices found|device '[^']*' not found|waiting for device"

# What the log of an app process shows when the app crashed (the native log keeps only the lines of the app processes).
L2A_APP_CRASH='FATAL EXCEPTION|Fatal signal'

# l2a_start_lost <test log> <guard result> <native log>: succeeds, and prints what flutter or adb said, when the last
# run of a test in its log (the output after the last header of l2a_step) did not start because adb lost the device:
# its file failed to load or flutter found no device, so that no test of it ran; a line of L2A_LOST_DEVICE is there;
# no line of a test body is (an L2A_ line, a passed test); the guard saw no packet the app sent off the device; and
# the native log of the run shows no crash of the app (L2A_APP_CRASH), which flutter reports the same way. Anything
# else, a test that failed, a file that did not compile, a packet that left the device, a crash, is the result of
# the run.
l2a_start_lost() {
  local run marker
  [ -f "$1" ] || return 1
  grep -qE "$L2A_APP_CRASH" "$3" 2> /dev/null && return 1
  run=$(awk 'index($0, "# command (repository ") == 1 { run = "" } { run = run $0 "\n" } END { printf "%s", run }' "$1")
  printf '%s\n' "$run" | grep -qE 'Failed to load "|No supported devices found' || return 1
  printf '%s\n' "$run" | grep -qE 'L2A_[A-Z_]+ \{|✅|^[0-9]+:[0-9]+ \+[1-9]' && return 1
  grep -qE '(^|[^0-9])[1-9][0-9]* IPv[46] packets rejected' "$2" 2> /dev/null && return 1
  marker=$(printf '%s\n' "$run" | grep -oE "$L2A_LOST_DEVICE" | head -1)
  [ -n "$marker" ] || return 1
  echo "$marker"
}

# l2a_rule_packets <serial> <iptables|ip6tables> <uid>: the packets the guard rule of the uid rejected, read as the
# guard reads them; "?" when there is no such rule or adb cannot tell.
l2a_rule_packets() {
  local packets
  packets=$("$ADB" -s "$1" shell "$2 -w -L OUTPUT -v -n -x | grep 'owner UID match $3'" 2> /dev/null |
    awk '{print $1}' | head -1)
  echo "${packets:-?}"
}

# l2a_close_first_guard <serial> <package> <guard result>: once the device is back, closes what the guard of a run
# during which adb lost the device could not: uninstalls the app first, so that it sends nothing once its rules are
# gone; takes each counter of its uid (named in <guard result>) from <guard result> when the guard read it there, and
# reads only a counter the guard could not ("?"), whose rule the guard could not reach and so left in place; removes
# the rules of the uid (a reinstalled app gets another uid, and the next guard counts every uid rule left against
# itself); and appends to <guard result> a line
# "RECOVERED uid=... rejected_ipv4_packets=... rejected_ipv6_packets=... uid_rules_left=...", with the reason after a
# colon when it fails. Succeeds only when the app is gone, both counters are 0 and no rule of the uid is left: a packet
# the app sent, or a counter that still cannot be read, keeps the run red. With no uid in <guard result> the guard put
# no rule in.
l2a_close_first_guard() {
  local serial=$1 package=$2 result=$3 first uid v4 v6 table left installed reason=""
  "$ADB" -s "$serial" uninstall "$package" > /dev/null 2>&1
  installed=$("$ADB" -s "$serial" shell "pm list packages $package" 2> /dev/null) || installed="?"
  if [ "$installed" = "?" ] || printf '%s\n' "$installed" | tr -d '\r' | grep -qx "package:$package"; then
    reason="the app could not be uninstalled"
  fi
  first=$(head -1 "$result" 2> /dev/null)
  uid=$(printf '%s\n' "$first" | sed -n 's/^[A-Z]* uid=\([0-9][0-9]*\) .*/\1/p')
  if [ -z "$uid" ]; then
    echo "RECOVERED uid=unknown: ${reason:-the guard put no rule in}" | tee -a "$result"
    [ -z "$reason" ]
    return
  fi
  v4=$(printf '%s\n' "$first" | sed -n 's/.* rejected_ipv4_packets=\([0-9][0-9]*\) .*/\1/p')
  v6=$(printf '%s\n' "$first" | sed -n 's/.* rejected_ipv6_packets=\([0-9][0-9]*\) .*/\1/p')
  [ -n "$v4" ] || v4=$(l2a_rule_packets "$serial" iptables "$uid")
  [ -n "$v6" ] || v6=$(l2a_rule_packets "$serial" ip6tables "$uid")
  for table in iptables ip6tables; do
    for _ in 1 2 3; do
      "$ADB" -s "$serial" shell "$table -w -D OUTPUT -m owner --uid-owner $uid ! -o lo -j REJECT" > /dev/null 2>&1 ||
        break
    done
  done
  left=$("$ADB" -s "$serial" shell "iptables -w -S OUTPUT; ip6tables -w -S OUTPUT" 2> /dev/null) || left="?"
  [ "$left" = "?" ] || left=$(printf '%s\n' "$left" | grep -c -- "--uid-owner $uid ")
  if [ "$v4" = "?" ] || [ "$v6" = "?" ]; then reason="${reason:+$reason; }a counter could not be read"; fi
  if [ "$v4" != "?" ] && [ "$v4" != 0 ]; then reason="${reason:+$reason; }$v4 IPv4 packets rejected"; fi
  if [ "$v6" != "?" ] && [ "$v6" != 0 ]; then reason="${reason:+$reason; }$v6 IPv6 packets rejected"; fi
  if [ "$left" != 0 ]; then reason="${reason:+$reason; }$left uid rules left in OUTPUT"; fi
  local counts="rejected_ipv4_packets=$v4 rejected_ipv6_packets=$v6 uid_rules_left=$left"
  echo "RECOVERED uid=$uid $counts${reason:+: $reason}" | tee -a "$result"
  [ -z "$reason" ]
}
