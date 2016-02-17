-- Filename: emu.cpu.lua
-- Author: Nyefan
-- Contact: nyefancoding@gmail.com
-- This file handles emulation of the CPU (6602) on the RP2A03 (NTSC) and RP2A07 (PAL) MCs

-- Libraries
local bit8 = require "bit8"
local bit32 = require "bit32"

-- CPU management data
local Cycles = 0 --number of cycles that have been executed
local interrupt = 0
local stall = 0
local frequency = 1789773
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
                  
                 --0x0    0x1    0x2    0x3    0x4    0x5    0x6    0x7    0x8    0x9    0xA    0xB    0xC    0xD    0xE    0xF
local opCodes = { "BRK", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO", "PHP", "ORA", "ASL", "ANC", "NOP", "ORA", "ASL", "SLO",  --0x00
                  "BPL", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO", "CLC", "ORA", "NOP", "SLO", "NOP", "ORA", "ASL", "SLO",  --0x10
                  "JSR", "AND", "KIL", "RLA", "BIT", "AND", "ROL", "RLA", "PLP", "AND", "ROL", "ANC", "BIT", "AND", "ROL", "RLA",  --0x20
                  "BMI", "AND", "KIL", "RLA", "NOP", "AND", "ROL", "RLA", "SEC", "AND", "NOP", "RLA", "NOP", "AND", "ROL", "RLA",  --0x30
                  "RTI", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE", "PHA", "EOR", "LSR", "ALR", "JMP", "EOR", "LSR", "SRE",  --0x40
                  "BVC", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE", "CLI", "EOR", "NOP", "SRE", "NOP", "EOR", "LSR", "SRE",  --0x50
                  "RTS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA", "PLA", "ADC", "ROR", "ARR", "JMP", "ADC", "ROR", "RRA",  --0x60
                  "BVS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA", "SEI", "ADC", "NOP", "RRA", "NOP", "ADC", "ROR", "RRA",  --0x70
                  "NOP", "STA", "NOP", "SAX", "STY", "STA", "STX", "SAX", "DEY", "NOP", "TXA", "XAA", "STY", "STA", "STX", "SAX",  --0x80
                  "BCC", "STA", "KIL", "AHX", "STY", "STA", "STX", "SAX", "TYA", "STA", "TXS", "TAS", "SHY", "STA", "SHX", "AHX",  --0x90
                  "LDY", "LDA", "LDX", "LAX", "LDY", "LDA", "LDX", "LAX", "TAY", "LDA", "TAX", "LAX", "LDY", "LDA", "LDX", "LAX",  --0xA0
                  "BCS", "LDA", "KIL", "LAX", "LDY", "LDA", "LDX", "LAX", "CLV", "LDA", "TSX", "LAS", "LDY", "LDA", "LDX", "LAX",  --0xB0
                  "CPY", "CMP", "NOP", "DCP", "CPY", "CMP", "DEC", "DCP", "INY", "CMP", "DEX", "AXS", "CPY", "CMP", "DEC", "DCP",  --0xC0
                  "BNE", "CMP", "KIL", "DCP", "NOP", "CMP", "DEC", "DCP", "CLD", "CMP", "NOP", "DCP", "NOP", "CMP", "DEC", "DCP",  --0xD0
                  "CPX", "SBC", "NOP", "ISC", "CPX", "SBC", "INC", "ISC", "INX", "SBC", "NOP", "SBC", "CPX", "SBC", "INC", "ISC",  --0xE0
                  "BEQ", "SBC", "KIL", "ISC", "NOP", "SBC", "INC", "ISC", "SED", "SBC", "NOP", "ISC", "NOP", "SBC", "INC", "ISC" } --0xF0
                  
                         
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

                --0x0  0x1  0x2  0x3  0x4  0x5  0x6  0x7  0x8  0x9  0xA  0xB  0xC  0xD  0xE  0xF
local opSizes  = { 1,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0x00
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0x10
                   3,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0x20
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0x30
                   1,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0x40
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0x50
                   1,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0x60
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0x70
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   0,   1,   0,   3,   3,   3,   0,  --0x80
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   0,   3,   0,   0,  --0x90
                   2,   2,   2,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0xA0
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0xB0
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0xC0
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0,  --0xD0
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   2,   1,   0,   3,   3,   3,   0,  --0xE0
                   2,   2,   0,   0,   2,   2,   2,   0,   1,   3,   1,   0,   3,   3,   3,   0 } --0xF0

                --0x0  0x1  0x2  0x3  0x4  0x5  0x6  0x7  0x8  0x9  0xA  0xB  0xC  0xD  0xE  0xF
local opPCycles= { 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x00
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0,  --0x10
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x20
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0,  --0x30
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x40
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0,  --0x50
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x60
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0,  --0x70
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x80
                   1,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0x90
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0xA0
                   1,   1,   0,   1,   0,   0,   0,   0,   0,   1,   0,   1,   1,   1,   1,   1,  --0xB0
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0xC0
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0,  --0xD0
                   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,  --0xE0
                   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   1,   0,   0 } --0xF0


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

local function HI(value)
  return bit32.extract(value, 8, 8);
end

local function LO(value)
  return bit32.band(value, 0xFF);
end

local function HILO(hi, lo)
  bit32.band(bit32.bor(bit32.lshift(hi, 8), lo), 0xFFFF);
end

local function addBranchCycles(address)
  if (HI(address) == HI(PC)) then Cycles = Cycles + 1 end
  Cycles = Cycles + 1;
end

local function genericBranch(address)
  addBranchCycles(address);
  PC = address;
end

local function bool2bin(bool)
  if(bool) then return 0x01 else return 0x00 end
end

local function Read(address)
  return 0;
end

local function Read16(address)
  local lo = Read(address)
  local hi = Read(address+1)
  return HILO(hi, lo);
end

local function Read16Bug(address)
  local lo = Read(address)
  local hi = Read(HILO(HI(address), LO(address+1)))
  return HILO(hi, lo);
end

local function Write(address, value)
  return 0;
end

local function Push(value)
  Write(bit8.bor(0x0100, SP), value)
end

local function Push16(value)
  Push(HI(value))
  Push(LO(value))
end

local function Pull()
  SP = SP + 1
  return Read(bit8.bor(0x100, SP))
end

local function Pull16()
  local lo = Pull()
  local hi = Pull()
  return HILO(hi, lo);
end

local function triggerNMI()
  interrupt = interruptModes.nmi
end

local function triggerIRQ()
  interrupt = interruptModes.irq
end

local function setZ(value)
  Z = not bit8.btest(value, 0xFF);
end

local function setN(value)
  N = bit8.btest(A, 0x80);
end

local function setFlagsByHex(value)
  C = bit8.btest(value, 0x01);
  Z = bit8.btest(value, 0x02);
  I = bit8.btest(value, 0x04);
  D = bit8.btest(value, 0x08);
  B = bit8.btest(value, 0x10);
  U = bit8.btest(value, 0x20);
  V = bit8.btest(value, 0x40);
  N = bit8.btest(value, 0x80);
end

local function setFlags(C, Z, I, D, B, U, V, N)
  C = C;
  Z = Z;
  I = I;
  D = D;
  B = B;
  U = U;
  V = V;
  N = N;
end

local function getFlags()
  return bit8.bor(bit8.lshift(C, 0),
                  bit8.lshift(Z, 1),
                  bit8.lshift(I, 2),
                  bit8.lshift(D, 3),
                  bit8.lshift(B, 4),
                  bit8.lshift(U, 5),
                  bit8.lshift(V, 6),
                  bit8.lshift(N, 7))
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
              setZ(A); setN(A); 
            end, --61, 65, 69, 6D, 71, 75, 79, 7D
  ["AND"] = function(address) -- and memory with accumulator
              A = bit8.band(A, Read(address));
              setZ(A); setN(A);
            end, --21, 25, 29, 2D, 31, 35, 39, 3D
  ["ASL"] = function(address, mode) -- arithmetic shift left
              if mode == addressingMode.accumulator then do
                C = bit8.btest(A, 0x80);
                A = bit8.lshift(A, 1);
                setZ(A); setN(A);
              end else
                local temp = Read(address);
                C = bit8.btest(A, 0x80);
                temp = bit8.lshift(temp, 1);
                Write(address, temp);
                setZ(temp); setN(temp);
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
              setZ(bit8.btest(A, temp)); setN(temp);
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
              Push16(PC);
              Push(bit8.bor(getFlags(), 0x10)); --PHP()
              I = true; --SEI()
              PC = Read16(0xFFFE);
            end, --00
  ["BVC"] = function(address) -- branch on overflow clear
              if (not V) then genericBranch(address) end
            end, --50
  ["BVS"] = function(address) -- branch on overflow set
              if (V) then genericBranch(address) end  
            end, --70
  ["CLC"] = function() -- clear carry flag
              C = false;
            end, --18
  ["CLD"] = function() -- clear decimal flag
              D = false;
            end, --D8
  ["CLI"] = function() -- clear interrupt disable flag
              I = false;
            end, --58
  ["CLV"] = function() -- clear overflow flag
              V = false;
            end, --B8
  ["CMP"] = function(address) -- compare memory and accumulator
              C = A >= Read(address);
            end, --C1, C5, C9, CD, D1, D5, D9, DD
  ["CPX"] = function(address) -- compare memory and register X
              C = X >= Read(address);
            end, --E0, E4, EC
  ["CPY"] = function(address) -- compare memory and register Y
              C = Y >= Read(address);
            end, --C0, C4, CC
  ["DEC"] = function(address) -- decrement memory by 1
              local temp = bit8.band(Read(address) - 1, 0xFF);
              Write(address, temp);
              setZ(temp); setN(temp);
            end, --C6, CE, D6, DE
  ["DEX"] = function() -- decrement register X by 1
              X = bit8.band(X - 1, 0xFF);
              setZ(X); setN(X);
            end, --CA
  ["DEY"] = function() -- decrement register Y by 1
              Y = bit8.band(Y - 1, 0xFF);
              setZ(Y); setN(Y);
            end, --88
  ["EOR"] = function(address) -- xor memory with accumulator (store in accumulator)
              A = bit8.bxor(A, Read(address));
              setZ(A); setN(A);
            end, --41, 45, 49, 4D, 51, 55, 59, 5D
  ["INC"] = function(address) -- increment memory by 1
              local temp = bit8.band(Read(address) + 1, 0xFF);
              Write(address, temp);
              setZ(temp); setN(temp);
            end, --E6, EE, F6, FE
  ["INX"] = function() -- increment register X by 1
              X = bit8.band(X + 1, 0xFF);
              setZ(X); setN(X);
            end, --E8
  ["INY"] = function() -- increment register Y by 1
              Y = bit8.band(Y - 1, 0xFF);
              setZ(Y); setN(Y);
            end, --C8
  ["JMP"] = function(address) -- jump
              PC = address
            end, --4C, 6C
  ["JSR"] = function(address) -- jump, saving return address
              Push16(PC-1);
              PC = address;
            end, --20
  ["LDA"] = function(address) -- load accumulator with memory
              A = Read(address);
              setZ(A); setN(A);
            end, --A1, A5, A9, AD, B1, B5, B9, BD
  ["LDX"] = function(address) -- load register X with memory
              X = Read(address);
              setZ(X); setN(X);
            end, --A2, A6, AE, B6, BE
  ["LDY"] = function(address) -- load register Y with memory
              Y = Read(address);
              setZ(Y); setN(Y);
            end, --A0, A4, AC, B4, BB
  ["LSR"] = function(address, mode) -- logical shift right
              if mode == addressingMode.accumulator then do
                C = bit8.btest(A, 0x01);
                A = bit8.rshift(A, 1);
                setZ(A); setN(A);
              end else
                local temp = Read(address);
                C = bit8.btest(temp, 0x01);
                temp = bit8.rshift(temp, 1);
                Write(address, temp);
                setZ(temp); setN(temp);
              end
            end, --46, 4A, 4E, 56, 5E
  ["NOP"] = function() -- no op (two cycles)
              -- do nothing
            end, --04, 0C, 14, 1A, 1C, 34, 3A, 3C, 44, 54, 5A, 5C, 64, 74, 7A, 7C, 80, 82, 89, C2, D4, DA, DC, E2, EA, F4, FA, FC
  ["ORA"] = function(address) -- or accumulator with memory
              A = bit8.bor(A, Read(address));
              setZ(A); setN(A);
            end, --01, 05, 09, 0D, 11, 15, 19, 1D
  ["PHA"] = function() -- push accumulator to stack
              Push(A);
            end, --48
  ["PHP"] = function() -- push PC to stack
              Push(bit8.bor(getFlags(), 0x10));
            end, --08
  ["PLA"] = function() -- pull accumulator from stack
              A = Pull();
              setZ(A); setN(A);
            end, --68
  ["PLP"] = function() -- pull PC from stack
              setFlagsByHex(bit8.bor(bit8.band(Pull(), 0xEF), 0x20));
            end, --28
  ["ROL"] = function(address, mode) -- rotate left (memory or accumulator)
              if mode == addressingMode.accumulator then do
                local tempC = C;
                C = bit8.btest(A, 0x80);
                A = bit8.bor(bit8.lshift(A, 1), bool2bin(tempC)); --TODO: figure out a way to remove bool2bin()
                setZ(A); setN(A);
              end else
                local temp = Read(address);
                local tempC = C;
                C = bit8.btest(temp, 0x80);
                temp = bit8.bor(bit8.lshift(temp, 1), bool2bin(tempC)); --TODO: figure out a way to remove bool2bin()
                Write(address, temp);
                setZ(temp); setN(temp);
              end
            end, --26, 2A, 2E, 36, 3E
  ["ROR"] = function(address, mode) -- rotate right (memory of accumulator)
              if mode == addressingMode.accumulator then do
                local tempC = C;
                C = bit8.btest(A, 0x01);
                A = bit8.bor(bit8.rshift(A, 1), bit8.lshift(bool2bin(tempC)));
                setZ(A); setN(A);
              end else
                local temp = Read(address);
                local tempC = C;
                C = bit8.btest(temp, 0x01);
                temp = bit8.bor(bit8.rshift(temp, 1), bit8.lsfhift(bool2bin(tempC)));
                Write(address, temp);
                setZ(temp); setN(temp);
              end
            end, --66, 6A, 6E, 76, 7E
  ["RTI"] = function() -- return from interrupt
              setFlagsByHex(bit8.bor(bit8.band(Pull(), 0xEF), 0x20));
            end, --40
  ["RTS"] = function() -- return from subroutine
              PC = Pull16+1
            end, --60
            --TODO: ensure this handles overflow properly
  ["SBC"] = function(address) -- subtract memory from accumulator with borrow
              local tempA = A;
              local tempB = Read(address);
              
              A = tempA - tempB;
              if (not C) then A = A - 1 end
              
              C = (A >= 0x00);
              
              if (C) then A = bit8.band(A, 0xFF) end
              
              V = bit8.btest(bit8.bxor(tempA, tempB), 0x80) and bit8.test(bit8.bxor(tempA, A), 0x80);
              
              setZ(A); setN(A); 
              
            end, --E1, E5, E9, EB, ED, F1, F5, F9, FD
  ["SEC"] = function() -- set carry flag
              C = true;
            end, --38
  ["SED"] = function() -- set decimal flag
              D = true;
            end, --F8
  ["SEI"] = function() -- set interrupt disable flag
              I = true
            end, --78
  ["STA"] = function(address) -- store accumulator in memory
              Write(address, A)
            end, --81, 85, 8D, 91, 95, 99, 9D
  ["STX"] = function(address) -- store register X in memory
              Write(address, X)
            end, --8E, 96, 9E
  ["STY"] = function(address) -- store register Y in memory
              Write(address, Y)
            end, --8C, 94, 9C

  ["TAX"] = function() -- transfer accumulator to register X
              X = A;
              setZ(X); setN(X);
            end, --AA
  ["TAY"] = function() -- transfer accumulator to register Y
              Y = A;
              setZ(Y); setN(Y);
            end, --A8
  ["TSX"] = function() -- transfer stack pointer to register X
              X = SP;
              setZ(X); setN(X);
            end, --BA
  ["TXA"] = function() -- transfer register X to accumulator
              A = X;
              setZ(A); setN(A);
            end, --8A
  ["TXS"] = function() -- transfer register X to stack pointer
              SP = X;
            end, --9A
  ["TYA"] = function() -- transfer register Y to accumulator
              A = Y;
              setZ(A); setN(A);
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
  ["TAS"] = function() end, --9B, unofficial
  ["XAA"] = function() end, --8B, unofficial
}

local function NMI()
  Push16(PC)
  opTable.PHP(nil)
  PC = Read16(0xFFFA)
  I = 1
  Cycles = Cycles + 7
end

local function IRQ()
  Push16(PC)
  opTable.PHP(nil)
  PC = Read16(0xFFFE)
  I = 1
  Cycles = Cycles + 7
end

local interruptFuncs = {
  function() end,
  NMI(),
  IRQ()
}

local addressingFuncs = {
  function() return 0; end,                       --accumulator
  function() return PC+1; end,                    --immediate
  function() return Read(PC+1); end,              --zeroPage
  function() return Read(PC+1)+X; end,            --zeroPageX
  function() return Read(PC+1)+Y; end,            --zeroPageY
  function() return Read16(PC+1); end,            --absolute
  function()                                      --absoluteX
    local adr = Read16(PC+1)+X
    return adr, HI(adr-X)~=HI(adr);
  end,
  function()                                      --absoluteY
    local adr = Read16(PC+1)+Y
    return adr, HI(adr-Y)~=HI(adr);
  end,
  function() return 0; end,                       --implied
  function()                                      --relative
    local offset = Read(PC+1)
    if (offset < 0x80) then return PC+2+offset;
      else return PC+2+offset-0x100; end
  end,
  function() return Read16Bug(Read(PC+1)+X) end,  --indirectX (indexedIndirect)
  function()                                      --indirectY (indirectIndexed)
    local adr = Read16Bug(Read(PC+1)+Y)
    return adr, HI(adr-Y)~=HI(adr);
  end,
  function() return Read16Bug(Read16(PC+1)); end  --indirectAbsolute
}

local function start_cpu(inesMapper)
  Read = inesMapper.Read
  Write = inesMapper.Write
  print("cpu started")
end

local function reset_cpu()
  PC = Read16(0xFFFC)
  SP = 0xFD
  setFlagsByHex(0x24) --equivalent to setFlags(0,0,0,1,1,0,0,0)
end

local function step_cpu()
  if (stall > 0) then
    stall = stall - 1
    return 1
  end

  local cycles = Cycles

  interruptFuncs[interrupt]()
  interrupt = interruptModes.none

  local opcode = Read(PC)
  local address, pageCrossed = addressingFuncs[opModes[opcode]]()

  PC = PC + opSizes[opcode]
  Cycles = Cycles + opCycles[opcode]
  if(pageCrossed) then Cycles = Cycles + opPCycles[opcode] end

  opTable.opCodes[opcode](address, opModes[opcode])

  return Cycles-cycles;

end