#include <stdint.h>
#include <stdlib.h>
#include <ucontext.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

struct statebox {
   lua_State *L;
};

#include "cobox.h"

#define MAX_CONTEXTS (32)

static ucontext_t context_array[MAX_CONTEXTS];
static cobox_t cobox_array[MAX_CONTEXTS];


typedef void (*voidfunc)();

static void cobox_pcall(int index) {
   lua_pcall(cobox_array[index].sbx.L, 0, 0, 0);
}


cobox_t *cobox_create(size_t stacksize) {
   static int16_t top = 1;
   ucontext_t *ctx = &context_array[top];
   cobox_t *cbx = &cobox_array[top];
   cbx->ctx = top;

   if (getcontext(ctx) < 0) {
      return NULL;
   }
   void *stack = malloc(stacksize);
   if (! stack) {
      return NULL;
   }
   ctx->uc_stack.ss_sp = stack;
   ctx->uc_stack.ss_size = stacksize;
   ctx->uc_link = &context_array[0];
   makecontext(ctx, (voidfunc)cobox_pcall, 1, top);

   cbx->sbx.L = luaL_newstate();
   if (! cbx->sbx.L) {
      free (stack);
      return NULL;
   }
   luaL_openlibs(cbx->sbx.L);

   top++;
   return cbx;
}


static int yield_arg;
static int swap(int16_t from, int16_t to, int v) {
   yield_arg = v < 0 ? 0 : v;
   if (swapcontext(&context_array[from], &context_array[to]) < 0) {
      return -1;
   }
   return yield_arg;
}

int cobox_yield(int16_t index, int v) {
   return swap(index, 0, v);
}


int cobox_resume(int16_t index, int v) {
   return swap(0, index, v);
}
