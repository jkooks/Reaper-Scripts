--This script sorts all selected items equally in the time selection


function Msg(...)
	local message = ""

	for i = 1, select("#", ...) do
		message = message .. tostring(select(i, ...)) .. "\n"
	end

	reaper.ShowConsoleMsg(message)

	return message
end


--sorts the array given to it by whatever key value you provide
function SortTableByKey(temp_array, key)

	local item_count = #temp_array
	local has_changed

	repeat
		has_changed = false
		item_count = item_count - 1

		for i = 1, item_count do
			if temp_array[i][key] > temp_array[i + 1][key] then
				temp_array[i], temp_array[i + 1] = temp_array[i + 1], temp_array[i]
				has_changed = true
			end
		end
	until has_changed == false

	return temp_array
end


function InTable(item, temp_table)
	for i, info in ipairs(temp_table) do
		if info["item"] == item then
			return true
		end
	end

	return false
end





function Main()

	local reposition_group = true --set to true if you want grouped items to move to (as long as they aren't also selected)
	local keep_offset = false --set to true if you want grouped item's positional offset to be the same

	local total_len = 0

	local items = {}
	for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)

		local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

		total_len = total_len + length

		table.insert(items, {item=item, length=length, position=position})
	end

	if #items <= 1 then
		-- reaper.defer(function() end)
		return false
	end

	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)

	items = SortTableByKey(items, "position")

	local start_position, end_position = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

	if start_position == end_position then
		start_position = nil
		end_position = nil
	end

	if not start_position then start_position = items[1]["position"] end
	if not end_position then end_position = items[#items]["position"] + items[#items]["length"] end

	local time = end_position - start_position - total_len
	local offset = time / (#items - 1)

	local position = start_position

	for i, info in ipairs(items) do
		reaper.SetMediaItemInfo_Value(info["item"], "D_POSITION", position)
		
		info["new_position"] = position

		position = position + info["length"] + offset
	end


	--reposition any grouped items if you want it to
	if reposition_group then
		local groups = {}

		for i = 0, reaper.CountMediaItems(0) - 1 do
			local item = reaper.GetMediaItem(0, i)
			local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")

			if group_id > 0 then
				if not groups[group_id] then groups[group_id] = {} end
				table.insert(groups[group_id], item)
			end
		end

		for i, info in ipairs(items) do
			local group_id = reaper.GetMediaItemInfo_Value(info["item"], "I_GROUPID")

			if group_id > 0 and groups[group_id] then
				for j, group_item in ipairs(groups[group_id]) do
					local new_position = info["new_position"]

					if info["item"] ~= group_item and not InTable(group_item, items) then
						if keep_offset then
							new_position = new_position - (info["position"] - reaper.GetMediaItemInfo_Value(group_item, "D_POSITION"))
						end

						reaper.SetMediaItemInfo_Value(group_item, "D_POSITION", new_position)
					end
				end
			end
		end
	end

	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()

	reaper.Undo_EndBlock("Reposition Items Equally In Time Selection", -1)

	return true
end


Main()