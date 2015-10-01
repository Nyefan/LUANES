-- Filename: emu.cpu.lua
-- Author: Nyefan
-- Contact: nyefancoding@gmail.com
-- This file handles emulation of the CPU (6602) on the RP2A03 (NTSC) and RP2A07 (PAL) MCs

-- CPU management data
local Cycles = 0 --number of cycles that have been executed

-- CPU components
local A  --accumulator
local X  --register, X
local Y  --register, Y
local B  --flag, break
local C  --flag, carry
local D  --flag, decimal
local I  --flag, interrupt disable
local N  --flag, negative
local U  --flag, unused
local V  --flag, overflow
local Z  --flag, zero
local PC --program counter
local SP --stack pointer

local function Read(address)
  return 0;
end

local optable = {
  ["ADC"] = function(address) -- add with carry
              local a = A;
              local b = Read(address);
              A = a+b;
              if (C) then A = A + 1 end
              
              C = (A > 0xFF);
              
              if (C) then A = bit8.band(A, 0xFF) end
              
              V = bit8.band(bit8.bxor(a, b), 0x80) == 0x00 and bit8.band(bit8.bxor(a, A), 0x80) ~= 0x00; --TODO: revisit this with btest()
              Z = bit8.band(A, 0xFF) == 0x00;
              N = bit8.band(A, 0x80) ~= 0x00; 
            end, --61, 65, 69, 6D, 71, 75, 79, 7D
  ["AND"] = function(address) -- logical and
              A = bit8.band(A, Read(address));
              setZN(A);
            end, --21, 25, 29, 2D, 31, 35, 39, 3D
  ["ASL"] = function(address, mode) -- arithmetic shift left
              if mode == mode_Accumulator then do
                C = bit8.btest(A, 0x80);
                A = bit8.lshift(A, 1);
                Z = not bit8.btest(A, 0xFF);
                N = bit8.btest(A, 0x80);
              end else
                local a = Read(address);
                C = bit8.btest(A, 0x80);
                a = bit8.lshift(a, 1);
                Write(address, a);
                Z = not bi8.btest(a, 0xFF);
                N = bit8.btest(a, 0x80);
              end
            end, --06, 0A, 0E, 16, 1E
  ["BCC"] = function() end, --90
  ["BCS"] = function() end, --B0
  ["BEQ"] = function() end, --F0
  ["BIT"] = function() end, --24, 2C
  ["BMI"] = function() end, --30
  ["BNE"] = function() end, --D0
  ["BPL"] = function() end, --10
  ["BRK"] = function() end, --00
  ["BVC"] = function() end, --50
  ["BVS"] = function() end, --70
  ["CLC"] = function() end, --18
  ["CLD"] = function() end, --D8
  ["CLI"] = function() end, --58
  ["CLV"] = function() end, --B8
  ["CMP"] = function() end, --C1, C5, C9, CD, D1, D5, D9, DD
  ["CPX"] = function() end, --E0, E4, EC
  ["CPY"] = function() end, --C0, C4, CC
  ["DEC"] = function() end, --C6, CE, D6, DE
  ["DEX"] = function() end, --CA
  ["DEY"] = function() end, --88
  ["EOR"] = function() end, --41, 45, 49, 4D, 51, 55, 59, 5D
  ["INC"] = function() end, --E6, EE, F6, FE
  ["INX"] = function() end, --E8
  ["INY"] = function() end, --C8
  ["JMP"] = function() end, --4C, 6C
  ["JSR"] = function() end, --20
  ["LDA"] = function() end, --A1, A5, A9, AD, B1, B5, B9, BD
  ["LDX"] = function() end, --A2, A6, AE, B6, BE
  ["LDY"] = function() end, --A0, A4, AC, B4, BB
  ["LSR"] = function() end, --46, 4A, 4E, 56, 5E
  ["NOP"] = function() end, --04, 0C, 14, 1A, 1C, 34, 3A, 3C, 44, 54, 5A, 5C, 64, 74, 7A, 7C, 80, 82, 89, C2, D4, DA, DC, E2, EA, F4, FA, FC
  ["ORA"] = function() end, --01, 05, 09, 0D, 11, 15, 19, 1D
  ["PHA"] = function() end, --48
  ["PHP"] = function() end, --08
  ["PLA"] = function() end, --68
  ["PLP"] = function() end, --28
  ["ROL"] = function() end, --26, 2A, 2E, 36, 3E
  ["ROR"] = function() end, --66, 6A, 6E, 76, 7E
  ["RTI"] = function() end, --40
  ["RTS"] = function() end, --60
  ["SBC"] = function() end, --E1, E5, E9, EB, ED, F1, F5, F9, FD
  ["SEC"] = function() end, --38
  ["SED"] = function() end, --F8
  ["SEI"] = function() end, --78
  ["STA"] = function() end, --81, 85, 8D, 91, 95, 99, 9D
  ["STX"] = function() end, --8E, 96, 9E
  ["STY"] = function() end, --8C, 94, 9C
  ["TAS"] = function() end, --9B
  ["TAX"] = function() end, --AA
  ["TAY"] = function() end, --A8
  ["TSX"] = function() end, --BA
  ["TXA"] = function() end, --8A
  ["TXS"] = function() end, --9A
  ["TYA"] = function() end, --98
  
  ["AHX"] = function() end, --93, 9F, unofficial
  ["ALR"] = function() end, --4B, unofficial
  ["ANC"] = function() end, --0B, 2B, unofficial
  ["ARR"] = function() end, --6B, unofficial
  ["AXS"] = function() end, --CB, unofficial
  ["DCP"] = function() end, --C3, C7, CF, D3, D7, DB, DF, unofficial
  ["ISC"] = function() end, --E3, E7, EF, F3, F7, FB, FF, unofficial
  ["KIL"] = function() end, --02, 12, 22, 32, 42, 52, 62, 72, 92, B2, D2, F2, unofficial
  ["LAS"] = function() end, --BB, unofficial
  ["LAX"] = function() end, --A3, A7, AB, AF, B3, B7, BF, unofficial
  ["RLA"] = function() end, --23, 27, 2F, 33, 37, 3B, 3F, unofficial
  ["RRA"] = function() end, --63, 67, 6F, 73, 77, 7B, 7F, unofficial
  ["SAX"] = function() end, --8B, 8F, 97, 9F, unofficial
  ["SHX"] = function() end, --9E, unofficial
  ["SHY"] = function() end, --9C, unofficial
  ["SLO"] = function() end, --03, 07, 0F, 13, 17, 1B, 1F, unofficial
  ["SRE"] = function() end, --43, 47, 4F, 53, 57, 5B, 5F, unofficial
  ["XAA"] = function() end, --8B, unofficial
}

function start_cpu(inesMapper)
  Read = inesMapper.Read
  print("cpu started")
end