#################################
# Architecture dependent settings
#################################

ifndef ARCH
    ARCH_NAME = $(shell uname -m)
endif

ifeq ($(ARCH_NAME), i386)
    ARCH = x86
    CFLAGS += -m32
    LDFLAGS += -m32
    SSPFD = -lsspfd_x86
    LDFLAGS += -L$(LIBSSMEM)/lib -lssmem_x86
endif

ifeq ($(ARCH_NAME), i686)
    ARCH = x86
    CFLAGS += -m32
    LDFLAGS += -m32
    SSPFD = -lsspfd_x86
    LDFLAGS += -L$(LIBSSMEM)/lib -lssmem_x86
endif

ifeq ($(ARCH_NAME), x86_64)
    ARCH = x86_64
    CFLAGS += -m64
    LDFLAGS += -m64
    SSPFD = -lsspfd_x86_64
    LDFLAGS += -L$(LIBSSMEM)/lib -lssmem_x86_64
endif

ifeq ($(ARCH_NAME), sun4v)
    ARCH = sparc64
    CFLAGS += -DSPARC=1 -DINLINED=1 -m64
    LDFLAGS += -lrt -m64
    SSPFD = -lsspfd_sparc64
    LDFLAGS += -L$(LIBSSMEM)/lib -lssmem_sparc64
endif

ifeq ($(ARCH_NAME), tile)
    LDFLAGS += -L$(LIBSSMEM)/lib -lssmem_tile
    SSPFD = -lsspfd_tile
endif

CFLAGS = -D_GNU_SOURCE

ifeq ($(DEBUG),1)
  DEBUG_FLAGS=-Wall -ggdb -g -DDEBUG
  CFLAGS += -O0 -DADD_PADDING -fno-inline
else ifeq ($(DEBUG),2)
  DEBUG_FLAGS=-Wall
  CFLAGS += -O0 -DADD_PADDING -fno-inline
else ifeq ($(DEBUG),3)
  DEBUG_FLAGS=-Wall -g -ggdb 
  CFLAGS += -O3 -DADD_PADDING -fno-inline
else
  DEBUG_FLAGS=-Wall
  CFLAGS += -O3 -DADD_PADDING
endif

ifeq ($(SET_CPU),0)
	CFLAGS += -DNO_SET_CPU
endif

ifeq ($(LATENCY),1)
	CFLAGS += -DCOMPUTE_LATENCY -DDO_TIMINGS
endif

ifeq ($(LATENCY),2)
	CFLAGS += -DCOMPUTE_LATENCY -DDO_TIMINGS -DUSE_SSPFD -DLATENCY_ALL_CORES=0
	LIBS += $(SSPFD) -lm
endif

ifeq ($(LATENCY),3)
	CFLAGS += -DCOMPUTE_LATENCY -DDO_TIMINGS -DUSE_SSPFD -DLATENCY_ALL_CORES=1
	LIBS += $(SSPFD) -lm
endif

ifeq ($(LATENCY),4)
	CFLAGS += -DCOMPUTE_LATENCY -DDO_TIMINGS -DUSE_SSPFD -DLATENCY_PARSING=1
	LIBS += $(SSPFD) -lm
endif

ifeq ($(LATENCY),5)
	CFLAGS += -DCOMPUTE_LATENCY -DDO_TIMINGS -DUSE_SSPFD -DLATENCY_PARSING=1 -DLATENCY_ALL_CORES=1
	LIBS += $(SSPFD) -lm
endif

TOP := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

LIBS+=-L$(TOP)/external/lib -L$(TOP)

SRCPATH := $(TOP)/src
MAININCLUDE := $(TOP)/include

ifeq ($(M),1)
LIBS += -lsspfd
CFLAGS += -DUSE_SSPFD
endif

ALL = 	clht_lb clht_lb_res clht_lb_res_no_next clht_lb_ro clht_lb_linked clht_lb_packed \
	clht_lf clht_lf_res clht_lf_only_map_rem \
	math_cache_lb math_cache_lf math_cache_lock_ins \
	snap_stress noise

# default setings
PLATFORM=-DDEFAULT
GCC=gcc
PLATFORM_NUMA=0
OPTIMIZE=
LIBS += -lrt -lpthread -lm  -lclht -lssmem

UNAME := $(shell uname -n)

ifeq ($(UNAME), lpd48core)
PLATFORM=-DOPTERON
GCC=gcc-4.8
PLATFORM_NUMA=1
OPTIMIZE=-DOPTERON_OPTIMIZE
LIBS += -lrt -lpthread -lm -lnuma
endif

ifeq ($(UNAME), lpdxeon2680)
PLATFORM=-DXEON2
GCC=gcc
PLATFORM_NUMA=1
OPTIMIZE=
LIBS += -lrt -lpthread -lm -lnuma
endif

ifeq ($(UNAME), lpdpc4)
PLATFORM=-DCOREi7
GCC=gcc
PLATFORM_NUMA=0
OPTIMIZE=
LIBS += -lrt -lpthread -lm
endif

ifeq ($(UNAME), lpdpc34)
PLATFORM=-DCOREi7 -DRTM
GCC=gcc-4.8
PLATFORM_NUMA=0
OPTIMIZE=
LIBS += -lrt -lpthread -lm -mrtm
endif

ifeq ($(UNAME), diascld9)
PLATFORM=-DOPTERON2
GCC=gcc
LIBS += -lrt -lpthread -lm
endif

ifeq ($(UNAME), diassrv8)
PLATFORM=-DXEON
GCC=gcc
PLATFORM_NUMA=1
LIBS += -lrt -lpthread -lm -lnuma
endif

ifeq ($(UNAME), diascld19)
PLATFORM=-DXEON2
GCC=gcc
LIBS += -lrt -lpthread -lm
endif

ifeq ($(UNAME), maglite)
PLATFORM=-DSPARC
GCC:=/opt/csw/bin/gcc
LIBS+= -lrt -lpthread -lm
CFLAGS += -m64 -mcpu=v9 -mtune=v9
endif

ifeq ($(UNAME), parsasrv1.epfl.ch)
PLATFORM=-DTILERA
GCC=tile-gcc
LIBS += -lrt -lpthread -lm -ltmc
endif

ifeq ($(UNAME), smal1.sics.se)
PLATFORM=-DTILERA
GCC=tile-gcc
LIBS += -lrt -lpthread -lm -ltmc
endif

ifeq ($(UNAME), ol-collab1)
PLATFORM=-DT44
GCC=/usr/sfw/bin/gcc
CFLAGS += -m64
LIBS+= -lrt -lpthread -lm
endif

CFLAGS += $(PLATFORM)
CFLAGS += $(OPTIMIZE)
CFLAGS += $(DEBUG_FLAGS)

INCLUDES := -I$(MAININCLUDE) -I$(TOP)/external/include
OBJ_FILES := clht_gc.o

SRC := src

BMARKS := bmarks

#MAIN_BMARK := $(BMARKS)/test.c
#MAIN_BMARK := $(BMARKS)/test_ro.c
MAIN_BMARK := $(BMARKS)/test_mem.c


default: normal

all: $(ALL)

.PHONY: $(ALL)

normal: clht_lb_res clht_lf_res 


%.o:: $(SRC)/%.c 
	$(GCC) $(CFLAGS) $(INCLUDES) -o $@ -c $<

################################################################################
# library
################################################################################

TYPE = clht_lb
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb.o $(OBJ_FILES)

TYPE = clht_lb_res
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb_res.o $(OBJ_FILES)

TYPE = clht_lb_res_no_next
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb_res_no_next.o $(OBJ_FILES)

TYPE = clht_lb_linked
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb_linked.o $(OBJ_FILES)

TYPE = clht_lb_packed
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb_packed.o $(OBJ_FILES)

TYPE = clht_lb_lock_ins
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lb_lock_ins.o $(OBJ_FILES)

TYPE = clht_lf
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lf.o $(OBJ_FILES)

TYPE = clht_lf_res
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lf_res.o $(OBJ_FILES)

TYPE = clht_lf_only_map_rem
OBJ = $(TYPE).o
lib$(TYPE).a: $(OBJ_FILES) $(OBJ)
	@echo Archive name = libclht.a
	ar -r libclht.a clht_lf_only_map_rem.o $(OBJ_FILES)

################################################################################
# lock-based targets
################################################################################

TYPE = clht_lb
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) -DNO_RESIZE $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lb $(LIBS) -lclht

TYPE = clht_lb_res
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) $(INCLUDES) $(CFLAGS) $(MAIN_BMARK) $(SRC)/clht_lb_res.c -o clht_lb_res $(LIBS)

TYPE = clht_lb_res_no_next
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lb_nn $(LIBS)

TYPE = clht_lb_linked
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lb_linked $(LIBS)

TYPE = clht_lb_packed
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) $(SRC)/clht_lb_packed.c -o clht_lb_packed $(LIBS)

TYPE = clht_lb_lock_ins
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) -DLOCK_INS $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lb_lock_ins $(LIBS)

################################################################################
# lock-free targets
################################################################################

TYPE = clht_lf
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) -DLOCKFREE $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lf $(LIBS)

TYPE = clht_lf_res
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) -DLOCKFREE_RES $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lf_res $(LIBS)

TYPE = clht_lf_only_map_rem
$(TYPE): $(MAIN_BMARK) lib$(TYPE).a
	$(GCC) -DLOCKFREE $(CFLAGS) $(INCLUDES) $(MAIN_BMARK) -o clht_lf_only_map_rem $(LIBS)

################################################################################
# other tests
################################################################################

math_cache_lb: $(BMARKS)/math_cache.c libclht_lb_res.a
	$(GCC) $(INCLUDES) $(CFLAGS) $(BMARKS)/math_cache.c -o math_cache_lb $(LIBS)

math_cache_lf: $(BMARKS)/math_cache.c libclht_lf_res.a
	$(GCC) -DLOCKFREE $(CFLAGS) $(INCLUDES) $(BMARKS)/math_cache.c -o math_cache_lf $(LIBS)

snap_stress: $(BMARKS)/snap_stress.c libclht_lf_res.a
	$(GCC) -DLOCKFREE $(CFLAGS) $(INCLUDES) $(BMARKS)/snap_stress.c -o snap_stress $(LIBS)

math_cache_lock_ins: $(BMARKS)/math_cache.c libclht_lb_lock_ins.a
	$(GCC) -DLOCK_INS $(CFLAGS) $(INCLUDES) $(BMARKS)/math_cache.c -o math_cache_lock_ins $(LIBS)

noise: $(BMARKS)/noise.c $(OBJ_FILES)
	$(GCC) $(CFLAGS) $(INCLUDES) $(OBJ_FILES) $(BMARKS)/noise.c -o noise $(LIBS)



clean:				
	rm -f *.o *.a clht_* math_cache* snap_stress
