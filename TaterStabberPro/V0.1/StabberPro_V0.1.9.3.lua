-- grandMA3 Plugin: StabberPro LogicTestMode
-- Author: LXTater
-- Version: 0.1.6 (2025-09-19)
-- Test and debug only. Backup first.

local plugintable, thiscomponent = select(3, ...)

local presets = {}
local selectedMode = 1
local modes = {"Straight", "Shuffle", "Scatter"}

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

-- add presets function
function plugintable.addPresets(caller)
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
  -- update display
  local dialog = caller.Parent.Parent
  local presetsLabel = dialog:FindRecursive("presetsLabel")
  if presetsLabel then
    presetsLabel.Text = getPresetsDisplay()
  end
end

-- build function
function plugintable.build(caller)
  local dialog = caller.Parent.Parent

  local groupStr = dialog:FindRecursive("groupEdit").Text
  local seqNumStr = dialog:FindRecursive("seqNumEdit").Text
  local seqName = dialog:FindRecursive("seqNameEdit").Text
  local xGroupStr = dialog:FindRecursive("xGroupEdit").Text
  local xBlockStr = dialog:FindRecursive("xBlockEdit").Text
  local xWingsStr = dialog:FindRecursive("xWingsEdit").Text
  local shuffleSeedStr = dialog:FindRecursive("shuffleSeedEdit").Text
  local offCueFade = dialog:FindRecursive("offCueFadeEdit").Text
  local offCueDelay = dialog:FindRecursive("offCueDelayEdit").Text

  if groupStr == "" then err("Group number required."); return end
  local groupNum = toInt(groupStr)
  if not groupNum or groupNum < 1 then err("Invalid group number: " .. tostring(groupStr)); return end
  if not groupSeemsToExist(groupNum) then
    err("Group " .. groupNum .. " does not appear to exist.")
    if not askYesNo("Continue anyway?\n(Recipes will still be created but may not resolve)", false) then
      return
    end
  end

  local seqNum = toInt(seqNumStr)
  if not seqNum or seqNum < 1 then err("Invalid sequence number: " .. tostring(seqNumStr)); return end
  seqName = (seqName ~= "" and seqName) or "Stabber Recipe"

  local xGroup       = toInt(xGroupStr) or 0
  local xBlock       = toInt(xBlockStr) or 0
  local xWings       = toInt(xWingsStr) or 0
  local shuffleSeed  = toInt(shuffleSeedStr) or 0

  if #presets == 0 then
    err("No presets entered. Aborting.")
    return
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
    if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c) then return end
    for p = 1, #presets do
      local partStr = "0." .. p
      local pr = presets[p]
      if not safeCmd('Store Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      if not safeCmd('Assign Group ' .. groupNum .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      if not safeCmd('Assign Preset ' .. pr.pool .. '.' .. pr.index .. ' At Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr) then return end
      --if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "Command" "Off Sequence "'.. seqName ..'"') then return end
      if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "X" ' .. x_values[c]) then return end
      if xGroup > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XGroup" ' .. xGroup) then return end end
      if xBlock > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XBlock" ' .. xBlock) then return end end
      if xWings > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XWings" ' .. xWings) then return end end
      if shuffleSeed > 0 then if not safeCmd('Set Sequence ' .. seqNum .. ' Cue ' .. c .. ' Part ' .. partStr .. ' Property "XShuffle" ' .. shuffleSeed) then return end end
    end
  end

  -- finished successfully
  local trueSequName = DataPool().Sequences[seqNum].name -- Makes sure name is correct, incase user has sequences ending in MA3 handed #s.
  safeCmd(string.format('Set Sequence %d Cue * Property "Command" "Off Sequence \'%s\'"',seqNum, trueSequName))
  safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueFade" "\'%s\'"',seqNum, offCueFade))
  safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueDelay" "\'%s\'"',seqNum, offCueDelay))
  msg("Done.")

  -- close dialog
  dialog:Remove()
end

-- cancel function
function plugintable.cancel(caller)
  local dialog = caller.Parent.Parent
  dialog:Remove()
end

-- mode select functions
function plugintable.straightMode(caller)
  if caller.State == 1 then
    selectedMode = 1
    caller.Parent:FindRecursive("shuffleCheck").State = 0
    caller.Parent:FindRecursive("scatterCheck").State = 0
  end
end

function plugintable.shuffleMode(caller)
  if caller.State == 1 then
    selectedMode = 2
    caller.Parent:FindRecursive("straightCheck").State = 0
    caller.Parent:FindRecursive("scatterCheck").State = 0
  end
end

function plugintable.scatterMode(caller)
  if caller.State == 1 then
    selectedMode = 3
    caller.Parent:FindRecursive("straightCheck").State = 0
    caller.Parent:FindRecursive("shuffleCheck").State = 0
  end
end

-- reset matricks function
function plugintable.resetMatricks(caller)
  local dialog = caller.Parent.Parent
  dialog:FindRecursive("xGroupEdit").Text = "0"
  dialog:FindRecursive("xBlockEdit").Text = "0"
  dialog:FindRecursive("xWingsEdit").Text = "0"
end

return function ()
  -- Get the colors from color themes
  local colorTransparent = Root().ColorTheme.ColorGroups.Global.Transparent
  local colorBackground = Root().ColorTheme.ColorGroups.Button.Background
  local colorBackgroundPlease = Root().ColorTheme.ColorGroups.Button.BackgroundPlease
  local colorPartlySelected = Root().ColorTheme.ColorGroups.Global.PartlySelected
  local colorPartlySelectedPreset = Root().ColorTheme.ColorGroups.Global.PartlySelectedPreset
  local colorBlack = Root().ColorTheme.ColorGroups.Global.Transparent
  -- MAtricks colors
  local colorXMAtricks = Root().ColorTheme.ColorGroups.MATricks.BackgroundX
  -- Value colors
  local colorFadeValue = Root().ColorTheme.ColorGroups.ProgLayer.Fade
  local colorDelayValue = Root().ColorTheme.ColorGroups.ProgLayer.Delay

  local display = GetFocusDisplay()
  local screenOverlay = display.ScreenOverlay

  -- Delete any UI elements currently displayed on the overlay.
  screenOverlay:ClearUIChildren()

  local dialogWidth = 1200
  local baseInput = screenOverlay:Append('BaseInput')
  baseInput.Name = "StabberPro"
  baseInput.H = "0"
  baseInput.W = dialogWidth
  baseInput.MaxSize = string.format("%s,%s", display.W * 0.8, display.H)
  baseInput.MinSize = string.format("%s,0", dialogWidth - 100)
  baseInput.Columns = 1
  baseInput.Rows = 2
  baseInput[1][1].SizePolicy = "Fixed"
  baseInput[1][1].Size = "80"
  baseInput[1][2].SizePolicy = "Stretch"
  baseInput.AutoClose = "No"
  baseInput.CloseOnEscape = "Yes"

  -- Create the title bar.
  local titleBar = baseInput:Append("TitleBar")
  titleBar.Columns = 2
  titleBar.Rows = 1
  titleBar.Anchors = "0,0"
  titleBar[2][2].SizePolicy = "Fixed"
  titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"

  local titleBarIcon = titleBar:Append("TitleButton")
  titleBarIcon.Text = "StabberPro LogicTestMode"
  titleBarIcon.Texture = "corner1"
  titleBarIcon.Anchors = "0,0"
  titleBarIcon.Icon = "star"

  local titleBarCloseButton = titleBar:Append("CloseButton")
  titleBarCloseButton.Anchors = "1,0"
  titleBarCloseButton.Texture = "corner2"
  titleBarCloseButton.PluginComponent = thiscomponent
  titleBarCloseButton.Clicked = 'cancel'

  -- Create the dialog's main frame.
  local dlgFrame = baseInput:Append("DialogFrame")
  dlgFrame.H = "100%"
  dlgFrame.W = "100%"
  dlgFrame.Columns = 1
  dlgFrame.Rows = 3
  dlgFrame.Anchors = {
    left = 0,
    right = 0,
    top = 1,
    bottom = 1
  }
  -- subtitle row
  dlgFrame[1][1].SizePolicy = "Fixed"
  dlgFrame[1][1].Size = "60"
  -- main grid row
  dlgFrame[1][2].SizePolicy = "Fixed"
  dlgFrame[1][2].Size = "400"
  -- button row
  dlgFrame[1][3].SizePolicy = "Fixed"
  dlgFrame[1][3].Size = "80"

  -- Create the sub title.
  local subTitle = dlgFrame:Append("UIObject")
  subTitle.Text = "Set Parameters for Stabber Recipe"
  subTitle.ContentDriven = "Yes"
  subTitle.ContentWidth = "No"
  subTitle.TextAutoAdjust = "No"
  subTitle.Anchors = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0
  }
  subTitle.Padding = {
    left = 20,
    right = 20,
    top = 15,
    bottom = 15
  }
  subTitle.Font = "Medium20"
  subTitle.HasHover = "No"
  subTitle.BackColor = colorBlack

  -- Create the inputs grid.
  local inputsGrid = dlgFrame:Append("UILayoutGrid")
  inputsGrid.Columns = 10
  inputsGrid.Rows = 5
  inputsGrid.Anchors = {
    left = 0,
    right = 0,
    top = 1,
    bottom = 1
  }
  inputsGrid.Margin = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 5
  }
  inputsGrid.BackColor = colorTransparent

  local inputMargins = {
    left = 0,
    right = 10,
    top = 0,
    bottom = 20
  }

  -- Group Number
  local label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '0,0'
  label.Text = "Group Number:"

  local edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '1,0'
  edit.Name = "groupEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "1"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"

  -- Sequence Number
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '2,0'
  label.Text = "Sequence Number:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '3,0'
  edit.Name = "seqNumEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "201"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"

  -- Sequence Name
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '4,0'
  label.Text = "Sequence Name:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '5,0,9,0'
  edit.Name = "seqNameEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.VkPluginName = "TextInput"
  edit.Content = "Stabber Recipe"
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"

  -- Modes Checkboxes
  local straightCheck = inputsGrid:Append("CheckBox")
  straightCheck.Margin = inputMargins
  straightCheck.Anchors = {
    left = 0,
    right = 1,
    top = 1,
    bottom = 1
  }
  straightCheck.Name = "straightCheck"
  straightCheck.Text = "Straight"
  straightCheck.TextalignmentH = "Center"
  straightCheck.State = 1
  straightCheck.Padding = '5,5'
  straightCheck.PluginComponent = thiscomponent
  straightCheck.Clicked = "straightMode"
  straightCheck.BackColor = colorPartlySelected

  local shuffleCheck = inputsGrid:Append("CheckBox")
  shuffleCheck.Margin = inputMargins
  shuffleCheck.Anchors = {
    left = 2,
    right = 3,
    top = 1,
    bottom = 1
  }
  shuffleCheck.Name = "shuffleCheck"
  shuffleCheck.Text = "Shuffle"
  shuffleCheck.TextalignmentH = "Center"
  shuffleCheck.State = 0
  shuffleCheck.Padding = '5,5'
  shuffleCheck.PluginComponent = thiscomponent
  shuffleCheck.Clicked = "shuffleMode"
  shuffleCheck.BackColor = colorPartlySelected

  local scatterCheck = inputsGrid:Append("CheckBox")
  scatterCheck.Margin = inputMargins
  scatterCheck.Anchors = {
    left = 4,
    right = 5,
    top = 1,
    bottom = 1
  }
  scatterCheck.Name = "scatterCheck"
  scatterCheck.Text = "Scatter"
  scatterCheck.TextalignmentH = "Center"
  scatterCheck.State = 0
  scatterCheck.Padding = '5,5'
  scatterCheck.PluginComponent = thiscomponent
  scatterCheck.Clicked = "scatterMode"
  scatterCheck.BackColor = colorPartlySelected

  -- Shuffle Seed
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '6,1'
  label.Text = "Shuffle Seed:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '7,1,9,1'
  edit.Name = "shuffleSeedEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"

  -- MAtricks XGroup
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '0,2'
  label.Text = "MAtricks XGroup:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '1,2'
  edit.Name = "xGroupEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"
  edit.BackColor = colorXMAtricks

  -- MAtricks XBlock
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '2,2'
  label.Text = "MAtricks XBlock:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '3,2'
  edit.Name = "xBlockEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"
  edit.BackColor = colorXMAtricks

  -- MAtricks XWings
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '4,2'
  label.Text = "MAtricks XWings:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '5,2'
  edit.Name = "xWingsEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = "0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"
  edit.BackColor = colorXMAtricks

  -- Reset MAtricks
  local resetButton = inputsGrid:Append("Button")
  resetButton.Margin = inputMargins
  resetButton.Anchors = {
    left = 6,
    right = 9,
    top = 2,
    bottom = 2
  }
  resetButton.Text = "Reset MAtricks"
  resetButton.TextalignmentH = "Center"
  resetButton.Padding = "5,5"
  resetButton.PluginComponent = thiscomponent
  resetButton.Clicked = "resetMatricks"

  -- OffCue Fade
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '0,3'
  label.Text = "OffCue Fade:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '1,3,3,3'
  edit.Name = "offCueFadeEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = ".0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"
  edit.BackColor = colorFadeValue

  -- OffCue Delay
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '4,3'
  label.Text = "OffCue Delay:"

  edit = inputsGrid:Append('LineEdit')
  edit.Margin = inputMargins
  edit.Anchors = '5,3,9,3'
  edit.Name = "offCueDelayEdit"
  edit.Prompt = ""
  edit.TextAutoAdjust = "Yes"
  edit.Filter = ".0123456789"
  edit.VkPluginName = "TextInputNumOnly"
  edit.Content = "0"
  edit.MaxTextLength = 6
  edit.HideFocusFrame = "Yes"
  edit.Padding = "5,5"
  edit.BackColor = colorDelayValue

  -- Presets
  label = inputsGrid:Append('Label')
  label.Margin = inputMargins
  label.Anchors = '0,4'
  label.Text = "Presets:"

  local presetsLabel = inputsGrid:Append('Label')
  presetsLabel.Margin = inputMargins
  presetsLabel.Anchors = '1,4,7,4'
  presetsLabel.Name = "presetsLabel"
  presetsLabel.Text = getPresetsDisplay()
  presetsLabel.HasHover = "No"

  -- Add Presets Button
  local addPresetsButton = inputsGrid:Append('Button')
  addPresetsButton.Margin = inputMargins
  addPresetsButton.Anchors = '8,4,9,4'
  addPresetsButton.Text = "Add Presets"
  addPresetsButton.TextalignmentH = "Center"
  addPresetsButton.Padding = "5,5"
  addPresetsButton.PluginComponent = thiscomponent
  addPresetsButton.Clicked = 'addPresets'

  -- Create the button grid.
  local buttonGrid = dlgFrame:Append("UILayoutGrid")
  buttonGrid.Columns = 2
  buttonGrid.Rows = 1
  buttonGrid.Anchors = {
    left = 0,
    right = 0,
    top = 2,
    bottom = 2
  }

  local buildButton = buttonGrid:Append('Button')
  buildButton.Anchors = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0
  }
  buildButton.Textshadow = 1
  buildButton.HasHover = "Yes"
  buildButton.Text = "Build Sequence"
  buildButton.Font = "Medium20"
  buildButton.TextalignmentH = "Centre"
  buildButton.PluginComponent = thiscomponent
  buildButton.Clicked = 'build'

  local cancelButton = buttonGrid:Append('Button')
  cancelButton.Anchors = {
    left = 1,
    right = 1,
    top = 0,
    bottom = 0
  }
  cancelButton.Textshadow = 1
  cancelButton.HasHover = "Yes"
  cancelButton.Text = "Cancel"
  cancelButton.Font = "Medium20"
  cancelButton.TextalignmentH = "Centre"
  cancelButton.PluginComponent = thiscomponent
  cancelButton.Clicked = 'cancel'
  cancelButton.Visible = "Yes"
end