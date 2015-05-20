

struct __jucontext_stack_t {
    void *ss_sp;
    int ss_flags;
    size_t ss_size;
};
typedef struct jucontext_t {
    unsigned long uc_regs[9];
    unsigned long uc_flags;
    void *uc_link;
    struct __jucontext_stack_t uc_stack;
} jucontext_t;


void jmakecontext(jucontext_t *ucp, void (*fn)(void), int argc, unsigned long arg);
int jgetcontext(jucontext_t *ucp);
int jswapcontext(jucontext_t *oucp, jucontext_t *ucp);
