
local config = require('core.config')
local engine = require('core.app')
local basic_apps = require('apps.basic.basic_apps')
inter_link = require('lib.thread.inter_link')

print ('sink:', require('syscall').getpid())

local c = config.new()
-- config.app(c, 'sink', 'apps.basic.sink', {input={'//interlink'}})
config.app(c, 'sink', basic_apps.Sink, {input={inter_link('/interlink')}})
-- config.link(c, 'source.output -> sink.input')
engine.configure(c)

engine.main{duration=10, report={showlinks=true}}
