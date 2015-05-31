

_Bool cas_int(int *ptr, int expected, int desired) {
   return __atomic_compare_exchange_n(ptr, &expected, desired, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
}
