
module(..., package.seeall)
local pci       = require("lib.hardware.pci")
local virtio_dev = require("apps.vguest.vguest_dev")


local VGuest = {}
VGuest.__index = VGuest


function VGuest:new(args)
   return setmetatable({
      device = assert(virtio_dev.VGdev:new(args)),
   }, self)
end


function VGuest:stop()
   self.device:close()
end


function VGuest:push()
   local dev = self.device
   local l = self.input.rx
   if not dev or not l then return end

   local transmitted = false
   while not l:empty() and dev:can_transmit() do
      dev:transmit(l:receive())
      transmitted = true
   end
   dev:sync_transmit(transmitted)
end


function VGuest:pull()
   local dev = self.device
   local l = self.output.tx
   if not dev or not l then return end

   dev:sync_receive()
   while not l:full() and dev:can_receive() do
      io.write('c')
      l:transmit(dev:receive())
   end
--    io.write('f')
   self:add_receive_buffers()
--    io.write('d')
end


function VGuest:add_receive_buffers()
   local dev = self.device
   local new_buffs = false
   while dev:can_add_receive_buffer() do
--       io.write('a')
      dev:add_receive_buffer(packet.allocate())
      new_buffs = true
   end
   if new_buffs then io.write('b'); dev:sync_receive(true) end
end


local pcap = require("apps.pcap.pcap")
local basic_apps = require("apps.basic.basic_apps")


function selftest()
   local pcidev = '0000:00:03.0'       -- os.getenv("SNABB_TEST_VIRTIO_PCIDEV")
   local input_file = "apps/keyed_ipv6_tunnel/selftest.cap.input"
--    local vg = VGuest:new({pciaddr=pcidev})

   engine.configure(config.new())
   local c = config.new()
--    config.app(c, 'source', pcap.PcapReader, input_file)
   config.app(c, 'source', basic_apps.Source)
   config.app(c, 'vguest', VGuest, {pciaddr=pcidev})
   config.app(c, 'sink', basic_apps.Sink)
   config.link(c, 'source.output -> vguest.rx')
   config.link(c, 'vguest.tx -> sink.input')
   engine.configure(c)
--    engine.busywait = true
   engine.main({duration = 1, report={showlinks=true, showapps=true}})

end


-- function selftest()
--    local pcidev = '0000:00:03.0'       -- os.getenv("SNABB_TEST_VIRTIO_PCIDEV")
--
--    engine.configure(config.new())
--    local c = config.new()
--    config.app(c, 'vguest', VGuest, {pciaddr=pcidev})
--    config.app(c, 'sink', basic_apps.Sink)
--    config.link(c, 'vguest.tx -> sink.input')
--    engine.configure(c)
-- --    engine.busywait = true
--    engine.main({duration = 10, report={showlinks=true, showapps=true}})
-- end
