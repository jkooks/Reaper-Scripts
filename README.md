# Reaper-Scripts
A number of standalone tools and scripts that I have made for use in Reaper. All scripts should be able to be loaded into Reaper and then they should just work - no additional steps needed.


### Items

##### Extend-Trim
These scripts are meant to be used when editing the tops and tails of files. Hovering over the item itself will allow you to cut into that item, whereas hovering over an empty part of the track will cause the top/tail to extend to the mouse cursor (depending on which script is being used).
The difference between the versions are mainly that the "No Fade" version doesn't adjust the fade length when editing the item, so it just changes position but not length.

The various options for this script are in the Extend-Trim Options.lua script, and can be run in Reaper to be set. The options are as follows:
	Minimum top fade length (number) = makes sure that the top fade length doesn't go below this value (in seconds). Default is 0 seconds.
	Minimum tail fade length (number) = makes sure that the tail fade length doesn't go below this value (in seconds). Default is 0 seconds.
	Extend Allowed (boolean) = allows the tool to extend an item when run over an empty portion of the track. Default is true. 

##### Reposition Items Equally In Time Selection
This script is meant to sort all items equally in the given time selection.

### Tracks

##### Smart Track Creator
This script is used to make a track at any depth level after the selected track. The following are instructions to use this tool, and they are also in the script if you need a refresher on how to use it.

###### Situations
If no tracks is selected = create a track at the end of the track count
If one track is selected:
	If it is a "base level track" (i.e. not parented) = create another base level track
	If it is the end of a folder = create a base level track/normal track within the overarching folder structure (if there is one)
	If it is within a folder structure = create another track within that structure
If multiple tracks selected:
	If the last track selected is the end of the folder structure:
		If the first track selected is within the same folder structure/the parent of it = create a track and make it the new end of that structure
		If the first track is a "grandparent"/part of an overarching folder structure = create a track and make it the end of that folder if there isn't one already
		Otherwise add it as a base level track
	If it is not the end of the folder structure = create a track within that folder
