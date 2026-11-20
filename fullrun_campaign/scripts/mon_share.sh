source ~/lane_common.sh
O=$HOME/CS622_L2_TLB/robustness/comms/mon_$L.txt
while true; do bash ~/lane_mon.sh > $O.tmp 2>&1 && mv $O.tmp $O; sleep 300; done
