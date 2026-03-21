return function()
local group, preset, seqNum, seqName, xGroup, xBlock, xWings, shuffle


local result = MessageBox({
title = "StabberPro Recipe Builder",
message = "Enter your sequence options:",
commands = {
{ name = "OK", value = "ok" },
{ name = "Cancel", value = "cancel" }
},
inputs = {
{ name = "Group", value = "", prompt = "Group Number" },
{ name = "Preset", value = "1.1", prompt = "Preset (e.g. 1.1)" },
{ name = "Sequence", value = "101", prompt = "Sequence Number" },
{ name = "Name", value = "Stab", prompt = "Sequence Name" },
{ name = "XGroup", value = "0", prompt = "MATricks XGroup" },
{ name = "XBlock", value = "0", prompt = "MATricks XBlock" },
{ name = "XWings", value = "0", prompt = "MATricks XWings" },
{ name = "Shuffle", type = "CheckBox", value = false },
}
})


if not result or result == "cancel" then return end


group = tonumber(result.Input.Group)
preset = result.Input.Preset
seqNum = tonumber(result.Input.Sequence)
seqName = result.Input.Name
xGroup = tonumber(result.Input.XGroup)
xBlock = tonumber(result.Input.XBlock)
xWings = tonumber(result.Input.XWings)
shuffle = result.Input.Shuffle


Cmd("Delete Sequence " .. seqNum .. " /nc")
Cmd("Store Sequence " .. seqNum .. " /nc")
Cmd("Label Sequence " .. seqNum .. " \"" .. seqName .. "\"")
Cmd("Assign Sequence " .. seqNum .. " At Page 1.201")
Cmd("ClearAll")


local fixtures = {}
for i = 1, 999 do
local handle = DataPool().Groups[group]
if not handle then return ErrEcho("Invalid Group") end
local count = handle.Count or 0
if count == 0 then return ErrEcho("Empty Group") end
break
end


local steps = xGroup > 0 and xGroup or 1
local cueIndex = 1


for x = 1, steps do
Cmd("ClearAll")
Cmd("Group " .. group)

Cmd("At Preset " .. preset)
Cmd("Store Sequence " .. seqNum .. " Cue " .. cueIndex .. " /nc")
Cmd("Recipe 1")
Cmd("Set Cue " .. cueIndex .. " Property " .. "Recipe.X=" .. x)
cueIndex = cueIndex + 1
end


Cmd("ClearAll")
Echo("[TaterPlugin] Recipe sequence created: Sequence " .. seqNum)
end