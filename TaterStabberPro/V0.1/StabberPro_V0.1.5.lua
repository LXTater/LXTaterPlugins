-- StabberPro - Logic test version. -
-- Adds multi-preset input loop and numeric shuffle seed.
-- Author: Tater MA3 Plugin Assistant V2.0
-- This is a simple logic only version of the plugin to test the core functionality.
-- It does not include error handling!! Use at your own risk. Make backups of your show file first.

return function()
  local function msg(s) Printf("[StabberUI] %s", s) end
  local function err(s) ErrPrintf("[StabberUI] %s", s) end

  -- helpers
  local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end
  local function toInt(s)  s = trim(s); local n = tonumber(s); return n and math.floor(n) or nil end

  -- simple “message box” prompts
  local function askText(title, default)
    local v = TextInput(title, default or "")
    return trim(v or "")
  end

  -- gather core fields
  local groupStr  = askText("Enter Group Number\n(e.g. 1)", "1")
  if groupStr == "" then err("Canceled: Group number required."); return end
  local seqNumStr = askText("Enter Sequence Number\n(pool slot to use)", "201")
  local seqName   = askText("Enter Sequence Name", "Stabber Recipe")

  -- MAtricks
  local xGroupStr = askText("MAtricks XGroup (0 for none)", "0")
  local xBlockStr = askText("MAtricks XBlock (0 for none)", "0")
  local xWingsStr = askText("MAtricks XWings (0 for none)", "0")

  -- Shuffle seed (0 = none)
  local shuffleSeedStr = askText("Shuffle Seed (0 for none)\n(Use an integer for repeatable shuffle)", "0")

  -- Validate numbers
  local groupNum = toInt(groupStr)
  if not groupNum or groupNum < 1 then err("Invalid group number: " .. tostring(groupStr)); return end

  local seqNum = toInt(seqNumStr)
  if not seqNum or seqNum < 1 then err("Invalid sequence number: " .. tostring(seqNumStr)); return end
  seqName = (seqName ~= "" and seqName) or "Stabber Recipe"

  local xGroup = toInt(xGroupStr) or 0
  local xBlock = toInt(xBlockStr) or 0
  local xWings = toInt(xWingsStr) or 0
  local shuffleSeed = toInt(shuffleSeedStr) or 0

  -- preset input loop
  local presets = {}
  while true do
    local prompt = (#presets == 0)
      and "Enter Preset (Pool.Index)\n(e.g. 1.1 or 2.1)\n\nWhen finished adding presets, press Enter on an empty field."
      or  "Enter another Preset (Pool.Index)\n(or press Enter with a blank field to finish)"
    local presetStr = askText(prompt, "")
    if presetStr == "" then break end

    local pool, index = presetStr:match("^(%d+)%.(%d+)$")
    local presetPool  = toInt(pool)
    local presetIndex = toInt(index)
    if presetPool and presetIndex then
      presets[#presets + 1] = { pool = presetPool, index = presetIndex }
      msg(("Added Preset %d.%d"):format(presetPool, presetIndex))
    else
      err("Invalid preset format: \"" .. presetStr .. "\". Use Pool.Index like 1.1")
    end
  end

  if #presets == 0 then
    err("No presets entered. Aborting.")
    return
  end

  -- Utility: count fixtures in group (briefly uses programmer; then clears)
  local function countGroupFixtures(gNum)
    Cmd("ClearAll")
    Cmd("Group " .. gNum)
    local count = 0
    local stabberCueTotalFix = SelectionFirst()
    while stabberCueTotalFix do
      count = count + 1
      stabberCueTotalFix = SelectionNext(stabberCueTotalFix)
    end
    Cmd("ClearAll")
    return count
  end

  --[[Determine cue count
  local totalCues
  if xGroup > 0 then
    totalCues = xGroup
  else
    totalCues = countGroupFixtures(groupNum)
    if totalCues < 1 then
      err("Group " .. groupNum .. " appears empty. Aborting.")
      return
    end
  end
]]

  -- Utility: count fixtures in group (briefly uses programmer; then clears)
  local function countGroupFixtures(gNum)
    Cmd("ClearAll")
    Cmd("Group " .. gNum)
    local count = 0
    local stabberCueTotalFix = SelectionFirst()
    while stabberCueTotalFix do
      count = count + 1
      stabberCueTotalFix = SelectionNext(stabberCueTotalFix)
    end
    Cmd("ClearAll")
    return count
  end

  -- Determine cue count
  local totalCues
  if xGroup > 0 then
    -- explicit XGroup means we want exactly this many cues
    totalCues = xGroup
  else
    local N = countGroupFixtures(groupNum)
    if N < 1 then
      err("Group " .. groupNum .. " appears empty. Aborting.")
      return
    end
    -- Each X position will cover (XBlock * XWings) fixtures.
    local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
    if perX < 1 then perX = 1 end
    totalCues = math.ceil(N / perX)
  end
  -- Prepare target sequence
  Cmd('Store Sequence ' .. seqNum)
  Cmd('Set Sequence ' .. seqNum .. ' Property "Name" "' .. seqName .. '"')

  msg(("Building %d cue(s) in Sequence %d \"%s\" using Group %d and %d preset(s)%s"):format(
      totalCues, seqNum, seqName, groupNum, #presets, (shuffleSeed > 0) and (" with ShuffleSeed " .. shuffleSeed) or ""))

  -- Build cues
  for c = 1, totalCues do
    Cmd('Store Sequence ' .. seqNum .. ' Cue ' .. c)

    -- one recipe part per preset (0.1, 0.2, …)
    for p = 1, #presets do
      local partStr = "0." .. p
      local pr = presets[p]

      Cmd('Store Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr)

      Cmd('Assign Group ' .. groupNum .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr)
      Cmd('Assign Preset ' .. pr.pool .. '.' .. pr.index .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr)

      -- set recipe properties
      Cmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "X" ' .. c)

      if xGroup > 0 then
        Cmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XGroup" ' .. xGroup)
      end
      if xBlock > 0 then
        Cmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XBlock" ' .. xBlock)
      end
      if xWings > 0 then
        Cmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XWings" ' .. xWings)
      end
      if shuffleSeed > 0 then
        -- numeric shuffle seed (per your correction)
        Cmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XShuffle" ' .. shuffleSeed)
      end
    end
  end

  msg("Done.")
end
