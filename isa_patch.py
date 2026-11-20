import sys,os
d=sys.argv[1]
p=d+"/src/arch/x86/isa/insts/x87/compare_and_test/floating_point_ordered_compare.py"
s=open(p).read()
if "FCOMIP_R" not in s.replace("# FCOMIP",""):
    old="def macroop FCOMI_R\n{\n    compfp st(0), sti\n};\n"
    assert s.count(old)==1,"macroop pattern"
    open(p,"w").write(s.replace(old,old+"\ndef macroop FCOMIP_R\n{\n    compfp st(0), sti, spm=1\n};\n"))
p=d+"/src/arch/x86/isa/decoder/x87.isa"
s=open(p).read()
if "0x3: fcomip();" in s:
    open(p,"w").write(s.replace("                0x3: fcomip();\n","                0x3: Inst::FCOMIP(Rq);\n"))
print("isa patched")
