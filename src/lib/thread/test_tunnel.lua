local app = require("core.app")

local tunnel_config = {
   local_address = "00::2:1",
   remote_address = "00::2:1",
   local_cookie = "12345678",
   remote_cookie = "12345678",
   default_gateway_MAC = "a1:b2:c3:d4:e5:f6"
}

app.configure (config.new())

local c = config.new()
config.app(c, "source", 'apps.basic.source', {size=1500})
config.app(c, "tunnel", 'apps.keyed_ipv6_tunnel.tunnel', tunnel_config)
config.app(c, "sink", 'apps.basic.sink')
config.link(c, "source.output -> tunnel.decapsulated")
config.link(c, "tunnel.encapsulated -> tunnel.encapsulated")
config.link(c, "tunnel.decapsulated -> sink.input")
app.configure(c)

app.main{duration = 10, report={}}
