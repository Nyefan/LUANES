local cpu = require "emu.cpu"
local apu = require "emu.apu"
local ppu = require "emu.ppu"
local cartridge = require "emu.cartridge"
local controller = require "emu.controller"
local mapper = require "emu.mapper"
local ram = require "emu.ram"

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