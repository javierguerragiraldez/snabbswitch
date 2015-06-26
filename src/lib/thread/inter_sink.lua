
local config = require('core.config')
local engine = require('core.app')

local c = config.new()
config.app(c, 'sink', 'apps.basic.sink', {input={'//interlink'}})
-- config.link(c, 'source.output -> sink.input')
engine.configure(c)

engine.main{duration=10, report={showlinks=true}}
