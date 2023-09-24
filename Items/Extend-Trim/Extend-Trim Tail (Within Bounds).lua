--Extends and trims right edge of the previous clip on the selected track if the item isn't shorter/longer than what you want to trim it to
--(simpler code than left end cause I don't have to mess with source offsets and envelope point positions)




-----------------
----Main Code----
-----------------


--unselects all the selected items (if there are any)
local itemNum = reaper.CountSelectedMediaItems(0)
for i = itemNum - 1 , 0, -1 do
	local thisItem = reaper.GetSelectedMediaItem(0, i)
	reaper.SetMediaItemSelected(thisItem, false)
end

--makes sure the mouse cursor is over the arrange view
local cursorPos = reaper.BR_PositionAtMouseCursor(false)
if cursorPos == -1 then 
	reaper.defer(function() end)
	return
end

--gets item that mouse cursor is over (if there is one)
x,y = reaper.GetMousePosition() -- get x,y of the mouse
local editItem = reaper.GetItemFromPoint(x, y, false) -- check if item is under mouse

--gets the next grid line if snap is enabled
local snapState = reaper.GetToggleCommandState(1157) --Options: Toggle snapping
if snapState == 1 then cursorPos = reaper.SnapToGrid(0, cursorPos) end

--get minimum fade value
local minFade = tonumber(reaper.GetExtState('extend-trim', 'tailFade'))
if not minFade then minFade = 0 end

--get if the user wants extension to be a thing
local isExtend = true
if reaper.GetExtState('extend-trim', 'isExtend') == 'false' then isExtend = false end

local isTrim = false

--trims item(s)
if editItem then
	isTrim = true

	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	reaper.SetMediaItemSelected(editItem, true)

	local group = reaper.GetMediaItemInfo_Value(editItem, "I_GROUPID")
	if group > 0 and reaper.GetToggleCommandState(1156) == 1 then --trims multiple items if part of a group and "Options: Toggle item grouping override" is enabled
		reaper.Main_OnCommand(40034, 0) --selects all items if the original is part of a group
	end

	itemNum = reaper.CountSelectedMediaItems(0)
	for i = 0, itemNum - 1 do
		local thisItem = reaper.GetSelectedMediaItem(0, i)

		local itemLen = reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")
		local itemEnd = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION") + reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")

		if itemEnd > cursorPos then
			local editDif = itemEnd - cursorPos
			local newLen = itemLen - editDif

			reaper.SetMediaItemInfo_Value(thisItem, "D_LENGTH", newLen)

			--changes the fade length to make sure it isn't lower than a one frame length
			local fadeLen = reaper.GetMediaItemInfo_Value(thisItem, "D_FADEOUTLEN")
			local newFadeLen = fadeLen - editDif
			if newFadeLen < minFade then newFadeLen = minFade end
			reaper.SetMediaItemInfo_Value(thisItem, "D_FADEOUTLEN", newFadeLen)

			--gsets rid of snap offset values
			local snapOffset = reaper.GetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET")
			if snapOffset ~= 0 then
				reaper.SetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET", 0)
			end
		end
	end



--extends item(s)
elseif isExtend then
	local thisTrack = reaper.GetTrackFromPoint(x, y) -- get track under mouse

	--finds the item that you want to edit/gets start position for it
	itemNum = reaper.CountTrackMediaItems(thisTrack)
	for i = 0, itemNum - 1 do
		local thisItem = reaper.GetTrackMediaItem(thisTrack, i)
		local thisEnd = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION") + reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")

		if thisEnd <= cursorPos then
			editItem = thisItem
		else
			break
		end
	end

	--break out of the script in case there are no items (i.e. cursor is after the last item)
	if not editItem then
		reaper.defer(function() end)
		return
	end

	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	reaper.SetMediaItemSelected(editItem, true)

	local group = reaper.GetMediaItemInfo_Value(editItem, "I_GROUPID")
	if group > 0 and reaper.GetToggleCommandState(1156) == 1 then --trims multiple items if part of a group and "Options: Toggle item grouping override" is enabled
		reaper.Main_OnCommand(40034, 0) --selects all items if the original is part of a group
	end

	--runs through all of the items
	itemNum = reaper.CountSelectedMediaItems(0)
	for i = 0, itemNum - 1 do
		local thisItem = reaper.GetSelectedMediaItem(0, i)

		local itemLen = reaper.GetMediaItemInfo_Value(thisItem, "D_LENGTH")
		local itemEnd = reaper.GetMediaItemInfo_Value(thisItem, "D_POSITION") + itemLen

		if itemEnd < cursorPos then
			local editDif = cursorPos - itemEnd
			local newLen = itemLen + editDif

			reaper.SetMediaItemInfo_Value(thisItem, "D_LENGTH", newLen)

			--changes the fade length to make sure it isn't lower than a one frame length
			local fadeLen = reaper.GetMediaItemInfo_Value(thisItem, "D_FADEOUTLEN")
			local newFadeLen = fadeLen + editDif
			if newFadeLen < minFade then newFadeLen = minFade end
			reaper.SetMediaItemInfo_Value(thisItem, "D_FADEOUTLEN", newFadeLen)

			--gets rid of snap offset values
			local snapOffset = reaper.GetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET")
			if snapOffset ~= 0 then
				reaper.SetMediaItemInfo_Value(thisItem, "D_SNAPOFFSET", 0)
			end
		end
	end
end


--gets the frame count that is in 3% of the view  and the markers where it will move the view if edited in them (EXPERIMENT WITH OTHER if you'd like)
local startFrame, endFrame = reaper.GetSet_ArrangeView2(0, false, 0, 0) --gets the frames that are in view

local totalFrame = endFrame - startFrame
local screenPerc = totalFrame * 0.03 --% of the screen you want to account for
local resetEnd = endFrame - screenPerc
local resetStart = startFrame + screenPerc


--moves the screen/frames up if the cursor is wihtin the last (right side) 3% of the screen
if cursorPos > resetEnd then
	local newValue =  cursorPos - (endFrame - screenPerc) --abundance of math is so it shifts the view more if you are closer to the frame limit

	startFrame = startFrame + newValue
	endFrame = endFrame + newValue

	local newStartFrame, newEndFrame = reaper.GetSet_ArrangeView2(0, true, 0, 0, startFrame, endFrame)

--moves the screen/frames down if the cursor is wihtin the beginning (right side) 3% of the screen
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
reaper.UpdateArrange()

if isTrim then reaper.Undo_EndBlock("Trim Tail (Within Bounds)", -1) else reaper.Undo_EndBlock("Extend Tail (Within Bounds)", -1) end