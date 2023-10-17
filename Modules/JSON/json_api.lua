--Allows the user to load and dump json information





--encodes the info from passed arrays/dictionaries into a string and returns it
function json.Encode(info)
    local dispatcher
    local depth = 0

    local string_escape_pattern = '[\0-\31"\\]'

    local string_substitues = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
        __index = function(_, c)
            return string.format('\\u00%02X', string.byte(c))
        end
    }

    setmetatable(string_substitues, string_substitues)


    local function GetTabs(current_depth)
        local tabs = ''
        tab_count = 0
        while current_depth > 0 and tab_count < current_depth do
            tabs = tabs .. '\t'
            tab_count = tab_count + 1
        end

        return tabs
    end


    local function RemoveComma(json_info)
        local first_part, second_part = json_info:match('(.*),(.*)')
        return first_part .. second_part
    end


    local function Stack(value)
        local value_type
        if not value then
            value_type = 'null'
        else
            value_type = type(value)
        end

        local ending = ''
        if depth > 0 then ending = ",\n" end

        return dispatcher[value_type](value) .. ending
    end


    local function EncodeString(value)
        if value:find(string_escape_pattern) then
            value = value:gsub(string_escape_pattern, string_substitues)
        end

        return "\"" .. value .. "\""
    end


    local function EncodeNumber(value)
        return value
    end


    local function EncodeBoolean(value)
        if value then
            return "true"
        else 
            return "false"
        end
    end


    local function EncodeNil(value)
        return "null"
    end


    local function EncodeTable(value)
        if #value > 0 then
            local encoding = '[\n'
            depth = depth + 1

            local value_length = #value

            local i = 1
            if value[0] then
                i = 0
                value_length = value_length - 1
            end

            repeat
                encoding = encoding .. GetTabs(depth) .. Stack(value[i])
                i = i + 1
            until i > value_length

            encoding = RemoveComma(encoding)

            depth = depth - 1
            encoding = encoding .. GetTabs(depth) .. ']'

            return encoding

        else
            local encoding = '{\n'
            depth = depth + 1

            for key, v in pairs(value) do
                encoding = encoding .. GetTabs(depth) .. "\"" .. key .. "\"" .. " : " .. Stack(v)
            end

            encoding = RemoveComma(encoding)

            depth = depth - 1
            encoding = encoding .. GetTabs(depth) .. "}"

            return encoding
        end
    end


    dispatcher = {
        string = EncodeString,
        number = EncodeNumber,
        boolean = EncodeBoolean,
        table = EncodeTable,
        null = EncodeNil,
    }

    local converted_info = Stack(info)

    return converted_info
end


--dumps the info from arrays/dictionaries that you pass it into a string encoded file
function json.Dump(info, file)
    local new_string = json.Encode(info)

    local file_type = type(file)
    if file_type == 'string' then
        file = io.open(file, 'w')
    elseif file_type ~= 'userdata' then
        reaper.ReaScriptError('! No file or filepath given, can\'t proceed with reading the json file.')
    end

    file:write(new_string)
    file:close()
end






--loads the info from a string into arrays/dictionaries
function json.Decode(info, is_zero)
    local dispatcher
    local depth = 0
    local start_pos, end_pos = 1, 1


    local f_str_ctrl_pat = '[\0-\31]'

    local f_str_escapetbl = {
        ['"']  = '"',
        ['\\'] = '\\',
        ['/']  = '/',
        ['b']  = '\b',
        ['f']  = '\f',
        ['n']  = '\n',
        ['r']  = '\r',
        ['t']  = '\t',
        __index = function()
            reaper.ReaScriptError("! Invalid escape sequence")
        end
    }

    setmetatable(f_str_escapetbl, f_str_escapetbl)


    --returnns the json line number that the decoder errored on
    local function GetLineNumber()
        local subbed_line, line_count = info:sub(1, end_pos):gsub('\n', '-_-') --special face symbol for fun (really because this should never be in a string)
        if not subbed_line:find("-_-$") then line_count = line_count + 1 end -- check to see if the error didn't end on a new line (line count is one off if it doesn't)

        return line_count
    end


    local function StartsWith(line, char)
        return line:find('^' .. char)
    end


    local f_str_surrogate_prev = 0
    local function StringSubstitute(ch, ucode)
        if ch == 'u' then
            local c1, c2, c3, c4, rest = string.byte(ucode, 1, 5)
            ucode = f_str_hextbl[c1-47] * 0x1000 +
                    f_str_hextbl[c2-47] * 0x100 +
                    f_str_hextbl[c3-47] * 0x10 +
                    f_str_hextbl[c4-47]
            if ucode ~= inf then
                if ucode < 0x80 then  -- 1byte
                    if rest then
                        return string.char(ucode, rest)
                    end
                    return string.char(ucode)
                elseif ucode < 0x800 then  -- 2bytes
                    c1 = math.floor(ucode / 0x40)
                    c2 = ucode - c1 * 0x40
                    c1 = c1 + 0xC0
                    c2 = c2 + 0x80
                    if rest then
                        return string.char(c1, c2, rest)
                    end
                    return string.char(c1, c2)
                elseif ucode < 0xD800 or 0xE000 <= ucode then  -- 3bytes
                    c1 = math.floor(ucode / 0x1000)
                    ucode = ucode - c1 * 0x1000
                    c2 = math.floor(ucode / 0x40)
                    c3 = ucode - c2 * 0x40
                    c1 = c1 + 0xE0
                    c2 = c2 + 0x80
                    c3 = c3 + 0x80
                    if rest then
                        return string.char(c1, c2, c3, rest)
                    end
                    return string.char(c1, c2, c3)
                elseif 0xD800 <= ucode and ucode < 0xDC00 then  -- surrogate pair 1st
                    if f_str_surrogate_prev == 0 then
                        f_str_surrogate_prev = ucode
                        if not rest then
                            return ''
                        end
                        surrogate_first_error()
                    end
                    f_str_surrogate_prev = 0
                    surrogate_first_error()
                else  -- surrogate pair 2nd
                    if f_str_surrogate_prev ~= 0 then
                        ucode = 0x10000 +
                                (f_str_surrogate_prev - 0xD800) * 0x400 +
                                (ucode - 0xDC00)
                        f_str_surrogate_prev = 0
                        c1 = math.floor(ucode / 0x40000)
                        ucode = ucode - c1 * 0x40000
                        c2 = math.floor(ucode / 0x1000)
                        ucode = ucode - c2 * 0x1000
                        c3 = math.floor(ucode / 0x40)
                        c4 = ucode - c3 * 0x40
                        c1 = c1 + 0xF0
                        c2 = c2 + 0x80
                        c3 = c3 + 0x80
                        c4 = c4 + 0x80
                        if rest then
                            return string.char(c1, c2, c3, c4, rest)
                        end
                        return string.char(c1, c2, c3, c4)
                    end
                    reaper.ReaScriptError("! 2nd surrogate pair byte appeared without 1st")
                end
            end
            reaper.ReaScriptError("! Invalid unicode codepoint literal")
        end
        if f_str_surrogate_prev ~= 0 then
            f_str_surrogate_prev = 0
            surrogate_first_error()
        end
        return f_str_escapetbl[ch] .. ucode
    end


    local function Stack(line)
        local response

        if StartsWith(line, '[\"]') then
            response = dispatcher['string'](line)
        elseif StartsWith(line, '%-?[%d%.]') then
            response = dispatcher['number'](line)
        elseif StartsWith(line, '[tf]') then
            response = dispatcher['boolean'](line)
        elseif StartsWith(line, 'null') then
            response = dispatcher['Null'](line)
        elseif StartsWith(line, '[%[{]') then
            response = dispatcher['table'](line)
        else
            reaper.ReaScriptError('! Incorrectly tried to decode a sequence with no type (line #' .. GetLineNumber() .. '): ' .. line)
            response = nil
        end

        return response
    end


    local function DecodeString(line)
        local new_line = line:match('[\"](.*)[\"]')
        if not new_line then reaper.ReaScriptError('! Incorrectly tried to decode a string (line #' .. GetLineNumber() .. '): ' .. line) end

        if new_line:find('\\', 1, true) then  -- check whether a backslash exists
            new_line = new_line:gsub('\\(.)([^\\]?[^\\]?[^\\]?[^\\]?[^\\]?)', StringSubstitute)
            if f_str_surrogate_prev ~= 0 then
                f_str_surrogate_prev = 0
                reaper.ReaScriptError('! 1st surrogate pair byte not continued by 2nd (line #' .. GetLineNumber() .. '): ' .. line)
            end
        end

        return new_line
    end

    local function DecodeNumber(line)
        local number = tonumber(line)
        if not number then reaper.ReaScriptError('! Incorrectly tried to decode a number (line #' .. GetLineNumber() .. '): ' .. line) end
        
        return number
    end

    local function DecodeBoolean(line)
        if line == "true" then
            return true
        elseif line == "false" then
            return false
        else
            reaper.ReaScriptError('! Incorrectly tried to decode a boolean: (line #' .. GetLineNumber() .. '): ' .. line)
            return nil
        end
    end

    local function DecodeNil(line)
        return nil
    end

    local function DecodeTable(line)
        local decoding = {}

        if line:find('^%[') then
            local array_start, array_end, array_match = info:find('(%b[])', start_pos)

            if array_match then
                end_pos = array_start + 1

                local insert_position = 1
                if is_zero then insert_position = 0 end

                while end_pos < array_end - 1 do
                    local line_start, line_end, line_match = info:find('%s*(.-)[,\n%]]', end_pos)

                    --if the line is a string and it doesn't end with an end quote (because of a comma in the string breaking the regular expression) do some more work to get the whole line
                    if line_match and StartsWith(line_match, '[\"]') and not line_match:find('\"$') then
                        local new_line = info:sub(line_start)
                        local new_start, new_end, new_match = new_line:find('(\".-\")')

                        if new_match then
                            line_match = new_match
                            line_end = line_start + new_end
                        else
                            reaper.ReaScriptError('! Can\'t find the end of a string - additional comma in string may be causing this: (line #' .. GetLineNumber() .. '): ' .. line)
                        end
                    end

                    if not line_match or line_match == '' or StartsWith(line_match, "%]") then break end

                    start_pos = line_start
                    end_pos = line_end + 1

                    decoding[insert_position] = Stack(line_match)

                    insert_position = insert_position + 1
                end

                start_pos = array_end
                end_pos = array_end + 3
            end
        else
            local dict_start, dict_end, dict_match = info:find('(%b{})', start_pos)

            if dict_match then
                local values_end = dict_match:find('%s*}$') --splits off any spaces before the '}' to know when the actual end of the dictionary entries are

                values_end = values_end + dict_start - 1

                end_pos = dict_start + 1

                while end_pos < values_end do
                    local line_start, line_end, key_match, line_match = info:find('%s-[\"](.-)[\"]%s-:%s*(.-),?\n', end_pos) -- does the %s* break something?
                    if not key_match or not line_match or StartsWith(line_match, "}") then break end

                    start_pos = line_start
                    end_pos = line_end

                    decoding[key_match] = Stack(line_match)
                end

                start_pos = dict_end
                end_pos = dict_end + 3
            end
        end

        return decoding
    end


    dispatcher = {
        string = DecodeString,
        number = DecodeNumber,
        boolean = DecodeBoolean,
        table = DecodeTable,
        null = DecodeNil,
    }

    -- local converted_table = Stack(info) -- don't think this is right Did I need it like this for the CharList?
    local converted_table = DecodeTable(info)

    return converted_table
end


--reads the info from a file and then decodes it into arrays/dictionaries
function json.Load(file)
    local file_type = type(file)

    if file_type == 'string' then
        file = io.open(file, 'r')
    elseif file_type ~= 'userdata' then
        reaper.ReaScriptError('! No file or filepath given, can\'t proceed with reading the json file.')
    end

    local file_info = file:read("*all")
    file:close()

    return json.Decode(file_info)
end
