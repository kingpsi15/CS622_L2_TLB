#!/bin/bash
# usage: launch_patched.sh LANE SRCHOST SRC_WORKDIR HOST...
L=$1; SRC=$2; SW=$3; shift 3
IDS=(500 502 503 505 507 508 510 520 521 525 526 527 531 541 548 549 554 557 600 603 605 607 620 621 625 627 628 641 648 649 654 657)
HOSTS=("$@"); N=${#HOSTS[@]}
for ((i=0;i<N;i++)); do
  S=""
  for ((j=i;j<${#IDS[@]};j+=N)); do S="$S ${IDS[$j]}"; done
  S=${S# }
  ssh -n -o LogLevel=ERROR -o BatchMode=yes sahilag24@${HOSTS[$i]}.cse.iitk.ac.in "tmux new -d -s patched \"bash ~/spawn_new.sh $L $SRC '$S' $SW > /tmp/spawn_p.log 2>&1\""
  echo "${HOSTS[$i]} $L: $S"
done
