# shellcheck shell=bash
# Shared by ios.sh and android.sh (sourced, not run): the output directory of a run, its steps, the egress guard
# and the summary.
#
# A run writes into its output directory:
#   steps.tsv     one line per step: <name> <infra|probe> <exit code> <attempts> <seconds>, tab-separated;
#   info.tsv      <key> <value> lines: platform, mode, commit, device, and xcode or variant;
#   <step>.log    the output of each step under a header: the command, the commit, the device and the start;
#   <test>.native.log and, on Android, <test>.egress.log: the native log of each test and the guard result.
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
  L2A_GUARD_OUT=$3
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
