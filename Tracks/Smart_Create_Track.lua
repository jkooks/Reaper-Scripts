--[[
	This script is used to make a track at any depth level after the selected track

	Situations:
		If no tracks is selected = create a track at the end of the track count
		
		If one track is selected:
			If it is a "base level track" (i.e. not parented) = create another base level track
			If it is the end of a folder = create a base level track/normal track within the overarching folder structure (if there is one)
			If it is within a folder structure = create another track within that structure

		If multiple tracks selected:
			If the last track selected is the end of the folder structure:
				If the first track selected is within the same folder structure/the parent of it = create a track and make it the new end of that structure
				If the first track is a "grandparent"/part of an overarching folder structure = create a track and make it the end of that folder if there isn't one already
					otherwise add it as a base level track

			If it is not the end of the folder structure = create a track within that folder

]]--

--gets total depth of the parent
function GetDepth(track)
	local depth = 0
	local parent = reaper.GetParentTrack(track)
	while parent do
		depth = depth + 1
		parent = reaper.GetParentTrack(parent)
	end

	return depth
end


--creates the tracks based off of the tracks that are selected
function AddTrack()
	local selected_count = reaper.CountSelectedTracks(0)
	local total_count = reaper.CountTracks(0)

	local last_track, first_track, next_track

	if selected_count > 0 then
		last_track = reaper.GetSelectedTrack(0, selected_count - 1) --grabs last track if you are adding it below and there are multiple tracks selected
		if selected_count > 1 then first_track = reaper.GetSelectedTrack(0, 0) end --grab the first track for parent level
	elseif selected_count == 0 then
		last_track = reaper.GetTrack(0, total_count - 1) --grabs the very last track if none are selected
	end

	--index of the selected track/where you want to add the new track after
	local last_index = total_count
	if last_track then
		last_index = reaper.GetMediaTrackInfo_Value(last_track, "IP_TRACKNUMBER") --return 1 based track number
		if last_index < total_count then next_track = reaper.GetTrack(0, last_index) end
	end

	--create the new track
	reaper.InsertTrackAtIndex(last_index, false)
	local new_track = reaper.GetTrack(0, last_index)

	--optional:
	reaper.SetTrackSelected(new_track, true) --if you want the new track to also be selected
	-- reaper.SetOnlyTrackSelected(new_track) --if you want the new track to be only track selected
	-- reaper.SetTrackColor(new_track, reaper.ColorToNative(math.random(0, 255), math.random(0, 255), math.random(0, 255))) --if you want color to be random

	--makes new tracks foldered tracks if more than one track was originally seleceted and the last track is the end of the folder
	if last_track and selected_count > 1then
		local end_depth = reaper.GetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH")

		if end_depth < 0 then

			--if the first track selected is a parent and the last track is the end of the folder then make the new track the end of the first track's folder
			if first_track and reaper.GetMediaTrackInfo_Value(first_track, "I_FOLDERDEPTH") == 1 and first_track ~= reaper.GetParentTrack(last_track) then

				--if there is already an end to the folder just end early (i.e. it is just a 0 track in that folder)
				if next_track and reaper.GetParentTrack(next_track) == first_track then
					return new_track
				else
					local parent_depth = GetDepth(first_track)

					if parent_depth == 0 or (parent_depth == 2 and end_depth == -2) then parent_depth = 1 end -- make sure they will always be at least -1

					reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", end_depth + parent_depth)
					reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -parent_depth)
				end

			--make the new track the end of current parent's folder if multiple tracks are selected and the last track is parented to the first track
			else
				reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", 0)
				reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", end_depth)
			end
		end
	end

	return new_track
end


function Main()
	reaper.Undo_BeginBlock()

	reaper.PreventUIRefresh(1)

	AddTrack()

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Add New Track", -1)
end

Main()
