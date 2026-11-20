H=$(hostname -s)
case $H in csewsrm22) L=excl;; csewsrm23) L=nine;; csewsrm24) L=agile;; csewsrm25) L=perf;; csews20|csewsrm20|csewsrm21) L=inc;; *) echo "unknown host $H"; exit 1;; esac
W=/tmp/sahilag24/work-$L
[ $L = inc ] && [ ! -d $W/cpu2017 ] && W=/tmp/sahilag24/work
IMG=$W/dl/x86-ubuntu-24.04.img
SPEC=$W/cpu2017
R=~/CS622_L2_TLB/robustness
B="520.omnetpp_r 620.omnetpp_s 603.bwaves_s 621.wrf_s 627.cam4_s 628.pop2_s 649.fotonik3d_s 654.roms_s"
