
typedef struct {
   struct statebox sbx;
   int16_t ctx;
} cobox_t;

cobox_t *cobox_create(size_t stacksize);
int cobox_yield(int16_t index, int v);
int cobox_resume(int16_t index, int v);
