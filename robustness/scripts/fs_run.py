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
from m5.objects import IdeDisk, RawDiskImage
from gem5.components.boards.x86_board import X86Board
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_switchable_processor import SimpleSwitchableProcessor
from gem5.isas import ISA
from gem5.resources.resource import DiskImageResource, KernelResource
from gem5.simulate.exit_handler import ExitHandler
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides
import m5

ap = argparse.ArgumentParser()
ap.add_argument("--cores", type=int, default=1)
ap.add_argument("--script", required=True)
ap.add_argument("--cpu", default="timing", choices=["timing", "o3"])
ap.add_argument("--start-cpu", default=os.environ.get("FS_START_CPU", "kvm"),
                choices=["kvm", "atomic"])
ap.add_argument("--spec-disk")
a = ap.parse_args()

start_type = CPUTypes.KVM if a.start_cpu == "kvm" else CPUTypes.ATOMIC
processor = SimpleSwitchableProcessor(
    starting_core_type=start_type,
    switch_core_type=CPUTypes.TIMING if a.cpu == "timing" else CPUTypes.O3,
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
    spec_disk.image = RawDiskImage(read_only=False)
    spec_disk.image.image_file = a.spec_disk
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


Simulator(board=board).run()
print("TLBFS: simulation end", flush=True)