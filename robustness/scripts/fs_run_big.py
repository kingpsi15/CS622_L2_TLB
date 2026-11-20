"""fs_run.py with a split-memory X86 board so guests can have more than 3 GiB."""
import argparse, os
from m5.objects import IdeDisk, RawDiskImage, X86E820Entry
from m5.params import AddrRange
from m5.util.convert import toMemorySize
from gem5.components.boards.x86_board import X86Board
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory.dram_interfaces.ddr4 import DDR4_2400_8x8
from gem5.components.memory.memory import ChanneledMemory
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_switchable_processor import SimpleSwitchableProcessor
from gem5.isas import ISA
from gem5.resources.resource import DiskImageResource, KernelResource
from gem5.simulate.exit_handler import ExitHandler
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides
import m5

LOW = toMemorySize("3GiB")


class SplitDDR4(ChanneledMemory):
    """Two DDR4 controllers, one per address range (below 3 GiB, above 4 GiB)."""
    def __init__(self, size):
        super().__init__(DDR4_2400_8x8, 2, 64, size=size)

    def set_memory_range(self, ranges):
        if len(ranges) != 2:
            raise Exception("SplitDDR4 needs exactly two ranges")
        self._ranges = list(ranges)
        for ctrl, r in zip(self.mem_ctrl, self._ranges):
            ctrl.dram.range = r

    def get_uninterleaved_range(self):
        return list(self._ranges)


class BigX86Board(X86Board):
    def _setup_memory_ranges(self):
        memory = self.get_memory()
        total = memory.get_size()
        data = [AddrRange(LOW), AddrRange(0x100000000, size=total - LOW)]
        memory.set_memory_range(data)
        self.mem_ranges = data + [AddrRange(0xC0000000, size=0x100000)]

    def _setup_board(self):
        super()._setup_board()
        total = self.get_memory().get_size()
        ent = X86E820Entry(addr=0x100000000, size="%dB" % (total - LOW), range_type=1)
        self.workload.e820_extra = ent
        self.workload.e820_table.entries = list(self.workload.e820_table.entries) + [ent]


ap = argparse.ArgumentParser()
ap.add_argument("--cores", type=int, default=1)
ap.add_argument("--script", required=True)
ap.add_argument("--cpu", default="timing", choices=["timing", "o3"])
ap.add_argument("--start-cpu", default=os.environ.get("FS_START_CPU", "kvm"), choices=["kvm", "atomic"])
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
        proc.core.usePerf = False

board = BigX86Board(
    clk_freq="3GHz",
    processor=processor,
    memory=SplitDDR4(size=os.environ.get("FS_MEM", "12GiB")),
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
    ide.spec_disk = spec_disk
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
