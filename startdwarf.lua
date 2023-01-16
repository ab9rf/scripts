-- change number of dwarves on initial embark

local addr = dfhack.internal.getAddress('start_dwarf_count')
if not addr then
    qerror('start_dwarf_count address not available - cannot patch')
end

local num = tonumber(({...})[1])
if not num or num < 7 or num > 9 then
    qerror('argument must be a number between 7 and 9')
end

dfhack.with_temp_object(df.new('uint32_t'), function(temp)
    temp.value = num
    local temp_size, temp_addr = temp:sizeof()
    dfhack.internal.patchMemory(addr, temp_addr, temp_size)
end)
