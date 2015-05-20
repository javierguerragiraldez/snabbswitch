
#include <stddef.h>
#include <stdlib.h>
#include "jcontext.h"

void jmakecontext(jucontext_t *ucp, void (*fn)(void), int argc, unsigned long arg) {
    unsigned long stack = (unsigned long) ucp->uc_stack.ss_sp;
    unsigned long stack_size = ucp->uc_stack.ss_size;

    if (argc != 1) abort();

    /* need to push stack pointer, f as ip and data as first arg */
    ucp->uc_regs[6] = stack + stack_size - 8; /* grows down */
    ucp->uc_regs[7] = (unsigned long) fn;
    ucp->uc_regs[8] = (unsigned long) arg;
}


int jgetcontext(jucontext_t *ucp) {
	return 0;
}
