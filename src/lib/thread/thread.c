#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <pthread.h>


   struct thread_t {
      pthread_t tid;
      struct lua_State *L;
   };

   struct threadstart_arg {
      struct thread_t *o;
      int namelen;
      char modulename[];
   };


_Bool cas_int(int *ptr, int expected, int desired) {
   return __atomic_compare_exchange_n(ptr, &expected, desired, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
}


void *luathread_start(void *voidarg) {
   struct threadstart_arg *arg = voidarg;
   struct thread_t *o = arg->o;

   int ret = luaL_loadstring(o->L, "return debug.traceback((...), 1)");
   int base = lua_gettop(o->L);
   if (ret != 0) {
//       perror("Can't load error handler");
      perror (lua_tostring(o->L, -1));
      free(arg);
      return NULL;
   }

   lua_getglobal(o->L, "require");
   lua_pushlstring(o->L, arg->modulename, arg->namelen);
   free(arg);
   ret = lua_pcall(o->L, 1, 0, base);
   if (ret != 0) {
//       perror ("Can't pcall require(code)");
      perror (lua_tostring(o->L, -1));
      return NULL;
   }

   return NULL;
}


int Lua_Pthread(struct thread_t*o, const char *modulename, int namelen) {
   struct threadstart_arg *arg = malloc(sizeof(struct threadstart_arg) + namelen);
   if (arg == NULL) {
      return errno;
   }
   arg->o = o;
   strncpy(arg->modulename, modulename, namelen);
   arg->namelen = namelen;
   return pthread_create(&o->tid, NULL, luathread_start, arg);
}
