module(..., package.seeall)

local app = require ('core.app')
local basic_apps = require ('apps.basic.basic_apps')
local tunnel = require ('apps.keyed_ipv6_tunnel.tunnel')


local tunnel_config = {
   local_address = "00::2:1",
   remote_address = "00::2:1",
   local_cookie = "12345678",
   remote_cookie = "12345678",
   default_gateway_MAC = "a1:b2:c3:d4:e5:f6"
}

app.configure (config.new())

local c = config.new()
config.app(c, "source", basic_apps.Source, {size=1500})
config.app(c, "tunnel", tunnel.SimpleKeyedTunnel, tunnel_config)
config.app(c, "sink", basic_apps.Sink)
config.link(c, "source.output -> tunnel.decapsulated")
config.link(c, "tunnel.encapsulated -> tunnel.encapsulated")
config.link(c, "tunnel.decapsulated -> sink.input")
app.configure(c)

app.main{duration = 10, report={}}
