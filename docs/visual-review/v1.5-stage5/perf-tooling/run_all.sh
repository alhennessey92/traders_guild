#!/bin/zsh
S=/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad
DEVCTL=0C90C5FD-D935-51C9-A75F-F8570802F382
wait_unlocked() {
  for i in $(seq 1 240); do
    xcrun devicectl device info lockState --device $DEVCTL 2>/dev/null | grep -q "passcodeRequired: false" && return 0
    sleep 15
  done
  echo "TIMEOUT waiting for unlock"; return 1
}
run() { # label dd args
  wait_unlocked || exit 2
  xcrun simctl terminate 9B8DAACB-DB63-4F23-A75B-3BC6C52E5705 co.tradersguild.app.linkeddev 2>/dev/null
  echo "== $1 $(date -u +%H:%M:%S)"; python3 $S/stage5/run_perf.py "$1" "$2" "$3"
}
rotate() { echo "== rotate $(date -u +%H:%M:%S)"; python3 $S/stage5/rotate_avatars.py $S/stage4/qa-creds.json $S/stage5/avatars > $S/stage5/rotate-$1.json && echo rotated; }
rotate base;  run base-cold     $S/dd-device-base ""
              run base-warm     $S/dd-device-base ""
rotate proto; run proto-on-cold $S/dd-device-proto "-TGAvatarMarkersExperiment YES"
              run proto-on-warm $S/dd-device-proto "-TGAvatarMarkersExperiment YES"
              run proto-off-warm $S/dd-device-proto "-TGAvatarMarkersExperiment NO"
              run base-warm-2   $S/dd-device-base ""
              run proto-on-warm-2 $S/dd-device-proto "-TGAvatarMarkersExperiment YES"
echo "== done $(date -u +%H:%M:%S)"
