
require("core.lib")
require("core.clib_h")
require("core.lib_h")
local S = require('syscall')
local config = require('core.config')
local engine = require('core.app')

local c = config.new()
config.app(c, 'source', 'apps.basic.source', {size=120})
config.app(c, 'sink', 'apps.basic.sink')
config.link(c, 'source.output -> sink.input')
engine.configure(c)

engine.main{duration=1, report={}}
