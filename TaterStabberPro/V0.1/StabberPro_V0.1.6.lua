-- grandMA3 Plugin: StabberPro LogicTestMode
-- Author: LXTater
-- Version: 0.1.6 (2025-09-19)
-- Test and debug only. Backup first.

return function()
  -- print info messages
  local function msg(s) Printf("[StabberUI] %s", s) end
  -- print error messages
  local function err(s) ErrPrintf("[StabberUI] %s", s) end

  -- trim whitespace from strings
  local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
  -- convert string to integer
  local function toInt(s) s = trim(s); local n = tonumber(s); return n and math.floor(n) or nil end

  -- run MA command safely
  local function safeCmd(s)
    local ok, why = pcall(Cmd, s)
    if not ok then err("Cmd failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  -- ask for text input
  local function askText(title, default)
    local v = TextInput(title, default or "")
    return trim(v or "")
  end

  -- ask yes or no
  local function askYesNo(title, defaultYes)
    local def = defaultYes and 2 or 1
    local idx = tonumber(select(1, PopupInput({
      title  = title,
      caller = GetFocusDisplay(),
      items  = {"No", "Yes"}
    }))) or def
    return (idx == 2)
  end

  -- check if sequence exists
  local function seqExists(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Sequences then return false end
    return dp.Sequences[num] ~= nil
  end

  -- check if group seems present
  local function groupSeemsToExist(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Groups then return true end
    return dp.Groups[num] ~= nil
  end

  -- check if preset seems present
  local function presetSeemsToExist(poolIdx, presetIdx)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.PresetPools then return true end
    local pool = dp.PresetPools[poolIdx]
    if not pool then return false end
    local ok2, child = pcall(function() return pool[presetIdx] end)
    if ok2 and child ~= nil then return true end
    return true
  end

  -- gather core inputs
  local groupStr  = askText("Enter Group Number\n(e.g. 1)", "1")
  if groupStr == "" then err("Canceled: Group number required."); return end
  local seqNumStr = askText("Enter Sequence Number\n(pool slot to use)", "201")
  local seqName   = askText("Enter Sequence Name", "Stabber Recipe")

  -- gather MAtricks inputs
  local xGroupStr = askText("MAtricks XGroup (0 for none)", "0")
  local xBlockStr = askText("MAtricks XBlock (0 for none)", "0")
  local xWingsStr = askText("MAtricks XWings (0 for none)", "0")

  -- gather shuffle seed
  local shuffleSeedStr = askText("Shuffle Seed (0 for none)\n(Use an integer for repeatable shuffle)", "0")

  -- validate numeric inputs
  local groupNum = toInt(groupStr)
  if not groupNum or groupNum < 1 then err("Invalid group number: " .. tostring(groupStr)); return end
  if not groupSeemsToExist(groupNum) then
    err("Group " .. groupNum .. " does not appear to exist.")
    if not askYesNo("Continue anyway?\n(Recipes will still be created but may not resolve)", false) then
      return
    end
  end

  -- parse sequence and names
  local seqNum = toInt(seqNumStr)
  if not seqNum or seqNum < 1 then err("Invalid sequence number: " .. tostring(seqNumStr)); return end
  seqName = (seqName ~= "" and seqName) or "Stabber Recipe"

  -- parse MAtricks values
  local xGroup       = toInt(xGroupStr) or 0
  local xBlock       = toInt(xBlockStr) or 0
  local xWings       = toInt(xWingsStr) or 0
  local shuffleSeed  = toInt(shuffleSeedStr) or 0

  -- count fixtures in group
  local function countGroupFixtures(gNum)
    safeCmd("ClearAll")
    safeCmd("Group " .. gNum)
    local count, idx = 0, SelectionFirst()
    while idx do count = count + 1; idx = SelectionNext(idx) end
    safeCmd("ClearAll")
    return count
  end

  -- build preset list
  local presets = {}
  while true do
    local prompt =
      (#presets == 0)
        and "Enter Preset (Pool.Index)\n(e.g. 1.1 or 2.1)\n\nWhen finished adding presets, press Enter on an empty field."
        or  "Enter another Preset (Pool.Index)\n(or press Enter with a blank field to finish)"
    local presetStr = askText(prompt, "")
    if presetStr == "" then break end

    local poolStr, idxStr = presetStr:match("^(%d+)%.(%d+)$")
    local presetPool      = toInt(poolStr)
    local presetIndex     = toInt(idxStr)

    if presetPool and presetIndex then
      if not presetSeemsToExist(presetPool, presetIndex) then
        if not askYesNo(("Preset %d.%d not found.\nAdd anyway?"):format(presetPool, presetIndex), false) then
          goto continue_preset
        end
      end
      presets[#presets + 1] = { pool = presetPool, index = presetIndex }
      msg(("Added Preset %d.%d"):format(presetPool, presetIndex))
    else
      err('Invalid preset format: "' .. presetStr .. '"\nUse Pool.Index like 1.1')
    end
    ::continue_preset::
  end

  -- ensure at least one preset
  if #presets == 0 then
    err("No presets entered. Aborting.")
    return
  end

  -- determine cue count
  local totalCues
  if xGroup > 0 then
    totalCues = xGroup
  else
    local N = countGroupFixtures(groupNum)
    if N < 1 then err("Group " .. groupNum .. " appears empty. Aborting."); return end
    local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
    if perX < 1 then perX = 1 end
    totalCues = math.ceil(N / perX)
  end

  -- protect against overwrite
  if seqExists(seqNum) then
    if not askYesNo(("Sequence %d already exists.\nOverwrite (delete & rebuild)?"):format(seqNum), false) then
      msg("Canceled by user; sequence preserved.")
      return
    end
    if not safeCmd('Delete Sequence ' .. seqNum .. ' /NC') then
      if not safeCmd('Delete Sequence ' .. seqNum) then
        err("Unable to delete existing Sequence " .. seqNum .. ". Aborting.")
        return
      end
    end
  end

  -- create target sequence
  if not safeCmd('Store Sequence ' .. seqNum) then return end
  if not safeCmd('Set Sequence ' .. seqNum .. ' Property "Name" "' .. seqName .. '"') then return end

  -- progress message
  msg(("Building %d cue(s) in Sequence %d \"%s\" using Group %d and %d preset(s)%s"):format(
        totalCues, seqNum, seqName, groupNum, #presets,
        (shuffleSeed > 0) and (" with ShuffleSeed " .. shuffleSeed) or ""))

  -- create cues and parts
  for c = 1, totalCues do
    if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c) then return end
    for p = 1, #presets do
      local partStr = "0." .. p
      local pr = presets[p]
      if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      if not safeCmd('Assign Group ' .. groupNum .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      if not safeCmd('Assign Preset ' .. pr.pool .. '.' .. pr.index .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      --if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "Command" "Off Sequence "'.. seqName ..'"') then return end
      if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "X" ' .. c) then return end
      if xGroup > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XGroup" ' .. xGroup) then return end end
      if xBlock > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XBlock" ' .. xBlock) then return end end
      if xWings > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XWings" ' .. xWings) then return end end
      if shuffleSeed > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XShuffle" ' .. shuffleSeed) then return end end
    end
  end

  -- finished successfully

  local trueSequName = DataPool().Sequences[seqNum].name -- Makes sure name is correct, incase user has sequences ending in MA3 handed #s.
  safeCmd(string.format('Set Sequence %d Cue * Property "Command" "Off Sequence \'%s\'"',seqNum, trueSequName))
  msg("Done.")
end