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

# l2a_start_guard <serial> <package> <result file>: starts the egress guard of the app in the background.
l2a_start_guard() {
  : > "$3"
  bash "$(dirname "${BASH_SOURCE[0]}")/egress_guard.sh" "$@" &
  L2A_GUARD_PID=$!
  L2A_GUARD_OUT=$3
}

# l2a_stop_guard: stops the running guard and prints its result; succeeds only when the guard wrote PASS.
l2a_stop_guard() {
  [ -n "${L2A_GUARD_PID:-}" ] || return 1
  kill -TERM "$L2A_GUARD_PID" 2> /dev/null
  wait "$L2A_GUARD_PID" 2> /dev/null
  L2A_GUARD_PID=""
  cat "$L2A_GUARD_OUT" 2> /dev/null
  grep -q '^PASS' "$L2A_GUARD_OUT" 2> /dev/null
}

# l2a_guard_passed <result file>: prints the result of a stopped guard; succeeds only when it is PASS.
l2a_guard_passed() {
  cat "$1"
  grep -q '^PASS' "$1"
}

# l2a_cleanup: the EXIT trap of a run script: stops a guard still running and an emulator the script started.
l2a_cleanup() {
  [ -n "${L2A_GUARD_PID:-}" ] && l2a_stop_guard > /dev/null
  if [ -n "${L2A_STARTED_EMULATOR:-}" ]; then
    "$ADB" -s "$L2A_STARTED_EMULATOR" emu kill > /dev/null 2>&1
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
