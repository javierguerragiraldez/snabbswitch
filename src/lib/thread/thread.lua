local ffi = require('ffi')
local C = ffi.C



ffi.cdef [[
   typedef struct lua_State lua_State;

   lua_State *luaL_newstate (void);
   void luaL_openlibs (lua_State *L);
]]


ffi.cdef [[
   typedef unsigned long int pthread_t;

   int pthread_join(pthread_t thread, void **retval);


   struct thread_t {
      pthread_t tid;
      struct lua_State *L;
   };

   int Lua_Pthread(struct thread_t*o, const char *modulename, int namelen);
]]

local Thread = {}
Thread.__index = Thread

local Thread_t = ffi.typeof('struct thread_t')


function Thread:__new(code)
   local o = ffi.new(self)
   o.L = C.luaL_newstate()
   assert(o.L ~= nil, "Couldn't allocate new Lua_State")
   C.luaL_openlibs(o.L)

   assert(C.Lua_Pthread(o, code, #code) == 0, "Can't create pthread")
   return o
end


local _retval = ffi.new('void *[1]')
function Thread:join()
   C.pthread_join(self.tid, _retval)
end

Thread.__gc = Thread.join


return ffi.metatype(Thread_t, Thread)
