cpu = require "emu.cpu"
apu = require "emu.apu"
ppu = require "emu.ppu"
cartridge = require "emu.cartridge"
controller = require "emu.controller"
mapper = require "emu.mapper"
ram = require "emu.ram"

function start_emu()
  start_cpu()
  start_apu()
  start_ppu()
  start_cartridge()
  start_controller()
  start_mapper()
  start_ram()
  print("emulator started")
end