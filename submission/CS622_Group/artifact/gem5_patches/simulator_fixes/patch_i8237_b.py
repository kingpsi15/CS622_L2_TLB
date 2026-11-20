import sys
p = sys.argv[1]
s = open(p).read()
if 'Illegal read from i8237 register %d; returning 0' in s:
    print('already patched'); sys.exit(0)
pairs = [
 ('        panic("Illegal read from i8237 register %d.", offset);\n',
  '        warn_once("Illegal read from i8237 register %d; returning 0.", offset);\n        return 0;\n'),
 ('    panic_if(!bitVal, "Turning on i8237 channels unimplemented.");\n',
  '    if (!bitVal)\n        warn_once("Turning on i8237 channels unimplemented; ignored.");\n'),
 ('    panic_if(bitVal, "Requesting i8237 DMA transfers is unimplemented.");\n',
  '    if (bitVal)\n        warn_once("Requesting i8237 DMA transfers unimplemented; ignored.");\n'),
]
for a, b in pairs:
    assert a in s, 'anchor not found: ' + a
    s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
