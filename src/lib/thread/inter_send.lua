local config = require('core.config')
local engine = require('core.app')

local c = config.new()
config.app(c, 'source', 'apps.basic.source', {size=120, output={'//interlink'}})
-- config.link(c, 'source.output -> sink.input')
engine.configure(c)

engine.main{duration=10, report={showlinks=true}}
