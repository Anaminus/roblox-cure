local lfs = require 'lfs'

if _VERSION == 'Lua 5.2' then
	unpack = table.unpack
end

-- maximum length of strings in replicated instances
MAX_STRING_LENGTH = 200000 - 1

local saveRBXM do
	-- because of the way XML is parsed, leading spaces get truncated
	-- so, simply add a "\" when a space or "\" is detected as the first character
	-- this will be decoded automatically by Cure
	local function encodeTruncEsc(str)
		local first = str:sub(1,1)
		if first:match('%s') or first == [[\]] then
			return [[\]] .. str
		end
		return str
	end

	local function escapeToXML(str)
		local nameEsc = {
			['"'] = "quot";
			["&"] = "amp";
			["'"] = "apos";
			["<"] = "lt";
			[">"] = "gt";
		}
		local out = ""
		for i = 1,#str do
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

	local encodeDataType = {
		['string'] = function(data)
			return encodeTruncEsc(escapeToXML(data))
		end;
		['ProtectedString'] = function(data)
			return encodeTruncEsc(escapeToXML(data))
		end;
		['CoordinateFrame'] = function(data,tab)
			local d = {data:components()}
			return {
				"\n",tab( 1),[[<X>]],d[1],[[</X>]];
				"\n",tab(  ),[[<Y>]],d[2],[[</Y>]];
				"\n",tab(  ),[[<Z>]],d[3],[[</Z>]];
				"\n",tab(  ),[[<R00>]],d[4],[[</R00>]];
				"\n",tab(  ),[[<R01>]],d[5],[[</R01>]];
				"\n",tab(  ),[[<R02>]],d[6],[[</R02>]];
				"\n",tab(  ),[[<R10>]],d[7],[[</R10>]];
				"\n",tab(  ),[[<R11>]],d[8],[[</R11>]];
				"\n",tab(  ),[[<R12>]],d[9],[[</R12>]];
				"\n",tab(  ),[[<R20>]],d[10],[[</R20>]];
				"\n",tab(  ),[[<R21>]],d[11],[[</R21>]];
				"\n",tab(  ),[[<R22>]],d[12],[[</R22>]];
				"\n",tab(-1);
			}
		end;
		['Color3'] = function(data)
			return tonumber(string.format("0xFF%02X%02X%02X",data.r*255,data.g*255,data.b*255))
		end;
		['Content'] = function(data)
			if #data == 0 then
				return [[<null></null>]]
			else
				return {[[<url>]],data,[[</url>]]}
			end
		end;
		['Ray'] = function(data,tab)
			local o = data.Origin
			local d = data.Direction
			return {
				"\n",tab( 1),[[<origin>]];
				"\n",tab( 1),[[<X>]],o.x,[[</X>]];
				"\n",tab(  ),[[<Y>]],o.y,[[</Y>]];
				"\n",tab(  ),[[<Z>]],o.z,[[</Z>]];
				"\n",tab(-1),[[</origin>]];
				"\n",tab(  ),[[<direction>]];
				"\n",tab( 1),[[<X>]],d.x,[[</x>]];
				"\n",tab(  ),[[<Y>]],d.y,[[</Y>]];
				"\n",tab(  ),[[<Z>]],d.z,[[</Z>]];
				"\n",tab(-1),[[</direction>]];
				"\n";tab(-1);
			}
		end;
		['Vector3'] = function(data,tab)
			return {
				"\n",tab( 1),[[<X>]],data.x,[[</X>]];
				"\n",tab(  ),[[<Y>]],data.y,[[</Y>]];
				"\n",tab( 0),[[<Z>]],data.z,[[</Z>]];
				"\n";tab(-1);
			}
		end;
		['Vector2'] = function(data,tab)
			return {
				"\n",tab( 1),[[<X>]],data.x,[[</X>]];
				"\n",tab( 0),[[<Y>]],data.y,[[</Y>]];
				"\n";tab(-1);
			}
		end;
		['UDim2'] = function(data,tab)
			return {
				"\n",tab( 1),[[<XS>]],data.X.Scale,[[</XS>]];
				"\n",tab(  ),[[<XO>]],data.X.Offset,[[</XO>]];
				"\n",tab(  ),[[<YS>]],data.Y.Scale,[[</YS>]];
				"\n",tab( 0),[[<YO>]],data.Y.Offset,[[</YO>]];
				"\n";tab(-1);
			}
		end;
		['Ref'] = function(data)
			if data == nil then
				return "null"
			else
				return data
			end
		end;
		['double'] = function(data)
			return string.format("%f",data)
		end;
		['int'] = function(data)
			return string.format("%i",data)
		end;
		['bool'] = function(data)
			return not not data
		end;
	}

	-- Converts a RBXM table to a string.
	local function strRBXM(var)
		if type(var) ~= 'table' then
			error("table expected",2)
		end

		local contentString = {}
		local function output(...)
			local args = {...}
			for i = 1,#args do
				if type(args[i]) == 'table' then
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
				return string.rep("\t",t)
			end
		end

		local ref = 0
		local function r(object)
			output("\n",tab(),[[<Item class="]],object.ClassName,[[" referent="RBX]],ref,[[">]],"\n",tab(1),[[<Properties>]])
			ref = ref + 1

			local sorted = {}
			for k in pairs(object) do
				if type(k) == 'string' and k ~= "ClassName" then
					sorted[#sorted+1] = k
				end
			end
			table.sort(sorted)
			tab(1)
			for i = 1,#sorted do
				local propName = sorted[i]
				local propType,propValue = object[propName][1],object[propName][2]

				if encodeDataType[propType] then
					propValue = encodeDataType[propType](propValue,tab)
				end

				output("\n",tab(),[[<]],propType,[[ name="]],propName,[[">]],propValue,[[</]],propType,[[>]])
			end
			output("\n",tab(-1),[[</Properties>]])

			for i = 1,#object do
				r(object[i])
			end

			output("\n",tab(-1),[[</Item>]])
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

	-- Saves a RBXM string or table.
	function saveRBXM(var,filename)
		if type(var) == 'table' then
			var = strRBXM(var)
		end
		if type(var) == 'string' then
			local file = assert(io.open(filename,'w'))
			file:write(var)
			file:flush()
			file:close()
		else
			error("bad type",2)
		end
	end
end

local function splitName(path)
	for i = #path,1,-1 do
		local c = path:sub(i,i)
		if c == "." then
			return path:sub(1,i-1),path:sub(i+1,#path)
		end
	end
	return path,""
end

local function createValue(type,name,value)
	return {ClassName=type .. 'Value', Name={'string',name}, Value={type:lower(),value}}
end

local function checkSyntax(source)
	-- If it's a script, you want to make sure it can compile!
	local f, e = loadstring(source,'')
	if not f then
		print("WARNING: " .. e:gsub('^%[.-%]:',"line "))
	end
end

local function handleFile(path,file,sub)
	local content do
		local f = assert(io.open(path))
		content = f:read('*a')
		f:close()
	end

	if not sub and file:lower() == "cure.server.lua" then
		checkSyntax(content)
		return {ClassName='Script';
			Name={'string',"cure.server"};
			Source={'ProtectedString',content};
		}
	elseif not sub and file:lower() == "cure.client.lua" then
		checkSyntax(content)
		return {ClassName='LocalScript';
			Name={'string',"cure.client"};
			Source={'ProtectedString',content};
		}
	end

	local name,ext = splitName(file)
	ext = ext:lower()
	if ext == "lua" then
		checkSyntax(content)
		local subname,subext = splitName(name)
		if subext:lower() == "script" then
			return {ClassName='Script';
				Name={'string',subname};
				Source={'ProtectedString',content};
			}
		elseif subext:lower() == "localscript" then
			return {ClassName='LocalScript';
				Name={'string',subname};
				Source={'ProtectedString',content};
			}
		else
			local chunk = MAX_STRING_LENGTH
			local length = #content
			if length <= chunk then
				return createValue('String',name,content)
			else
				local value = createValue('Bool',name,true)
				for i = 1,math.ceil(length/chunk) do
					local a = (i - 1)*chunk + 1
					local b = a + chunk - 1
					b = b > length and length or b
					value[i] = createValue('String',tostring(i),content:sub(a,b))
				end
				return value
			end
		end
	elseif ext == "asset" then
		content = tonumber(content)
		if not content then
			print("WARNING: content of `" .. file .. "` must be a number")
		end
		return createValue('Int',name,content)
	elseif ext == "value" then
		return createValue('String',name,content)
	else
		return {ClassName='Script';
			Name={'string',name};
			Disabled={'bool',true};
			Source={'ProtectedString',"--[==[\n" .. content .. "\n--]==]"};
		}
	end
end

local function recurseDir(path,obj,r)
	print("DIR ",path)
	for name in lfs.dir(path) do
		if name ~= ".." and name ~= "." and name ~= ".gitignore" then
			local p = path .. "/" .. name
			if lfs.attributes(p,'mode') == 'directory' then
				obj[#obj+1] = recurseDir(p,{ClassName='Configuration', Name={'string',name}},true)
			else
				print("FILE",p)
				obj[#obj+1] = handleFile(p,name,r)
			end
		end
	end
	return obj
end

local rbxmObj = recurseDir("source",{ClassName='Configuration', Name={'string',"cure"}})
saveRBXM(rbxmObj,"build/" .. ((...) or "cure.rbxm"))

local f = io.open("locations.txt")
if f then
	local outputs = f:read('*a')
	f:close()

	for path in outputs:gmatch('[^\r\n]+') do
		saveRBXM(rbxmObj,path)
		print("wrote to",path)
	end
end
