#!/bin/bash
# Usage: egress_guard.sh <serial> <package> <result file>   (adb is $ADB, or adb on the PATH)
#
# Rejects every packet the app of the native probe sends off an Android emulator (loopback stays open) and counts
# them, with an iptables and an ip6tables rule on the uid of the app. Start it before the app is installed: it
# uninstalls the app, waits for the next install and puts the rules in place at once. Stop it with TERM: it then
# reads the counters, removes its rules and writes one line to <result file>, "PASS ..." when the app sent no
# packet off the device and none of its rules is left, "FAIL ...: <reason>" otherwise, including whenever it
# cannot tell (a counter it cannot read, an app that was never installed). Once the app is uninstalled it creates
# <result file>.ready, so that the caller starts the install only then.
# The rules go in at the first poll that sees the new uid (every 0.2 s, then two adb calls): a packet the app sends
# within that window after the install is neither rejected nor counted. The probe sends nothing that early (the app
# has to start first), but the guard does not prove it.
ADB=${ADB:-adb}
serial=$1
package=$2
out=$3
uid=""
finished=""
not_inserted=""

rule() { echo "-m owner --uid-owner $1 ! -o lo -j REJECT"; }

# counter <iptables|ip6tables>: the packets the rule of the app rejected, or "?" when there is no such rule.
counter() {
  local packets
  packets=$("$ADB" -s "$serial" shell "$1 -w -L OUTPUT -v -n -x | grep 'owner UID match $uid'" 2> /dev/null |
    awk '{print $1}' | head -1)
  echo "${packets:-?}"
}

finish() {
  [ -n "$finished" ] && exit 0
  finished=1
  local v4="?" v6="?" reason="" left table
  if [ -n "$uid" ]; then
    v4=$(counter iptables)
    v6=$(counter ip6tables)
    for table in iptables ip6tables; do
      for _ in 1 2 3; do
        "$ADB" -s "$serial" shell "$table -w -D OUTPUT $(rule "$uid")" > /dev/null 2>&1 || break
      done
    done
  else
    reason="the package was never installed while the guard ran"
  fi
  left=$("$ADB" -s "$serial" shell "iptables -w -S OUTPUT; ip6tables -w -S OUTPUT" 2> /dev/null | grep -c 'uid-owner')
  [ -n "$not_inserted" ] && reason="${reason:+$reason; }$not_inserted"
  if [ "$v4" = "?" ] || [ "$v6" = "?" ]; then reason=${reason:-a counter could not be read}; fi
  if [ "$v4" != "?" ] && [ "$v4" != 0 ]; then reason="${reason:+$reason; }$v4 IPv4 packets rejected"; fi
  if [ "$v6" != "?" ] && [ "$v6" != 0 ]; then reason="${reason:+$reason; }$v6 IPv6 packets rejected"; fi
  if [ "$left" != 0 ]; then reason="${reason:+$reason; }$left uid rules left in OUTPUT"; fi
  local counts="rejected_ipv4_packets=$v4 rejected_ipv6_packets=$v6 uid_rules_left=$left"
  if [ -z "$reason" ]; then
    echo "PASS uid=$uid $counts" > "$out"
  else
    echo "FAIL uid=${uid:-unknown} $counts: $reason" > "$out"
  fi
  exit 0
}
trap finish TERM INT EXIT

"$ADB" -s "$serial" root > /dev/null 2>&1
"$ADB" -s "$serial" wait-for-device > /dev/null 2>&1
"$ADB" -s "$serial" uninstall "$package" > /dev/null 2>&1
: > "$out.ready"
while true; do
  if [ -z "$uid" ]; then
    found=$("$ADB" -s "$serial" shell "grep '^$package ' /data/system/packages.list" 2> /dev/null |
      awk '{print $2}' | tr -d '\r')
    if [ -n "$found" ]; then
      # The uid is kept before the rules go in, so that a rule that fails to go in is still counted and removed,
      # and none goes in twice.
      uid=$found
      # adb shell passes on the exit code of the command; -w waits for the lock netd holds while it installs apps.
      "$ADB" -s "$serial" shell "iptables -w -I OUTPUT $(rule "$uid")" > /dev/null 2>&1 ||
        not_inserted="the IPv4 rule could not be inserted"
      "$ADB" -s "$serial" shell "ip6tables -w -I OUTPUT $(rule "$uid")" > /dev/null 2>&1 ||
        not_inserted="${not_inserted:+$not_inserted; }the IPv6 rule could not be inserted"
    fi
  fi
  sleep 0.2 &
  wait $!
done
