#!/bin/zsh
# Stage 5 baseline vs prototype comparison. Stops at the first failure; never deletes results.
#
# Device (default): waits for the phone to be unlocked before every step, and keeps the
# simulator's LinkedDev app closed, since every client's avatar requests reach the same
# local core-service log that run_perf.py counts.
# TG_DEST=<simulator udid>: the same sequence on the simulator builds, to validate the
# tooling. Simulator numbers are not device evidence.
S=/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad
SIM=9B8DAACB-DB63-4F23-A75B-3BC6C52E5705
DEVCTL=0C90C5FD-D935-51C9-A75F-F8570802F382
DEST=${TG_DEST:-00008120-00186CA01470201E}
if [[ $DEST == $SIM ]]; then
  B=$S/dd-sim-base; P=$S/dd-sim-proto; PREFIX=sim-
else
  B=$S/dd-device-base; P=$S/dd-device-proto; PREFIX=
fi
wait_unlocked() {
  [[ $DEST == $SIM ]] && return 0
  for i in $(seq 1 240); do
    xcrun devicectl device info lockState --device $DEVCTL 2>/dev/null | grep -q "passcodeRequired: false" && return 0
    sleep 15
  done
  echo "STOP: device still locked"; return 1
}
step() { # label dd args mode
  wait_unlocked || exit 2
  [[ $DEST != $SIM ]] && xcrun simctl terminate $SIM co.tradersguild.app.linkeddev 2>/dev/null
  echo "== $PREFIX$1 ($4) $(date -u +%H:%M:%S)"
  python3 $S/stage5/run_perf.py "$PREFIX$1" "$2" "$3" "$4" "$DEST" || { echo "STOP: $PREFIX$1 failed"; exit 3; }
}
rotate() { python3 $S/stage5/rotate_avatars.py $S/stage4/qa-creds.json $S/stage5/avatars > $S/stage5/rotate-$PREFIX$1-$(date -u +%Y%m%dT%H%M%SZ).json || { echo "STOP: rotate failed"; exit 4; }; echo "== rotated ($PREFIX$1)"; }
ON="-TGAvatarMarkersExperiment YES"; OFF="-TGAvatarMarkersExperiment NO"
step prepare-base   $B ""   prepare
rotate base;  step base-cold     $B ""   measure
              step base-warm     $B ""   measure
step prepare-proto  $P "$ON" prepare
rotate proto; step proto-on-cold $P "$ON" measure
              step proto-on-warm $P "$ON" measure
              step proto-off-warm $P "$OFF" measure
              step base-warm-2   $B ""   measure
              step proto-on-warm-2 $P "$ON" measure
echo "== sequence complete $(date -u +%H:%M:%S)"
