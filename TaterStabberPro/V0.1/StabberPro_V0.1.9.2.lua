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
    local idx = select(1, PopupInput({
      title  = title,
      caller = GetFocusDisplay(),
      items  = {"No", "Yes"}
    })) or def
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

  -- shuffle function
  local function shuffle(tbl)
    local size = #tbl
    for i = size, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
  end

  -- initialize inputs with defaults
  local groupStr = "1"
  local seqNumStr = "201"
  local seqName = "Stabber Recipe"
  local xGroupStr = "0"
  local xBlockStr = "0"
  local xWingsStr = "0"
  local shuffleSeedStr = "0"
  local offCueFade = "0"
  local offCueDelay = "0"
  local presets = {}
  local modes = {"Straight", "Shuffle", "Scatter"}
  local selectedMode = 1

  -- function to build preset list string for display
  local function getPresetsDisplay()
    if #presets == 0 then return "None added" end
    local list = ""
    for i, pr in ipairs(presets) do
      list = list .. pr.pool .. "." .. pr.index
      if i < #presets then list = list .. ", " end
    end
    return list
  end

  -- main menu loop
  while true do
    -- show dialog with inputs and commands
    local box = MessageBox({
      title = "StabberPro LogicTestMode",
      message = "Current Mode: " .. modes[selectedMode] .. "\nCurrent Presets: " .. getPresetsDisplay() .. "\n\nEnter settings below:",
      autoCloseOnInput = false,
      inputs = {
        {name = "Group Number", value = groupStr, vkPlugin = "NumericInput"},
        {name = "Sequence Number", value = seqNumStr, vkPlugin = "NumericInput"},
        {name = "Sequence Name", value = seqName, vkPlugin = "TextInput"},
        {name = "MAtricks XGroup", value = xGroupStr, vkPlugin = "NumericInput"},
        {name = "MAtricks XBlock", value = xBlockStr, vkPlugin = "NumericInput"},
        {name = "MAtricks XWings", value = xWingsStr, vkPlugin = "NumericInput"},
        {name = "Shuffle Seed", value = shuffleSeedStr, vkPlugin = "NumericInput"},
        {name = "OffCue Fade", value = offCueFade, vkPlugin = "TextInput"},
        {name = "OffCue Delay", value = offCueDelay, vkPlugin = "TextInput"}
      },
      commands = {
        {value = 1, name = "Add Presets"},
        {value = 2, name = "Build Sequence"},
        {value = 3, name = "Cancel"},
        {value = 4, name = "Select Mode"}
      }
    })

    if not box.success then
      msg("Dialog closed without selection.")
      return
    end

    -- update variables from inputs
    groupStr = box.inputs["Group Number"]
    seqNumStr = box.inputs["Sequence Number"]
    seqName = box.inputs["Sequence Name"]
    xGroupStr = box.inputs["MAtricks XGroup"]
    xBlockStr = box.inputs["MAtricks XBlock"]
    xWingsStr = box.inputs["MAtricks XWings"]
    shuffleSeedStr = box.inputs["Shuffle Seed"]
    offCueFade = box.inputs["OffCue Fade"]
    offCueDelay = box.inputs["OffCue Delay"]

    -- handle selection
    if box.result == 1 then
      -- add presets loop
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
    elseif box.result == 4 then
      -- select mode
      local currentIdx = selectedMode
      local idx = select(1, PopupInput({
        title = "Select Mode",
        caller = GetFocusDisplay(),
        items = modes,
        selectedValue = currentIdx
      })) or currentIdx
      selectedMode = idx
    elseif box.result == 2 then
      -- validate and build
      if groupStr == "" then err("Group number required."); goto continue_menu end
      local groupNum = toInt(groupStr)
      if not groupNum or groupNum < 1 then err("Invalid group number: " .. tostring(groupStr)); goto continue_menu end
      if not groupSeemsToExist(groupNum) then
        err("Group " .. groupNum .. " does not appear to exist.")
        if not askYesNo("Continue anyway?\n(Recipes will still be created but may not resolve)", false) then
          goto continue_menu
        end
      end

      local seqNum = toInt(seqNumStr)
      if not seqNum or seqNum < 1 then err("Invalid sequence number: " .. tostring(seqNumStr)); goto continue_menu end
      seqName = (seqName ~= "" and seqName) or "Stabber Recipe"

      local xGroup       = toInt(xGroupStr) or 0
      local xBlock       = toInt(xBlockStr) or 0
      local xWings       = toInt(xWingsStr) or 0
      local shuffleSeed  = toInt(shuffleSeedStr) or 0

      if #presets == 0 then
        err("No presets entered. Aborting.")
        goto continue_menu
      end

      -- count fixtures in group
      local function countGroupFixtures(gNum)
        safeCmd("ClearAll")
        safeCmd("Group " .. gNum)
        local count, idx = 0, SelectionFirst()
        while idx do count = count + 1; idx = SelectionNext(idx) end
        safeCmd("ClearAll")
        return count
      end

      -- determine cue count
      local totalCues
      if xGroup > 0 then
        totalCues = xGroup
      else
        local N = countGroupFixtures(groupNum)
        if N < 1 then err("Group " .. groupNum .. " appears empty. Aborting."); goto continue_menu end
        local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
        if perX < 1 then perX = 1 end
        totalCues = math.ceil(N / perX)
      end

      -- protect against overwrite
      if seqExists(seqNum) then
        if not askYesNo(("Sequence %d already exists.\nOverwrite (delete & rebuild)?"):format(seqNum), false) then
          msg("Canceled by user; sequence preserved.")
          goto continue_menu
        end
        if not safeCmd('Delete Sequence ' .. seqNum .. ' /NC') then
          if not safeCmd('Delete Sequence ' .. seqNum) then
            err("Unable to delete existing Sequence " .. seqNum .. ". Aborting.")
            goto continue_menu
          end
        end
      end

      -- create target sequence
      if not safeCmd('Store Sequence ' .. seqNum) then goto continue_menu end
      if not safeCmd('Set Sequence ' .. seqNum .. ' Property "Name" "' .. seqName .. '"') then goto continue_menu end

      -- progress message
      msg(("Building %d cue(s) in Sequence %d \"%s\" using Group %d and %d preset(s)%s"):format(
            totalCues, seqNum, seqName, groupNum, #presets,
            (shuffleSeed > 0) and (" with ShuffleSeed " .. shuffleSeed) or ""))

      -- prepare x_values based on mode
      local x_values = {}
      for i = 1, totalCues do
        x_values[i] = i
      end
      if modes[selectedMode] == "Shuffle" then
        math.randomseed(shuffleSeed > 0 and shuffleSeed or os.time())
        shuffle(x_values)
      elseif modes[selectedMode] == "Scatter" then
        local low, high = 1, totalCues
        local idx = 1
        while low <= high do
          x_values[idx] = low
          idx = idx + 1
          if low ~= high then
            x_values[idx] = high
            idx = idx + 1
          end
          low = low + 1
          high = high - 1
        end
      end

      -- create cues and parts
      for c = 1, totalCues do
        if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c) then goto continue_menu end
        for p = 1, #presets do
          local partStr = "0." .. p
          local pr = presets[p]
          if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then goto continue_menu end
          if not safeCmd('Assign Group ' .. groupNum .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then goto continue_menu end
          if not safeCmd('Assign Preset ' .. pr.pool .. '.' .. pr.index .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then goto continue_menu end
          --if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "Command" "Off Sequence "'.. seqName ..'"') then goto continue_menu end
          if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "X" ' .. x_values[c]) then goto continue_menu end
          if xGroup > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XGroup" ' .. xGroup) then goto continue_menu end end
          if xBlock > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XBlock" ' .. xBlock) then goto continue_menu end end
          if xWings > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XWings" ' .. xWings) then goto continue_menu end end
          if shuffleSeed > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XShuffle" ' .. shuffleSeed) then goto continue_menu end end
        end
      end

      -- finished successfully
      local trueSequName = DataPool().Sequences[seqNum].name -- Makes sure name is correct, incase user has sequences ending in MA3 handed #s.
      safeCmd(string.format('Set Sequence %d Cue * Property "Command" "Off Sequence \'%s\'"',seqNum, trueSequName))
      safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueFade" "\'%s\'"',seqNum, offCueFade))
      safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueDelay" "\'%s\'"',seqNum, offCueDelay))
      msg("Done.")
      break  -- exit after build

    elseif box.result == 3 then
      msg("Canceled.")
      return
    end

    ::continue_menu::
  end
end