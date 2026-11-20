import sys

d = sys.argv[1]

# 1. Ensure FCOMIP_R macroop and decoder entry are patched
p = d + "/src/arch/x86/isa/insts/x87/compare_and_test/floating_point_ordered_compare.py"
s = open(p).read()
if "FCOMIP_R" not in s.replace("# FCOMIP", ""):
    old = "def macroop FCOMI_R\n{\n    compfp st(0), sti\n};\n"
    assert s.count(old) == 1, f"FCOMI_R pattern mismatch in {p}"
    open(p, "w").write(s.replace(old, old + "\ndef macroop FCOMIP_R\n{\n    compfp st(0), sti, spm=1\n};\n"))

p = d + "/src/arch/x86/isa/decoder/x87.isa"
s = open(p).read()
if "0x3: fcomip();" in s:
    s = s.replace("                0x3: fcomip();\n", "                0x3: Inst::FCOMIP(Rq);\n")
assert "0x3: Inst::FCOMIP(Rq);" in s, f"FCOMIP decoder missing in {p}"

# 2. Patch FXAM decoder entry
if "0x5: fxam();" in s:
    s = s.replace("                    0x5: fxam();\n", "                    0x5: Inst::FXAM();\n")
assert "0x5: Inst::FXAM();" in s, f"FXAM decoder missing in {p}"
open(p, "w").write(s)

# 3. Add Examfp microop to fpop.isa
p = d + "/src/arch/x86/isa/microops/fpop.isa"
s = open(p).read()
if "class Examfp(" not in s:
    target = "    class Pop87(Fp0Op):\n"
    assert s.count(target) == 1, f"Pop87 anchor missing in {p}"
    exam_cls = """    class Examfp(FpOp):
        operand_types = (FloatSrc1Op,)
        code = '''
            [[maybe_unused]] RegVal new_fsw =
                FSW & ~(CC0Bit | CC1Bit | CC2Bit | CC3Bit);
            if (std::signbit(FpSrcReg1))
                new_fsw |= CC1Bit;
            if (((FTW >> (TOP * 2)) & 0x3) == 0x3) {
                new_fsw |= (CC3Bit | CC0Bit);
            } else {
                switch (std::fpclassify(FpSrcReg1)) {
                  case FP_NAN:
                    new_fsw |= CC0Bit;
                    break;
                  case FP_INFINITE:
                    new_fsw |= (CC2Bit | CC0Bit);
                    break;
                  case FP_ZERO:
                    new_fsw |= CC3Bit;
                    break;
                  case FP_SUBNORMAL:
                    new_fsw |= (CC3Bit | CC2Bit);
                    break;
                  case FP_NORMAL:
                  default:
                    new_fsw |= CC2Bit;
                    break;
                }
            }
        '''
        flag_code = 'FSW = new_fsw;'

"""
    open(p, "w").write(s.replace(target, exam_cls + target))

# 4. Implement FXAM macroop in classify.py
p = d + "/src/arch/x86/isa/insts/x87/compare_and_test/classify.py"
s = open(p).read()
if "def macroop FXAM" not in s:
    assert "# FXAM\n" in s, f"# FXAM anchor missing in {p}"
    s = s.replace("# FXAM\n", "# FXAM\ndef macroop FXAM\n{\n    examfp st(0), SetStatus=True\n};\n")
    open(p, "w").write(s)

print(f"patched v2 OK: {d}")
