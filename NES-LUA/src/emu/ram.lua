function start_ram()
  print("ram started")
end

local __RAM = {}

local function setVal(location, value) 
  __RAM[location] = value;
end

local function getVal(location)
  return __RAM[location] or 0;
end

local function setBlock(location, ...)
  for i, v in ipairs({...}) do __RAM[location+i-1] = v end;
end

local function getBlock(location, length)
  local temp = {};
  for i = location, location+length do temp[i-location] = __RAM[i] or 0 end;
  return temp;
end

-- probably useless
local function cleanRam()
  for i, v in ipairs(__RAM) do if v == 0 then __RAM[i] = nil end end;
end

return { setVal = setVal,
         getVal = getVal,
         setBlock = setBlock,
         getBlock = getBlock }

--[[
-- TEST CODE
local function pass(passfunc, test)
  if passfunc() then 
    do print(test .. "passed") end
  else 
    do print(test .. "failed") end
  end
end

local function runTest()
  setVal(50, 50);
  setBlock(51, 1, 2, 3, 4, 5);
  
  pass(function() return getVal(50) == 50 end, 
       "    setVal->getVal\t");
  
  pass(function() for i = 0,4 do 
                    if getVal(i+51) ~= i+1 then return false end 
                  end 
                  return true 
       end, 
       "  setBlock->getVal\t");
       
  pass(function() return getBlock(50, 1)[0] == 50 end, 
       "  setVal->getBlock\t");
  
  pass(function() temp = getBlock(50, 6) 
                  comp = {50, 1, 2, 3, 4, 5} 
                  for i = 0,5 do 
                    if temp[i] ~= comp[i+1] then return false end 
                  end 
                  return true 
       end, 
       "setBlock->getBlock\t");
  
  pass(function() return getVal(49) == 0 end,
       "      getVal (nil)\t");
  
  pass(function() temp = getBlock(49, 3)
                  comp = {0, 50, 1}
                  for i = 0,2 do
                    if temp[i] ~= comp[i+1] then return false end
                  end
                  return true
       end,
       "getBlock (nil&val)\t");
end

runTest()
--]]