import sys
p=sys.argv[1]; s=open(p).read()
if '603.bwaves_s,621.wrf_s' in s:
    print(p,'already patched'); sys.exit(0)
anchor='intrate,intspeed=base: # flags for integer base\n'
assert s.count(anchor)==1, 'anchor count %d' % s.count(anchor)
syms='pthread_mutex_destroy pthread_mutex_init pthread_mutex_lock pthread_mutex_trylock pthread_mutex_unlock pthread_cond_broadcast pthread_cond_destroy pthread_cond_init pthread_cond_wait pthread_create pthread_join pthread_self pthread_key_create pthread_key_delete pthread_getspecific pthread_setspecific __pthread_key_create'.split()
u=' '.join('-Wl,-u,'+x for x in syms)
blk=('603.bwaves_s,621.wrf_s,627.cam4_s,628.pop2_s,649.fotonik3d_s,654.roms_s=base:\n'
     '   # static glibc: weak pthread refs in libgfortran/libgomp resolve to 0 unless forced in\n'
     '   LDOPTIMIZE     = -static '+u+'\n\n'
     '520.omnetpp_r,620.omnetpp_s=base:\n'
     '   # C++17 adds 3-arg std::hypot; bare "hypot" then binds to the 3-arg cMathFunction ctor\n'
     '   CXXPORTABILITY = -fpermissive -std=gnu++14\n\n')
open(p,'w').write(s.replace(anchor, blk+anchor)); print(p,'patched')
