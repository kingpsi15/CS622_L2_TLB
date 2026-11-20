import sys
p = sys.argv[1] + "/src/arch/x86/pagetable_walker.cc"
s = open(p).read()
old = """        if (doWrite) {
            write = oldRead;
            if (dataSize == 8)
                write->setLE<uint64_t>(pte);
            else
                write->setLE<uint32_t>(pte);
            write->cmd = MemCmd::WriteReq;
        } else {"""
new = """        if (doWrite) {
            // Fresh write packet: recycling the response packet can carry a
            // stale cache-responding flag into CoherentXBar::recvTimingReq.
            RequestPtr wreq = std::make_shared<Request>(
                oldRead->req->getPaddr(), oldRead->getSize(),
                oldRead->req->getFlags(), walker->requestorId);
            write = new Packet(wreq, MemCmd::WriteReq);
            write->allocate();
            if (dataSize == 8)
                write->setLE<uint64_t>(pte);
            else
                write->setLE<uint32_t>(pte);
            delete oldRead;
        } else {"""
if "wreq" in s:
    print("already patched", p); sys.exit(0)
assert s.count(old) == 1, "pattern not found in " + p
open(p + ".orig_walker", "w").write(s)
open(p, "w").write(s.replace(old, new))
print("patched", p)
