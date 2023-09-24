--saves options for the Extend-Trim scripts

reaper.defer(function() end)

local topFade = tonumber(reaper.GetExtState('extend-trim', 'topFade'))
if not topFade then topFade = 0 end

local tailFade = tonumber(reaper.GetExtState('extend-trim', 'tailFade'))
if not tailFade then tailFade = 0 end

local isExtend = true
if reaper.GetExtState('extend-trim', 'isExtend') == 'false' then isExtend = false end


local retval, input = reaper.GetUserInputs("Extend-Trim Options", 3, "Minimum Top Fade (sec),Minimum Tail Fade (sec),Extend Allowed (true/false)", string.format("%.2f,%.2f,%s", topFade, tailFade, isExtend))
if not retval then return end

local topFade, tailFade, isExtend = input:match("(.-),(.-),(.*)")

topFade = tonumber(topFade)
if not topFade or topFade < 0 then
    reaper.ShowMessageBox('The top fade value was not a number, or it was a negative one. Please try again and input a number greater than or equal to zero.', 'Error Recording Input', 0)
    return
end

tailFade = tonumber(tailFade)
if not tailFade or tailFade < 0 then
    reaper.ShowMessageBox('The tail fade value was not a number, or it was a negative one. Please try again and input a number greater than or equal to zero.', 'Error Recording Input', 0)
    return
end

isExtend = isExtend:lower()
if isExtend ~= 'true' and isExtend ~= 'false' then
    reaper.ShowMessageBox('The value given for the extension approval is not \"true\" or \"false\". Please try again and only input one of those values.', 'Error Recording Input', 0)
    return
end

reaper.SetExtState('extend-trim', 'topFade', topFade, true)
reaper.SetExtState('extend-trim', 'tailFade', tailFade, true)
reaper.SetExtState('extend-trim', 'isExtend', isExtend, true)