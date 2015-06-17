#include <stdint.h>


uint64_t atomic_add_u64(uint64_t *p, uint64_t x) {
   return __atomic_add_fetch (p, x, __ATOMIC_SEQ_CST);
}
