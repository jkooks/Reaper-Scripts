--Extends and trims left edge of the next clip on the selected track


--gets the envelope points
function GetEnvelopePos(take)
	local envelopes = {}

	local index = 0
	while true do
		local thisEnvelope = reaper.GetTakeEnvelope(take, index)
		if thisEnvelope then
			local points = {}
			local pointCount = reaper.CountEnvelopePoints(thisEnvelope)

			local retval
			for i = 0, pointCount - 1 do
				retval, points[i] = reaper.GetEnvelopePoint(thisEnvelope, i)
			end

			envelopes[index] = {
				envelope = thisEnvelope,
				name = reaper.GetEnvelopeName(thisEnvelope),
				point_count = pointCount,
				points = points,
			}

			index = index + 1
		else
			break
		end
	end

	return envelopes, index
end


--sets a the envelope points
function SetEnvelopePos(envelopes, count, lenDif)
	for i = 0, count - 1 do
		local thisEnvelope = envelopes[i].envelope
		local pointCount = envelopes[i].point_count
		local points = envelopes[i].points

		for j = pointCount - 1, 0, -1 do
			reaper.SetEnvelopePoint(thisEnvelope, j, points[j] + lenDif , nil, nil, nil, nil, true)
		end

		reaper.Envelope_SortPoints(thisEnvelope)
	end
end


-----------------
----Main Code----
-----------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

--unselects all the selected items (if there are any)
local itemNum = reaper.CountSelectedMediaItems(0)
for i = itemNum - 1 , 0, -1 do
	local thisItem = reaper.GetSelectedMediaItem(0, i)
	reaper.SetMediaItemSelected(thisItem, false)
end

--makes sure the mouse cursor is over the arrange view
local cursorPos = reaper.BR_PositionAtMouseCursor(false)
if cursorPos == -1 then 
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("Trim/Extend Left Edge", 0)
	return
end


--gets item that mouse cursor is over (if there is one)
x,y = reaper.GetMousePosition() -- get x,y of the mouse
local editItem = reaper.GetItemFromPoint(x, y, false) -- check if item is under mouse


--gets the next grid line if snap is enabled
local snapState = reaper.GetToggleCommandState(1157) --Options: Toggle snapping
if snapState == 1 then cursorPos = reaper.SnapToGrid(0, cursorPos) end


--trims item(s)
if editItem then
	reaper.SetMediaItemSelected(editItem, true)

	local group = reaper.GetMediaItemInfo_Value(editItem, "I_GROUPID")
	if group > 0 then --trims multiple items if part of a group
		reaper.Main_OnCommand(40034, 0) --selects all items if the original is part of a group
	end

	itemNum = reaper.CountSelectedMediaItems(0)
	for i = 0, itemNum - 1 do
		local editDif

		local thisItem = reaper.GetSelectedMediaItem(0, i)

		local itemStart = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION")
		local itemLen = reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")
		local itemEnd = itemStart + itemLen

		local editDif = cursorPos - itemStart
		local newLen = itemLen - editDif

		reaper.SetMediaItemInfo_Value(thisItem, "D_POSITION", cursorPos)
		reaper.SetMediaItemInfo_Value(thisItem, "D_LENGTH", newLen)

		--changes the fade length to make sure it isn't lower than a one frame length
		-- local fadeLen = reaper.GetMediaItemInfo_Value(thisItem, "D_FADEINLEN")
		-- local newFadeLen = fadeLen - editDif
		-- if newFadeLen <= 0.033 then newFadeLen = 0.033 end --arbitrary value (set to one frame at 27.97 FPS)
		-- reaper.SetMediaItemInfo_Value(thisItem, "D_FADEINLEN", newFadeLen)

		--gets rid of snap offset values cause they are dumb
		local snapOffset = reaper.GetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET")
		if snapOffset ~= 0 then
			reaper.SetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET", 0)
		end

		--goes through takes to make sure points are in line
		local takeNumber = reaper.CountTakes(thisItem)
		for j = 0, takeNumber - 1 do
			local thisTake = reaper.GetMediaItemTake(thisItem, j)
			local offsetValue = reaper.GetMediaItemTakeInfo_Value(thisTake, "D_STARTOFFS")
			local playRate = reaper.GetMediaItemTakeInfo_Value(thisTake, "D_PLAYRATE")

			local sourceLen = reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(thisTake))

			local envelopes, envCount = GetEnvelopePos(thisTake)

			local newOffset = offsetValue + (editDif * playRate)
			if sourceLen - newOffset < 0 then
				newOffset = -(sourceLen - newOffset) --resets the source offset if the item goes past the loop point
			end


			reaper.SetMediaItemTakeInfo_Value(thisTake, "D_STARTOFFS", newOffset)

			if envelopes then SetEnvelopePos(envelopes, envCount, -(editDif*playRate)) end
		end
	end



--extends item(s)
else
	local thisTrack = reaper.GetTrackFromPoint(x, y) -- get track under mouse

	--finds the item that you want to edit/gets start position for it
	itemNum = reaper.CountTrackMediaItems(thisTrack)
	for i = 0, itemNum - 1 do
		local thisItem = reaper.GetTrackMediaItem(thisTrack, i)
		local thisPos = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION")

		if thisPos >= cursorPos then
			editItem = thisItem
			break
		end
	end

	--break out of the script in case there are no items (i.e. cursor is after the last item)
	if not editItem then
		reaper.PreventUIRefresh(-1)
		reaper.Undo_EndBlock("Trim/Extend Left Edge", 0)
		return
	end

	reaper.SetMediaItemSelected(editItem, true)

	local group = reaper.GetMediaItemInfo_Value(editItem, "I_GROUPID")
	if group > 0 then --trims multiple items if part of a group
		reaper.Main_OnCommand(40034, 0) --selects all items if the original is part of a group
	end

	--runs through all of the items
	itemNum = reaper.CountSelectedMediaItems(0)
	for i = 0, itemNum - 1 do
		local editDif

		local thisItem = reaper.GetSelectedMediaItem(0, i)

		local isLoop = reaper.GetMediaItemInfo_Value(thisItem, "B_LOOPSRC")

		local itemStart = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION")
		local itemLen = reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")
		local itemEnd = itemStart + itemLen

		local editDif = itemStart - cursorPos
		local newLen = itemLen + editDif


		reaper.SetMediaItemInfo_Value(thisItem, "D_POSITION", cursorPos)
		reaper.SetMediaItemInfo_Value(thisItem, "D_LENGTH", newLen)



		--gets rid of snap offset values cause they are dumb
		local snapOffset = reaper.GetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET")
		if snapOffset ~= 0 then
			reaper.SetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET", 0)
		end

		--changes take offsets and makes suer that the envelope points will stay where they need to
		local takeNumber = reaper.CountTakes(thisItem)
		for j = 0, takeNumber - 1 do
			local thisTake = reaper.GetMediaItemTake(thisItem, j)

			local envelopes, envCount = GetEnvelopePos(thisTake)

			local playRate = reaper.GetMediaItemTakeInfo_Value(thisTake, "D_PLAYRATE")
			local offsetValue = reaper.GetMediaItemTakeInfo_Value(thisTake, "D_STARTOFFS")

			local newOffset = offsetValue - (editDif * playRate)
			local thisSource = reaper.GetMediaItemTake_Source(thisTake)
			local sourceLen = reaper.GetMediaSourceLength(thisSource)

			--changes the fade length to make sure it isn't lower than a one frame length
			-- local fadeLen = reaper.GetMediaItemInfo_Value(thisItem, "D_FADEINLEN")
			-- local newFadeLen = fadeLen + editDif
			-- if newFadeLen <= 0.033 then newFadeLen = 0.033 end --arbitrary value (set to one frame at 27.97 FPS)
			-- reaper.SetMediaItemInfo_Value(thisItem, "D_FADEINLEN", newFadeLen)

			--changes the offset if the source is being looped (itemLen > sourceLen)
			if newOffset < 0 and isLoop == 1 then
				local repetitions = 1
				if newOffset < -sourceLen then repetitions = -(newOffset//sourceLen) end

				newOffset = (sourceLen * repetitions) + newOffset
			end

			reaper.SetMediaItemTakeInfo_Value(thisTake, "D_STARTOFFS", newOffset)

			if envelopes then SetEnvelopePos(envelopes, envCount, editDif * playRate) end
		end
	end
end


--gets the frame count that is in 3% of the view  and the markers where it will move the view if edited in them (EXPERIMENT WITH OTHER if you'd like)
local startFrame, endFrame = reaper.GetSet_ArrangeView2(0, false, 0, 0) --gets the frames that are in view

local totalFrame = endFrame - startFrame
local screenPerc = (totalFrame * 0.03) --% of the screen you want to account for
local resetEnd = endFrame - screenPerc
local resetStart = startFrame + screenPerc

--moves the screen/frames up if the cursor is wihtin the last (right side) 3% of the screen
if cursorPos > resetEnd then
	local newValue =  cursorPos - (endFrame - screenPerc) --abundance of math is so it shifts the view more if you are closer to the frame limit

	startFrame = startFrame + newValue
	endFrame = endFrame + newValue

	local newStartFrame, newEndFrame = reaper.GetSet_ArrangeView2(0, true, 0, 0, startFrame, endFrame)

--moves the screen/frames down if the cursor is wihtin the beginning (left side) 3% of the screen
elseif cursorPos < resetStart then
	local newValue = (startFrame + screenPerc) - cursorPos --abundance of math is so it shifts the view more if you are closer to the frame limit

	startFrame = startFrame - newValue
	endFrame = endFrame - newValue
	
	local newStartFrame, newEndFrame = reaper.GetSet_ArrangeView2(0, true, 0, 0, startFrame, endFrame)	
end


--clean up code

--unselects all of the selected items
for i = itemNum - 1 , 0, -1 do
	local thisItem = reaper.GetSelectedMediaItem(0, i)
	reaper.SetMediaItemSelected(thisItem, false)
end

reaper.SetEditCurPos(cursorPos, false, false) --sets the cursor positions to wherever it should be


reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Trim/Extend Left Edge", -1)