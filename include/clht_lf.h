#ifndef _LFHT_RES_H_
#define _LFHT_RES_H_

#include <stdlib.h>
#include <stdio.h>
#include <inttypes.h>
#include "atomic_ops.h"
#include "utils.h"

#include "ssmem.h"

extern __thread ssmem_allocator_t* clht_alloc;

#define true 1
#define false 0

/* #define DEBUG */

#if defined(DEBUG)
#  define DPP(x)	x++				
#else
#  define DPP(x)
#endif

#define CACHE_LINE_SIZE    64

#define MAP_INVLD 0
#define MAP_VALID 1
#define MAP_INSRT 2

#define KEY_BUCKT 3
#define ENTRIES_PER_BUCKET KEY_BUCKT


#ifndef ALIGNED
#  if __GNUC__ && !SCC
#    define ALIGNED(N) __attribute__ ((aligned (N)))
#  else
#    define ALIGNED(N)
#  endif
#endif

#define likely(x)       __builtin_expect((x), 1)
#define unlikely(x)     __builtin_expect((x), 0)

#if defined(__sparc__)
#  define PREFETCHW(x) 
#  define PREFETCH(x) 
#  define PREFETCHNTA(x) 
#  define PREFETCHT0(x) 
#  define PREFETCHT1(x) 
#  define PREFETCHT2(x) 

#  define PAUSE    asm volatile("rd    %%ccr, %%g0\n\t" \
				::: "memory")
#  define _mm_pause() PAUSE
#  define _mm_mfence() __asm__ __volatile__("membar #LoadLoad | #LoadStore | #StoreLoad | #StoreStore");
#  define _mm_lfence() __asm__ __volatile__("membar #LoadLoad | #LoadStore");
#  define _mm_sfence() __asm__ __volatile__("membar #StoreLoad | #StoreStore");


#elif defined(__tile__)
#  define _mm_lfence() arch_atomic_read_barrier()
#  define _mm_sfence() arch_atomic_write_barrier()
#  define _mm_mfence() arch_atomic_full_barrier()
#  define _mm_pause() cycle_relax()
#endif

#define CAS_U64_BOOL(a, b, c) (CAS_U64(a, b, c) == b)
inline int is_power_of_two(unsigned int x);

typedef uintptr_t clht_addr_t;
typedef volatile uintptr_t clht_val_t;
typedef uint64_t lfht_snapshot_all_t;

typedef union
{
  volatile uint64_t snapshot;
  struct
  {
#if KEY_BUCKT == 4
    uint32_t version;
#elif KEY_BUCKT == 6
    uint16_t version;
#else
    uint32_t version;
#endif
    uint8_t map[KEY_BUCKT];
  };
} lfht_snapshot_t;

#if __GNUC__ > 4 && __GNUC_MINOR__ > 4
_Static_assert (sizeof(lfht_snapshot_t) == 8, "sizeof(lfht_snapshot_t) == 8");
#endif

typedef volatile struct ALIGNED(CACHE_LINE_SIZE) bucket_s
{
  union
  {
    volatile uint64_t snapshot;
    struct
    {
#if KEY_BUCKT == 4
      uint32_t version;
#elif KEY_BUCKT == 6
      uint16_t version;
#else
      uint32_t version;
/* #  error "KEY_BUCKT should be either 4 or 6" */
#endif
      uint8_t map[KEY_BUCKT];
    };
  };
  clht_addr_t key[KEY_BUCKT];
  clht_val_t val[KEY_BUCKT];
} bucket_t;

#if __GNUC__ > 4 && __GNUC_MINOR__ > 4
_Static_assert (sizeof(bucket_t) % 64 == 0, "sizeof(bucket_t) == 64");
#endif

typedef struct ALIGNED(CACHE_LINE_SIZE) lfht_wrapper
{
  union
  {
    struct
    {
      struct clht_hashtable_s* ht;
      uint8_t next_cache_line[CACHE_LINE_SIZE - (sizeof(void*))];
    };
    uint8_t padding[2 * CACHE_LINE_SIZE];
  };
} clht_t;

typedef struct ALIGNED(CACHE_LINE_SIZE) clht_hashtable_s
{
  union
  {
    struct
    {
      size_t num_buckets;
      bucket_t* table;
      size_t hash;
    };
    uint8_t padding[2*CACHE_LINE_SIZE];
  };
} clht_hashtable_t;

inline uint64_t __ac_Jenkins_hash_64(uint64_t key);

/* Hash a key for a particular hashtable. */
uint32_t clht_hash(clht_hashtable_t* hashtable, clht_addr_t key );


static inline int
snap_get_empty_index(uint64_t snap)
{
  lfht_snapshot_t s = { .snapshot = snap };
  int i;
  for (i = 0; i < KEY_BUCKT; i++)
    {
      if (s.map[i] == MAP_INVLD)
	{
	  return i;
	}
    }
  return -1;
}

static inline int
keys_get_empty_index(clht_addr_t* keys)
{
  int i;
  for (i = 0; i < KEY_BUCKT; i++)
    {
      if (keys[i] == 0)
	{
	  return i;
	}
    }
  return -1;
}

static inline int
buck_get_empty_index(bucket_t* b, uint64_t snap)
{
  lfht_snapshot_t s = { .snapshot = snap };

  int i;
  for (i = 0; i < KEY_BUCKT; i++)
    {
      if (b->key[i] == 0 && s.map[i] != MAP_INSRT)
	{
	  return i;
	}
    }
  return -1;
}


static inline int
vals_get_empty_index(clht_val_t* vals, lfht_snapshot_all_t snap)
{
  lfht_snapshot_t s = { .snapshot = snap };

  int i;
  for (i = 0; i < KEY_BUCKT; i++)
    {
      if (vals[i] == 0 && s.map[i] != MAP_INSRT)
	{
	  return i;
	}
    }
  return -1;
}


static inline uint64_t
snap_set_map(uint64_t s, int index, int val)
{
  lfht_snapshot_t s1 = { .snapshot = s };
  s1.map[index] = val;
  return s1.snapshot;
}

static inline uint64_t
snap_set_map_and_inc_version(uint64_t s, int index, int val)
{
  lfht_snapshot_t s1 = { .snapshot =  s};
  s1.map[index] = val;
  s1.version++;
  return s1.snapshot;
}

static inline void
_mm_pause_rep(uint64_t w)
{
  while (w--)
    {
      _mm_pause();
    }
}



/* ******************************************************************************** */
/* inteface */
/* ******************************************************************************** */

/* Create a new hashtable. */
clht_hashtable_t* clht_clht_hashtable_create(uint32_t num_buckets);
clht_t* clht_create(uint32_t num_buckets);

/* Insert a key-value pair into a hashtable. */
int clht_put(clht_t* hashtable, clht_addr_t key, clht_val_t val);

/* Retrieve a key-value pair from a hashtable. */
clht_val_t clht_get(clht_hashtable_t* hashtable, clht_addr_t key);

/* Remove a key-value pair from a hashtable. */
clht_val_t clht_remove(clht_t* hashtable, clht_addr_t key);

size_t clht_size(clht_hashtable_t* hashtable);
size_t clht_size_mem(clht_hashtable_t* hashtable);
size_t clht_size_mem_garbage(clht_hashtable_t* hashtable);

void ht_gc_thread_init(clht_t* hashtable, int id);
inline void ht_gc_thread_version(clht_hashtable_t* h);
inline int lfht_gc_get_id();
int ht_gc_collect(clht_t* h);
int ht_gc_collect_all(clht_t* h);
int ht_gc_free(clht_hashtable_t* hashtable);
void ht_gc_destroy(clht_t* hashtable);

void clht_print(clht_hashtable_t* hashtable);
size_t ht_status(clht_t* hashtable, int resize_increase, int just_print);

bucket_t* clht_bucket_create();
int ht_resize_pes(clht_t* hashtable, int is_increase, int by);
void  clht_print_retry_stats();

#endif /* _LFHT_RES_H_ */

