-- Filename: bit8.lua
-- Author: Nyefan
-- Contact: nyefancoding@gmail.com
-- An 8 bit wrapper of the standard bit32 library

bit32 = require "bit32"

local bit8 = {}

function bit8.arshift(value, displacement)
  bit32.arshift(bit32.band(value, 0xFF), displacement)
end

function bit8.band(...)
  return bit32.band(..., 0xFF)
end

function bit8.bnot(value)
  return bit8.bnot(bit8.band(value, 0xFF))
end

function bit8.bor(...)
  return bit32.band(bit32.bor(...), 0xFF)
end

function bit8.btest(...)
  return bit32.btest(bit32.band(...), 0xFF)
end

function bit8.bxor(...)
  return bit32.band(bit32.bxor(...), 0xFF)
end

function bit8.extract(n, f, w)
  w = w or 1;
  return bit32.band(bit32.extract(n, f, w), 0xFF)
end

function bit8.replace(n, v, f, w)
  w = w or 1;
  return bit32.band(bit32.replace(n, v, f, w), 0xFF)
end

function bit8.lrotate(value, displacement)
  temp = bit32.band(value, 0xFF)
  return bit32.lrotate(bit32.bxor(temp, bit32.lshift(temp, 8), bit32.lshift(temp, 16), bit32.lshift(temp, 24)), displacement)
end

function bit8.lshift(value, displacement)
  return bit32.lshift(bit32.band(value, 0xFF), displacement)
end

function bit8.rrotate(value, displacement)
  temp = bit32.band(value, 0xFF)
  return bit32.rrotate(bit32.bor(temp, bit32.lshift(temp, 8), bit32.lshift(temp, 16), bit32.lshift(temp, 24)), displacement)
end

function bit8.lrshift(value, displacement)
  return bit32.rshift(bit32.band(value, 0xFF), displacement)
end

return bit8