--This script pins the selected track to the top of the arrange view, moving it to always be at the top as you scroll and adjust the view


--gets the zero based track index
function GetTrackIndex(track)
    return reaper.CSurf_TrackToID(track, false) - 1
end


--wait to go back to the initial project if you change projects
function WaitForProject()
    if reaper.EnumProjects(-1) ~= init_proj then
        reaper.defer(WaitForProject)
    else
        GetScrollLevel()
    end
end


--checks the scroll level to make sure you have adjusted the screen (i.e. it should move the track) and that you have stopped scrolling
function GetScrollLevel()
    local is_continue = reaper.GetExtState("pin_track", ext_key) == track_string or false

    --end early if you removed the track
    if not reaper.ValidatePtr(init_proj, "ReaProject*") or not reaper.ValidatePtr2(init_proj, track, "MediaTrack*") then
        still_exists = false
        do return end
    end

    --wait until user goes back to initial project
    if reaper.EnumProjects(-1) ~= init_proj then
        is_continue = false
        WaitForProject()
    end

    --see if the scroll view has changed (and react appropriately) if you haven't cancelled the script
    if is_continue then
        local retval, pos = reaper.JS_Window_GetScrollInfo(tcp_id, "v")

        if last_scroll then
            if has_moved and last_scroll == pos then
                if not last_time then last_time = reaper.time_precise() end

                if reaper.time_precise() - last_time > 0.25 then
                    MoveTrack()

                    last_scroll = nil
                    last_time = nil
                    
                    has_moved = false
                end

            else
                if not has_moved and last_scroll ~= pos then has_moved = true end        
                last_time = nil
            end
        end

        last_scroll = pos

        reaper.defer(GetScrollLevel)
    end
end


--moves the track to the new index
function MoveTrack(new_index)
    local tcp_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
    local wnd_h = reaper.GetMediaTrackInfo_Value(track, "I_WNDH")

    local track_index = GetTrackIndex(track)
    local track_count = reaper.CountTracks(init_proj) - 1

    local adjustment = 0

    --if you aren't directly telling the script where to move it to and it isn't already up top
    if tcp_y ~= 0 and not new_index then
        
        --get the combined height of the track and children tracks so moving them accounts for the full size
        for i = track_index + 1, track_count do
            local child_track = reaper.GetTrack(init_proj, i)
            if not reaper.GetParentTrack(child_track) then
                break
            else
                wnd_h = wnd_h + reaper.GetMediaTrackInfo_Value(child_track, "I_WNDH") 
            end
        end

        new_index = -1

        --move the track down in index (up in view)
        if tcp_y > 0 and track_index > 0 then
            new_index = track_index - 1

            while new_index >= 0 do
                local prev_track = reaper.GetTrack(init_proj, new_index)

                local prev_y = reaper.GetMediaTrackInfo_Value(prev_track, "I_TCPY")
                local prev_h = reaper.GetMediaTrackInfo_Value(prev_track, "I_WNDH")

                --break out once you find the "top" track and put it before that track
                if prev_y > 0 then
                    new_index = new_index - 1
                    adjustment = prev_y
                else
                    if prev_y < 0 then new_index = new_index + 1 end --if you go past the first track just increment up
                    if prev_y == 0 then adjustment = 0 end --reset the adjustment if the track will be at the top already
                    break
                end
            end

            if new_index < 0 then new_index = 0 end

        --move the track up in index (down in view)
        elseif tcp_y < 0 and track_index < track_count then
            new_index = track_index + 1
            
            while new_index <= track_count do
                local next_track = reaper.GetTrack(init_proj, new_index)

                local next_y = reaper.GetMediaTrackInfo_Value(next_track, "I_TCPY")
                local next_h = reaper.GetMediaTrackInfo_Value(track, "I_WNDH")
                
                --figure out the first track in view
                if next_y < 0 then
                    new_index = new_index + 1
                else
                    adjustment = next_y - wnd_h
                    break
                end
            end

            if new_index > track_count then new_index = track_count end
        end
    end

    --if the index isn't the same (i.e. it needs to change then go in and move it)
    if new_index and new_index ~= last_index then
        reaper.PreventUIRefresh(1)

        --save selected tracks
        local sel_tracks = {}
        for i = 0, reaper.CountSelectedTracks(init_proj) - 1 do table.insert(sel_tracks, reaper.GetSelectedTrack(init_proj, i)) end

        --only move main track
        reaper.SetOnlyTrackSelected(track)
        reaper.ReorderSelectedTracks(new_index, 0)
    
        reaper.SetTrackSelected(track, false)

        for i, sel_track in ipairs(sel_tracks) do reaper.SetTrackSelected(sel_track, true) end --reset selected tracks

        --adjust the scroll window to fit the track/children tracks (make them the top track in view and fully on screen)
        if adjustment ~= 0 then
            local retval, pos = reaper.JS_Window_GetScrollInfo(tcp_id, "v")
            reaper.JS_Window_SetScrollPos(tcp_id, "v", pos + adjustment)
        end

        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        
        last_index = new_index
    end
end


--resets the track's original positon on termination
function OnTerminate()

    --moves the track back to the original spot it was ini originially if you didn't delete it
    if still_exists and last_index >= 0 then
        local reset_index = -1

        --finds the last track that was before the track originally (and still exists)
        for i = init_index, 0, -1 do
            local found_index = false
            local check_track = reaper.GetTrack(init_proj, i)

            for j, prev_track in ipairs(previous_tracks) do
                if check_track == prev_track then
                    found_index = true
                    break
                end
            end

            if found_index then
                reset_index = i
                break
            end
        end

        MoveTrack(reset_index + 1)
    end

    --remove the ext state telling it when to stop (if the last track to be moved is the same track that this instance is moving)
    if reaper.GetExtState("pin_track", ext_key) == track_string then reaper.DeleteExtState("pin_track", ext_key, true) end
end





--------
--MAIN--
--------

track = reaper.GetSelectedTrack(0, 0)

--only start if there is a track selected
if track then
    track_string = tostring(track)

    init_index = GetTrackIndex(track)

    init_proj = reaper.EnumProjects(-1) --store the initial project

    hwnd = reaper.GetMainHwnd()
    tcp_id = reaper.JS_Window_FindChildByID(hwnd, 0x3E8)

    last_index = -1
    last_time, last_scroll = nil, nil
    has_moved = true --moves it right on start

    still_exists = true
    changed_project = nil --tells script to switch back and normalize things if you changed the project

    _, _, section_id, command_id = reaper.get_action_context()

    ext_key = "is_continue_" .. tostring(init_proj)
    
    --if the script is still running from another instance end it, or end the pinning if you pin the same track again
    if reaper.GetExtState("pin_track", ext_key) == track_string then
        reaper.DeleteExtState("pin_track", ext_key, true)
        do return end
    end
    
    --save all of the tracks that are before the frozen one so you can move it back to the right spot post freezing
    previous_tracks = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local prev_track = reaper.GetTrack(0, i)

        if prev_track ~= track then
            table.insert(previous_tracks, prev_track)
        else
            break
        end

    end

    reaper.SetExtState("pin_track", ext_key, track_string, true)

    GetScrollLevel() --start the defer loop
    reaper.atexit(OnTerminate) --reset everything on termination
end