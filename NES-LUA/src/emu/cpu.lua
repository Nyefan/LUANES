-- Filename: emu.cpu.lua
-- Author: Nyefan
-- Contact: nyefancoding@gmail.com
-- This file handles emulation of the CPU (6602) on the RP2A03 (NTSC) and RP2A07 (PAL) MCs

-- Libraries
local bit8 = require "bit8"
local bit32 = require "bit32"

-- CPU management data
local Cycles = 0 --number of cycles that have been executed
local interruptModes = { none = 0,
                         nmi  = 1,
                         irq  = 2 }
local addressingMode = { accumulator = 0,
                         immediate   = 1,
                         zeroPage    = 2,
                         zeroPageX   = 3,
                         zeroPageY   = 4,
                         absolute    = 5,
                         absoluteX   = 6,
                         absoluteY   = 7,
                         implied     = 8,
                         relative    = 9,
                         indirectX   = 10,  --indexed indirect
                         indirectY   = 11,  --indirect indexed
                         indirectAbs = 12 } --absolute indexed
                         
                --0x0  0x1  0x2  0x3  0x4  0x5  0x6  0x7  0x8  0x9  0xA  0xB  0xC  0xD  0xE  0xF
local opModes = {  8,  10,   8,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0x00 
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6,  --0x10
                   5,  10,   8,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0x20
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6,  --0x30
                   8,  10,   8,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0x40
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6,  --0x50
                   8,  10,   8,  10,   2,   2,   2,   2,   8,   1,   0,   1,  11,   5,   5,   5,  --0x60
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6,  --0x70
                   1,  10,   1,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0x80
                   9,  12,   8,  12,   3,   3,   4,   4,   8,   7,   8,   7,   6,   6,   6,   6,  --0x90
                   1,  10,   1,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0xA0
                   9,  12,   8,  12,   3,   3,   4,   4,   8,   7,   8,   7,   6,   6,   6,   6,  --0xB0
                   1,  10,   1,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0xC0
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6,  --0xD0
                   1,  10,   1,  10,   2,   2,   2,   2,   8,   1,   0,   1,   5,   5,   5,   5,  --0xE0
                   9,  12,   8,  12,   3,   3,   3,   3,   8,   7,   8,   7,   6,   6,   6,   6 } --0xF0
                
                --0x0  0x1  0x2  0x3  0x4  0x5  0x6  0x7  0x8  0x9  0xA  0xB  0xC  0xD  0xE  0xF
local opCycles = { 7,   6,   2,   8,   3,   3,   5,   5,   3,   2,   2,   2,   4,   4,   6,   6,  --0x00
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7,  --0x10
                   6,   6,   2,   8,   3,   3,   5,   5,   4,   2,   2,   2,   4,   4,   6,   6,  --0x20
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7,  --0x30
                   6,   6,   2,   8,   3,   3,   5,   5,   3,   2,   2,   2,   3,   4,   6,   6,  --0x40
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7,  --0x50
                   6,   6,   2,   8,   3,   3,   5,   5,   4,   2,   2,   2,   5,   4,   6,   6,  --0x60
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7,  --0x70
                   2,   6,   2,   6,   3,   3,   3,   3,   2,   2,   2,   2,   4,   4,   4,   4,  --0x80
                   2,   6,   2,   6,   4,   4,   4,   4,   2,   5,   2,   5,   5,   5,   5,   5,  --0x90
                   2,   6,   2,   6,   3,   3,   3,   3,   2,   2,   2,   2,   4,   4,   4,   4,  --0xA0
                   2,   5,   2,   5,   4,   4,   4,   4,   2,   4,   2,   4,   4,   4,   4,   4,  --0xB0
                   2,   6,   2,   8,   3,   3,   5,   5,   2,   2,   2,   2,   4,   4,   6,   6,  --0xC0
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7,  --0xD0
                   2,   6,   2,   8,   3,   3,   5,   5,   2,   2,   2,   2,   4,   4,   6,   6,  --0xE0
                   2,   5,   2,   8,   4,   4,   6,   6,   2,   4,   2,   7,   4,   4,   7,   7 } --0xF0

-- CPU components
local A  --accumulator
local X  --register, X
local Y  --register, Y

local B  --flag, break
local C  --flag, carry
local D  --flag, decimal
local N  --flag, negative
local I  --flag, interrupt disable
local U  --flag, unused
local V  --flag, overflow
local Z  --flag, zero

local PC --program counter
local SP --stack pointer

local function Read(address)
  return 0;
end

local function Write(address, value)
  return 0;
end

local function HI(value)
  return bit32.extract(value, 8, 8)
end

local function LO(value)
  return bit32.band(value, 0xFF)
end

local function addBranchCycles(address)
  if (HI(address) == HI(PC)) then Cycles = Cycles + 1 end
  Cycles = Cycles + 1;
end

local function genericBranch(address)
    addBranchCycles(address);
    PC = address;
end



local opTable = {
  ["ADC"] = function(address) -- add memory to accumulator with carry
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
  ["AND"] = function(address) -- and memory with accumulator
              A = bit8.band(A, Read(address));
              setZN(A);
            end, --21, 25, 29, 2D, 31, 35, 39, 3D
  ["ASL"] = function(address, mode) -- arithmetic shift left
              if mode == addressingMode.accumulator then do
                C = bit8.btest(A, 0x80);
                A = bit8.lshift(A, 1);
                Z = not bit8.btest(A, 0xFF);
                N = bit8.btest(A, 0x80);
              end else
                local a = Read(address);
                C = bit8.btest(A, 0x80);
                a = bit8.lshift(a, 1);
                Write(address, a);
                Z = not bit8.btest(a, 0xFF);
                N = bit8.btest(a, 0x80);
              end
            end, --06, 0A, 0E, 16, 1E
  ["BCC"] = function(address) -- branch on carry clear
              if (not C) then genericBranch(address) end
            end, --90
  ["BCS"] = function(address) -- branch on carry set
              if (C) then genericBranch(address) end
            end, --B0
  ["BEQ"] = function(address) -- branch on result zero
              if (not Z) then genericBranch(address) end
            end, --F0
  ["BIT"] = function(address) -- test bits in memory with accumulator
              local temp = Read(address);
              V = bit8.btest(A, 0x40);
              Z = not bit8.btest(A, temp);
              N = bit8.btest(A, 0x80);
            end, --24, 2C
  ["BMI"] = function(address) -- branch on result negative
              if (not N) then genericBranch(address) end
            end, --30
  ["BNE"] = function(address) -- branch on result not zero
              if (Z) then genericBranch(address) end
            end, --D0
  ["BPL"] = function(address) -- branch on result positive
              if (not N) then genericBranch(address) end
            end, --10
  ["BRK"] = function(address, mode) -- force break
              --TODO: write this
            end, --00
  ["BVC"] = function() -- branch on overflow clear
              if (not V) then genericBranch(address) end
            end, --50
  ["BVS"] = function() -- branch on overflow set
              if (V) then genericBranch(address) end  
            end, --70
  ["CLC"] = function() -- clear carry flag
            
            end, --18
  ["CLD"] = function() -- clear decimal flag
            
            end, --D8
  ["CLI"] = function() -- clear interrupt disable flag
            
            end, --58
  ["CLV"] = function() -- clear overflow flag
            
            end, --B8
  ["CMP"] = function() -- compare memory and accumulator
            
            end, --C1, C5, C9, CD, D1, D5, D9, DD
  ["CPX"] = function() -- compare memory and register X
            
            end, --E0, E4, EC
  ["CPY"] = function() -- compare memory and register Y
            
            end, --C0, C4, CC
  ["DEC"] = function() -- decrement memory by 1
            
            end, --C6, CE, D6, DE
  ["DEX"] = function() -- decrement register X by 1
            
            end, --CA
  ["DEY"] = function() -- decrement register Y by 1
            
            end, --88
  ["EOR"] = function() -- xor memory with accumulator (store in accumulator)
            
            end, --41, 45, 49, 4D, 51, 55, 59, 5D
  ["INC"] = function() -- increment memory by 1
            
            end, --E6, EE, F6, FE
  ["INX"] = function() -- increment register X by 1
            
            end, --E8
  ["INY"] = function() -- increment register Y by 1
            
            end, --C8
  ["JMP"] = function() -- jump
            
            end, --4C, 6C
  ["JSR"] = function() -- jump, saving return address
            
            end, --20
  ["LDA"] = function() -- load accumulator with memory
            
            end, --A1, A5, A9, AD, B1, B5, B9, BD
  ["LDX"] = function() -- load register X with memory
            
            end, --A2, A6, AE, B6, BE
  ["LDY"] = function() -- load register Y with memory
            
            end, --A0, A4, AC, B4, BB
  ["LSR"] = function() -- logical shift right
            
            end, --46, 4A, 4E, 56, 5E
  ["NOP"] = function() -- no op (two cycles)
            
            end, --04, 0C, 14, 1A, 1C, 34, 3A, 3C, 44, 54, 5A, 5C, 64, 74, 7A, 7C, 80, 82, 89, C2, D4, DA, DC, E2, EA, F4, FA, FC
  ["ORA"] = function() -- or accumulator with memory
            
            end, --01, 05, 09, 0D, 11, 15, 19, 1D
  ["PHA"] = function() -- push accumulator to stack
            
            end, --48
  ["PHP"] = function() -- push PC to stack
            
            end, --08
  ["PLA"] = function() -- pull accumulator from stack
            
            end, --68
  ["PLP"] = function() -- pull PC from stack
            
            end, --28
  ["ROL"] = function() -- rotate left (memory or accumulator)
            
            end, --26, 2A, 2E, 36, 3E
  ["ROR"] = function() -- rotate right (memory of accumulator)
            
            end, --66, 6A, 6E, 76, 7E
  ["RTI"] = function() -- return from interrupt
            
            end, --40
  ["RTS"] = function() -- return from subroutine
            
            end, --60
  ["SBC"] = function() -- subtract memory from accumulator with borrow
            
            end, --E1, E5, E9, EB, ED, F1, F5, F9, FD
  ["SEC"] = function() -- set carry flag
            
            end, --38
  ["SED"] = function() -- set decimal flag
            
            end, --F8
  ["SEI"] = function() -- set interrupt disable flag
            
            end, --78
  ["STA"] = function() -- store accumulator in memory
            
            end, --81, 85, 8D, 91, 95, 99, 9D
  ["STX"] = function() -- store register X in memory
            
            end, --8E, 96, 9E
  ["STY"] = function() -- store register Y in memory
            
            end, --8C, 94, 9C
  ["TAS"] = function() -- transfer accumulator to stack pointer
            
            end, --9B
  ["TAX"] = function() -- transfer accumulator to register X
            
            end, --AA
  ["TAY"] = function() -- transfer accumulator to register Y
            
            end, --A8
  ["TSX"] = function() -- transfer stack pointer to register X
            
            end, --BA
  ["TXA"] = function() -- transfer register X to accumulator
            
            end, --8A
  ["TXS"] = function() -- transfer register X to stack pointer
            
            end, --9A
  ["TYA"] = function() -- transfer register Y to accumulator
            
            end, --98
            
            
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
  Write = inesMapper.Write
  print("cpu started")
end