local config = require('core.config')
local engine = require('core.app')
local basic_apps = require('apps.basic.basic_apps')
inter_link = require('lib.thread.inter_link')

print ('send:', require('syscall').getpid())

local c = config.new()
-- config.app(c, 'source', 'apps.basic.source', {size=120, output={'//interlink'}})
config.app(c, 'source', basic_apps.Source, {size=120, output={inter_link('/interlink')}})
-- config.link(c, 'source.output -> sink.input')
print ('send added')
engine.configure(c)
print ('send configured')

engine.main{duration=10, report={showlinks=true}}
