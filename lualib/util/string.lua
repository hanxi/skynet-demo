local M = {}

function M.fromhex(str)
    return (str:gsub("..", function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

function M.tohex(str)
    return (str:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end))
end

function M.split(s, delim)
    local sp = {}
    local pattern = "[^" .. delim .. ']+'
    string.gsub(s, pattern, function(v) table.insert(sp, v) end)
    return sp
end

return M
