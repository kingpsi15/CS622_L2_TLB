#!/bin/bash
case $(hostname -s) in csewsrm22|csewsrm23|csewsrm24|csewsrm25|csews20) exit;; esac
KILL=" 500 600 502 503 505 507 508 510 511 519 520 521 523 526 531 538 541 544 548 549 554 557 602 603 605 607 620 621 623 628 631 638 641 644 648 649 654 657 "
for p in $(pgrep -x gem5.opt); do
  c=$(tr '\0' ' ' </proc/$p/cmdline)
  case "$c" in *extra-x87*) continue;; esac
  s=$(echo "$c" | grep -o -- '--script [^ ]*' | cut -d' ' -f2)
  [ -f "$s" ] || continue
  bs=$(grep -o '^echo SPEC_START [0-9]*' "$s" | awk '{print $3}' | sort -u)
  [ -n "$bs" ] || continue
  ok=1; for b in $bs; do case "$KILL" in *" $b "*) ;; *) ok=0;; esac; done
  if [ $ok = 1 ]; then echo "$(hostname -s) pid=$p [$(echo $bs | tr '\n' ' ')] $s"; [ "$DO" = 1 ] && kill $p; fi
done
