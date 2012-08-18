-- join two yaml files
local yaml = require 'yaml' -- using patched luayaml with is_binary_string disabled =_=

local base, patch, level, out = arg[1], arg[2], tonumber(arg[3]) or 1, arg[4]

if not (base and patch) then
    print('Usage: '..arg[0]..' base patch [level=1] [out=stdout]')
    os.exit(1)
end

-- load from file
function readYAML(filename)
    local f = io.open(filename)
    local yaml = yaml.load(f:read('*a'))
    f:close()
    return yaml
end

-- recursive join
function join(base, patch)
    if type(patch) == 'table' then
        for k in pairs(patch) do
            base[k] = join(base[k] or {}, patch[k])
        end
        return base
    end
    return patch or base
end

-- read
base, patch = readYAML(base), readYAML(patch)

-- rename first key
local cursorBase, cursorPatch = base, patch
for l = 1, level do
    local baseKey, patchKey = {}, {}
    for i in pairs(cursorBase) do baseKey[#baseKey + 1] = i end
    for i in pairs(cursorPatch) do patchKey[#patchKey + 1] = i end
    if #baseKey ~= #patchKey or #baseKey ~= 1 then
        error(string.format('level %d should have single key: [%s], [%s],',
            l, table.concat({unpack(baseKey, 1, 2)}, ','), table.concat({unpack(patchKey, 1, 2)}, ',')))
    end
    baseKey, patchKey = baseKey[1], patchKey[1]
    cursorBase[patchKey], cursorBase[baseKey] = cursorBase[baseKey], nil -- rename key
    cursorBase, cursorPatch = cursorBase[patchKey], cursorPatch[patchKey] -- we need to go deeper
end

out = out and io.open(out, 'w+b') or io.stdout
base, patch = join(base, patch), nil
--out:write(yaml.dump(base)) -- simple dump, random ordering

-- HACK: base order
local baseStack = {{-1, base, ''}}
function stackPath()
    local path = {}
    for i, v in ipairs(baseStack) do path[#path + 1] = v[3] end
    return table.concat(path, ':')
end

for l in io.lines(arg[1]) do
    local spaces, key, raw = string.match(l, '^(%s*)([%w_-]+)%s*:(.*)$') -- naive
    if key then
        local cursorBase = baseStack[#baseStack]
        local indent, value = unpack(cursorBase)

        while #spaces <= indent do -- level up
            table.remove(baseStack)
            indent, value = unpack(baseStack[#baseStack] or error("stack underflow"))
        end

        if #baseStack <= level then
            for i in pairs(value) do key, value = i, value[i] break end -- first key
        else
            value = value[key]
        end

        if #spaces > indent then -- level down
            baseStack[#baseStack + 1] = {#spaces, value, key }
        else
            cursorBase[3] = key
        end

        out:write(spaces, key, ':')
        if not(value) then
            out:write(raw, ' # (!) \n')
        elseif type(value) ~= 'table' then
            out:write(' "', string.gsub(tostring(value), '"', '\\"'),'"\n')
        else
            out:write('\n')
        end
    elseif string.match(l, '^%s*#') then -- comment
        out:write(l, '\n') -- copy
    end

end

out:close()