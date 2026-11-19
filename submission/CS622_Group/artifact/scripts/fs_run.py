"""gem5 full-system run for the TLB robustness campaign.

Boots Ubuntu 24.04 (Linux 6.8) on KVM cores (or atomic cores when KVM is not
available), switches to timing/O3 cores at the "after boot" hypercall (2),
resets stats, runs the guest script (readfile) on the simulated cores - i.e.
with the TLB under test handling every translation, timer interrupt, context
switch, IPI shootdown and page fault - and ends at hypercall 3 (script
finished).

gem5.opt fs_run.py --cores N --script guest.sh [--cpu timing|o3]
                   [--start-cpu kvm|atomic] [--spec-disk IMAGE]

--start-cpu defaults to $FS_START_CPU, or kvm if that is unset.
"""
import argparse, os
from m5.objects import CowDiskImage, IdeDisk, RawDiskImage
from gem5.components.boards.x86_board import X86Board
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_switchable_processor import SimpleSwitchableProcessor
from gem5.isas import ISA
from gem5.resources.resource import DiskImageResource, KernelResource
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.exit_handler import ExitHandler
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides
import m5

ap = argparse.ArgumentParser()
ap.add_argument("--cores", type=int, default=1)
ap.add_argument("--script", required=True)
ap.add_argument("--cpu", default="timing", choices=["timing", "o3", "atomic"])
ap.add_argument("--start-cpu", default=os.environ.get("FS_START_CPU", "kvm"),
                choices=["kvm", "atomic"])
ap.add_argument("--spec-disk")
# Measurement windows (with --cpu atomic): when the guest signals that a
# benchmark executable has started (hypercall 11), run --window-warm insts on
# atomic, switch to --window-cpu for --window-insts, dump stats, switch back
# to atomic so the benchmark still finishes and is validated. Hypercall 10 =
# next benchmark (guest-side marker), 12 = executable finished.
ap.add_argument("--window-insts", type=int, default=0)
ap.add_argument("--window-warm", type=int, default=100_000_000)
ap.add_argument("--window-cpu", default="timing", choices=["timing", "o3"])
ap.add_argument("--window-exit", action="store_true", help="end the simulation right after the window dump")
ap.add_argument("--window-benches", default="", help="space-separated, guest order")
a = ap.parse_args()

start_type = CPUTypes.KVM if a.start_cpu == "kvm" else CPUTypes.ATOMIC
processor = SimpleSwitchableProcessor(
    starting_core_type=start_type,
    # --cpu atomic: stay on the atomic cores (no switch). The TLB under test
    # still handles every translation; only cycle timing is not modelled.
    switch_core_type=(CPUTypes.O3 if (a.cpu == "o3" or (a.cpu == "atomic" and a.window_cpu == "o3"))
                      else CPUTypes.TIMING),
    isa=ISA.X86,
    num_cores=a.cores,
)
if a.start_cpu == "kvm":
    for proc in processor.start:
        proc.core.usePerf = False   # hybrid i9 host: avoid perf-counter trouble

board = X86Board(
    clk_freq="3GHz",
    processor=processor,
    memory=SingleChannelDDR4_2400(size="3GiB"),
    cache_hierarchy=PrivateL1PrivateL2CacheHierarchy(
        l1d_size="32KiB", l1i_size="32KiB", l2_size="512KiB"),
)
board.set_kernel_disk_workload(
    kernel=KernelResource(local_path=os.environ["FS_KERNEL"]),
    disk_image=DiskImageResource(local_path=os.environ["FS_DISK"], root_partition="2"),
    readfile_contents=open(a.script).read(),
    kernel_args=["earlyprintk=ttyS0", "console=ttyS0", "lpj=7999923", "root=/dev/sda2"],
)
if a.spec_disk:
    ide = board.pc.south_bridge.ide
    spec_disk = IdeDisk()
    spec_disk.driveID = "device1"
    # Copy-on-write over a read-only base: several gem5 shards can share one
    # SPEC disk file; guest writes stay in this process's memory.
    spec_disk.image = CowDiskImage(child=RawDiskImage(read_only=True), read_only=False)
    spec_disk.image.child.image_file = a.spec_disk
    ide.spec_disk = spec_disk                 # explicit parent, so it is not an orphan
    ide.disks = [*ide.disks, spec_disk]


class Booted(ExitHandler, hypercall_num=1):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        print("TLBFS: kernel booted (%s)" % a.start_cpu.upper(), flush=True)

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return False


class AfterBoot(ExitHandler, hypercall_num=2):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        if a.cpu == "atomic":
            print("TLBFS: boot done -> staying on atomic cores (TLB under test)", flush=True)
        else:
            print("TLBFS: boot done -> switching to simulated cores with the TLB under test", flush=True)
            simulator.switch_processor()
        m5.stats.reset()

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return False


class ScriptDone(ExitHandler, hypercall_num=3):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        print("TLBFS: guest script finished", flush=True)

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return True


# ---- measurement-window state machine (atomic -> detailed -> atomic) ----
W = {"state": "idle", "bench": None, "idx": -1, "stale": 0, "done": set()}
win_benches = a.window_benches.split()


def _wlog(msg):
    print("TLBFS-WINDOW %s" % msg, flush=True)


class NextBench(ExitHandler, hypercall_num=10):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        W["idx"] += 1
        W["bench"] = win_benches[W["idx"]] if W["idx"] < len(win_benches) else "bench%d" % W["idx"]

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return False


class ExeBegin(ExitHandler, hypercall_num=11):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        if not a.window_insts or a.cpu != "atomic" or W["state"] != "idle" or W["bench"] in W["done"]:
            return
        W["done"].add(W["bench"])
        if W["stale"]:
            _wlog("%s skipped stale-inst-stop-pending" % W["bench"])
            return
        W["state"] = "warm"
        simulator.schedule_max_insts(a.window_warm)
        _wlog("%s warm-start %d" % (W["bench"], a.window_warm))

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return False


def _end_measure(simulator, why):
    m5.stats.dump()
    _wlog("%s dumped %s" % (W["bench"], why))
    W["state"] = "idle"
    if a.window_exit:
        W["exit_now"] = True
        print("TLBFS: window-exit -> ending simulation", flush=True)
        return
    simulator.switch_processor()          # back to atomic


class ExeEnd(ExitHandler, hypercall_num=12):
    @overrides(ExitHandler)
    def _process(self, simulator) -> None:
        if W["state"] == "warm":
            W["stale"] += 1; W["state"] = "idle"
            _wlog("%s too-short-for-warmup" % W["bench"])
        elif W["state"] == "measure":
            _end_measure(simulator, "partial-exe-ended")
            W["stale"] += 1                   # its pending inst-stop fires later

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return bool(W.get("exit_now"))


def on_max_insts():
    sim = SIM[0]
    if W["state"] == "warm":
        sim.switch_processor()            # atomic -> detailed
        m5.stats.reset()
        sim.schedule_max_insts(a.window_insts)
        W["state"] = "measure"
        _wlog("%s measure-start %d %s" % (W["bench"], a.window_insts, a.window_cpu))
    elif W["state"] == "measure":
        _end_measure(sim, "full")
        if W.get("exit_now"):
            return True
    elif W["stale"]:
        W["stale"] -= 1
    return False


SIM = [None]
# single function, not a list: a list is consumed once, then gem5 exits on the next MAX_INSTS
SIM[0] = Simulator(board=board, on_exit_event={ExitEvent.MAX_INSTS: on_max_insts})
SIM[0].run()
print("TLBFS: simulation end", flush=True)