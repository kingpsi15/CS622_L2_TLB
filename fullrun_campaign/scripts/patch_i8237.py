import sys
p = sys.argv[1]
s = open(p).read()
if 'returning 0' in s:
    print('already patched'); sys.exit(0)
a = '        panic("Read from i8237 %s unimplemented.", label);\n'
b = '        panic("Write to i8237 %s unimplemented.", label);\n'
assert a in s and b in s, 'anchor not found'
open(p + '.orig', 'w').write(s)
s = s.replace(a, '        warn_once("Read from i8237 %s unimplemented; returning 0.", label);\n        return 0;\n')
s = s.replace(b, '        warn_once("Write to i8237 %s unimplemented; ignored.", label);\n')
open(p, 'w').write(s)
print('patched')
