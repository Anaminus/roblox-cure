
if _VERSION == "Lua 5.2" then
  unpack = table.unpack
end

local lfs = require "lfs"

-- Array of alternative paths to output the contents of the model.
local LOCATIONS = {
  -- "output.rbxmx",
  -- "test/game.rbxmx"
}

-- Where source code is stored and compiled to
local SOURCE_DIR = "source"
local BUILD_DIR  = "build/"

--[[
  The name and extension of the Model file that will be generated.

  [1] Roblox only supports two extensions: rbxm and rbxmx. The former uses
      binary while the latter uses XML. Because this build only compiles to
      XML, the rbxmx file extension is prefered.
--]]
local RBXM_FILE_NAME = "cure"
local RBXM_FILE_EXT  = ".rbxmx" -- [1]
local RBXM_FILE = RBXM_FILE_NAME..RBXM_FILE_EXT

-- The instance that will be used to replicate the folder structure. Any
-- instance can be used, but Folders are recommended.
local CONTAINER_CLASS = "Folder"

-- maximum length of strings in replicated instances
local MAX_STRING_LENGTH = 200000 - 1





--[[
  Helpers
  ==============================================================================
--]]

function isDir(dir)
  return lfs.attributes(dir, "mode") == "directory"
end

local function splitName(path)
  for i = #path, 1, -1 do
    local c = path:sub(i, i)
    if c == "." then
      return path:sub(1, i-1), path:sub(i+1, #path)
    end
  end
  return path, ""
end

-- Extract the contents of a file
local function getFileContents(path)
  local file = assert(io.open(path))
  local content = file:read("*a")
  file:close()

  return content
end





--[[
  XML
  ==============================================================================
--]]

local xml = {}

-- because of the way XML is parsed, leading spaces get truncated
-- so, simply add a "\" when a space or "\" is detected as the first character
-- this will be decoded automatically by Cure
function xml.encodeTruncEsc(str)
  local first = str:sub(1,1)
  if first:match("%s") or first == [[\]] then
    return [[\]] .. str
  end
  return str
end

function xml.escape(str)
  local nameEsc = {
    ["\""] = "quot";
    ["&"] = "amp";
    ["'"] = "apos";
    ["<"] = "lt";
    [">"] = "gt";
  }
  local out = ""
  for i = 1, #str do
    local c = str:sub(i,i)
    if nameEsc[c] then
      c = "&" .. nameEsc[c] .. ";"
    elseif not c:match("^[\10\13\32-\126]$") then
      c = "&#" .. c:byte() .. ";"
    end
    out = out .. c
  end
  return out
end





--[[
  Data Types
  ==============================================================================
--]]

local encodeDataType = {}

function encodeDataType.string(data)
  return xml.encodeTruncEsc(xml.escape(data))
end

function encodeDataType.ProtectedString(data)
  return xml.encodeTruncEsc(xml.escape(data))
end

function encodeDataType.CoordinateFrame(data, tab)
  local d = { data:components() }
  return {
    "\n", tab( 1), [[<X>]],   d[1],  [[</X>]];
    "\n", tab(  ), [[<Y>]],   d[2],  [[</Y>]];
    "\n", tab(  ), [[<Z>]],   d[3],  [[</Z>]];
    "\n", tab(  ), [[<R00>]], d[4],  [[</R00>]];
    "\n", tab(  ), [[<R01>]], d[5],  [[</R01>]];
    "\n", tab(  ), [[<R02>]], d[6],  [[</R02>]];
    "\n", tab(  ), [[<R10>]], d[7],  [[</R10>]];
    "\n", tab(  ), [[<R11>]], d[8],  [[</R11>]];
    "\n", tab(  ), [[<R12>]], d[9],  [[</R12>]];
    "\n", tab(  ), [[<R20>]], d[10], [[</R20>]];
    "\n", tab(  ), [[<R21>]], d[11], [[</R21>]];
    "\n", tab(  ), [[<R22>]], d[12], [[</R22>]];
    "\n", tab(-1);
  }
end

function encodeDataType.Color3(data)
  return tonumber(string.format("0xFF%02X%02X%02X", data.r*255, data.g*255, data.b*255))
end

function encodeDataType.Content(data)
  if #data == 0 then
    return [[<null></null>]]
  else
    return {[[<url>]],data,[[</url>]]}
  end
end

function encodeDataType.Ray(data, tab)
  local o = data.Origin
  local d = data.Direction
  return {
    "\n", tab( 1), [[<origin>]];
    "\n", tab( 1), [[<X>]], o.x, [[</X>]];
    "\n", tab(  ), [[<Y>]], o.y, [[</Y>]];
    "\n", tab(  ), [[<Z>]], o.z, [[</Z>]];
    "\n", tab(-1), [[</origin>]];
    "\n", tab(  ), [[<direction>]];
    "\n", tab( 1), [[<X>]], d.x, [[</x>]];
    "\n", tab(  ), [[<Y>]], d.y, [[</Y>]];
    "\n", tab(  ), [[<Z>]], d.z, [[</Z>]];
    "\n", tab(-1), [[</direction>]];
    "\n"; tab(-1);
  }
end

function encodeDataType.Vector3(data, tab)
  return {
    "\n", tab( 1), [[<X>]], data.x, [[</X>]];
    "\n", tab(  ), [[<Y>]], data.y, [[</Y>]];
    "\n", tab( 0), [[<Z>]], data.z, [[</Z>]];
    "\n"; tab(-1);
  }
end

function encodeDataType.Vector2(data, tab)
  return {
    "\n", tab( 1), [[<X>]], data.x, [[</X>]];
    "\n", tab( 0), [[<Y>]], data.y, [[</Y>]];
    "\n"; tab(-1);
  }
end

function encodeDataType.UDim2(data, tab)
  return {
    "\n", tab( 1), [[<XS>]], data.X.Scale,  [[</XS>]];
    "\n", tab(  ), [[<XO>]], data.X.Offset, [[</XO>]];
    "\n", tab(  ), [[<YS>]], data.Y.Scale,  [[</YS>]];
    "\n", tab( 0), [[<YO>]], data.Y.Offset, [[</YO>]];
    "\n"; tab(-1);
  }
end

function encodeDataType.Ref(data)
  if data == nil then
    return "null"
  else
    return data
  end
end

function encodeDataType.double(data)
  return string.format("%f",data)
end

function encodeDataType.int(data)
  return string.format("%i",data)
end

function encodeDataType.bool(data)
  return not not data
end





--[[
  Roblox Models
  ==============================================================================
--]]

local rbxm = {}

function rbxm:createValue(className, name, value)
  return {
    ClassName = className .. "Value",
    Name = { "string", name },
    Value = { className:lower(), value }
  }
end

-- Generate a new Script instance. Wrappers for this method are found below it.
function rbxm:createScript(className, name, source, disabled)
  local obj = {
    ClassName = className;
    Name = { "string", name };
    Source = { "ProtectedString", source };
  }

  if disabled then
    obj.Disabled = { "bool", true };
  end

  return obj
end

function rbxm:createServerScript(name, source, disabled)
  return self:createScript("Script", name, source, disabled)
end

function rbxm:createLocalScript(name, source, disabled)
  return self:createScript("LocalScript", name, source, disabled)
end

-- Create a value containing an asset's ID.
function rbxm:createAsset(name, value)
  content = tonumber(content)

  if not content then
    print("WARNING: content of `" .. file .. "` must be a number")
  end

  return createValue("Int", name, content)
end

-- Split apart the contents of the file into multiple StringValues, contained
-- inside a BoolValue
function rbxm:splitFileParts(length, chunk, content)
  local container = rbxm:createValue("Bool", name, true)

  for i = 1, math.ceil(length/chunk) do
    local a = (i - 1)*chunk + 1
    local b = a + chunk - 1
    b = b > length and length or b
    container[i] = rbxm:createValue("String", tostring(i), content:sub(a, b))
  end

  return container
end

function rbxm:checkScriptSyntax(source)
  -- If it's a script, you want to make sure it can compile!
  local func, err = loadstring(source, "")
  if not func then
    print("WARNING: " .. err:gsub("^%[.-%]:", "line "))
  end
end

-- Converts a RBXM table to a string.
function rbxm:tabToStr(var)
  if type(var) ~= "table" then
    error("table expected", 2)
  end

  local contentString = {}
  local function output(...)
    local args = {...}
    for i = 1, #args do
      if type(args[i]) == "table" then
        output(unpack(args[i]))
      else
        contentString[#contentString+1] = tostring(args[i])
      end
    end
  end

  local tab do
    local t = 1
    function tab(n)
      if n then t = t + n end
      return string.rep("\t", t)
    end
  end

  local ref = 0
  local function r(object)
    output("\n", tab(), [[<Item class="]], object.ClassName, [[" referent="RBX]], ref, [[">]], "\n", tab(1), [[<Properties>]])
    ref = ref + 1

    local sorted = {}
    for k in pairs(object) do
      if type(k) == "string" and k ~= "ClassName" then
        sorted[#sorted+1] = k
      end
    end
    table.sort(sorted)
    tab(1)
    for i = 1, #sorted do
      local propName = sorted[i]
      local propType, propValue = object[propName][1], object[propName][2]

      if encodeDataType[propType] then
        propValue = encodeDataType[propType](propValue, tab)
      end

      output("\n", tab(), [[<]], propType, [[ name="]], propName, [[">]], propValue, [[</]], propType, [[>]])
    end
    output("\n", tab(-1), [[</Properties>]])

    for i = 1, #object do
      r(object[i])
    end

    output("\n", tab(-1), [[</Item>]])
  end

  output(
    [[<roblox ]],
    [[xmlns:xmime="http://www.w3.org/2005/05/xmlmime" ]],
    [[xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ]],
    [[xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" ]],
    [[version="4">]]
  )
  r(var)
  output("\n</roblox>")
  return table.concat(contentString)
end

-- Saves an RBXM string or table.
function rbxm:save(var, filename)
  if type(var) == "table" then
    var = self:tabToStr(var)
  end
  if type(var) == "string" then
    local file = assert(io.open(filename, "w"))
    file:write(var)
    file:flush()
    file:close()
  else
    error("bad type", 2)
  end
end





--[[
  Cure
  ==============================================================================
--]]

local cure = {}

function cure:server(content)
  return rbxm:createServerScript("cure.server", content)
end

function cure:client(content)
  return rbxm:createLocalScript("cure.client", content)
end





--[[
  Compiling
  ==============================================================================
--]]

local function handleFile(path, file, subfolder)
  local content = getFileContents(path)
  local name, extension = splitName(file)
  local subName, subExtension = splitName(name)

  extension = extension:lower()
  subExtension = subExtension:lower()

  -- Special handling for the main Cure scripts
  if not subfolder then
    rbxm:checkScriptSyntax(content)

    if file:lower() == "cure.server.lua" then
      return cure:server(content)
    elseif file:lower() == "cure.client.lua" then
      return cure:client(content)
    end
  end

  if extension == "lua" then
    rbxm:checkScriptSyntax(content)

    if subExtension == "script" then
      return rbxm:createServerScript(subName, content)
    elseif subExtension == "localscript" then
      return rbxm:createLocalScript(subName, content)
    else
      local chunk = MAX_STRING_LENGTH
      local length = #content

      if length <= chunk then
        -- Create a StringValue to hold the source of the file
        return rbxm:createValue("String", name, content)
      else
        -- If the file is too big, split it into multiple parts
        return rbxm:splitFileParts(length, chunk, content)
      end
    end
  elseif ext == "asset" then
    -- Create an IntValue containing a Roblox AssetID
    return rbxm:createAsset(name, content)
  else
    -- Disable and comment out anything else
    return rbxm:createServerScript(name, "--[==[\n"..content.."\n--]==]", true)
  end
end

local function recurseDir(path, obj, r)
  print("DIR", path)

  for name in lfs.dir(path) do
    if name ~= ".." and name ~= "." and name ~= ".gitignore" then
      local joinedPath = path .. "/" .. name

      if isDir(joinedPath) then
        obj[#obj+1] = recurseDir(joinedPath, {
          ClassName = CONTAINER_CLASS,
          Name = { "string", name }
        }, true)
      else
        print("FILE", joinedPath)
        obj[#obj+1] = handleFile(joinedPath, name, r)
      end
    end
  end

  return obj
end

function compile(args)
  local rbxmObj = recurseDir(SOURCE_DIR, {
    ClassName = CONTAINER_CLASS,
    Name = { "string", "cure" }
  })

  local rbxmPath = BUILD_DIR.."/"..(unpack(args) or RBXM_FILE)

  -- Make sure the output directory exists
  lfs.mkdir(BUILD_DIR)

  -- Generate the model
  rbxm:save(rbxmObj, rbxmPath)

  -- Save the model to other locations
  for i,v in ipairs(LOCATIONS) do
    rbxm:save(rbxmObj, LOCATIONS[i])
  end
end

compile({...})
