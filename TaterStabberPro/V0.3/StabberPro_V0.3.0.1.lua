-- grandMA3 Plugin: StabberPro LogicTestMode (dlgframe UI)
-- Author: LXTater
-- Version: 0.3.0.0
-- NOTE: Test and debug only. Backup your showfile first!

local pluginName, componentName, signalTable, myHandle = select(1, ...)

return function()
  ------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------
  local function msg(s)        Printf("[StabberUI] %s", s) end
  local function err(s)        ErrPrintf("[StabberUI] %s", s) end
  local function trim(s)       return (tostring(s or ""):gsub("^%s+"," "):gsub("%s+$"," ")) end
  local function toInt(s)      s = trim(s); local n = tonumber(s); return n and math.floor(n) or nil end

  local function safeCmd(s)
    local ok, why = pcall(Cmd, s)
    if not ok then err("Cmd failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  local function seqExists(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Sequences then return false end
    return dp.Sequences[num] ~= nil
  end

  local function groupSeemsToExist(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Groups then return true end
    return dp.Groups[num] ~= nil
  end

  local function presetSeemsToExist(poolIdx, presetIdx)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.PresetPools then return true end
    local pool = dp.PresetPools[poolIdx]
    if not pool then return false end
    local ok2, child = pcall(function() return pool[presetIdx] end)
    if ok2 and child ~= nil then return true end
    return true
  end

  local function shuffle(tbl)
    for i = #tbl, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
  end

  local function countGroupFixtures(gNum)
    safeCmd("ClearAll")
    safeCmd("Group " .. gNum)
    local count, idx = 0, SelectionFirst()
    while idx do count = count + 1; idx = SelectionNext(idx) end
    safeCmd("ClearAll")
    return count
  end

  ------------------------------------------------------------
  -- Model (state)
  ------------------------------------------------------------
  local state = {
    groupStr       = "1",
    seqNumStr      = "201",
    seqName        = "Stabber Recipe",
    xGroupStr      = "0",
    xBlockStr      = "0",
    xWingsStr      = "0",
    shuffleSeedStr = "0",
    offCueFade     = "0",
    offCueDelay    = "0",
    presets        = {},       -- { {pool=<n>, index=<n>} ... }
    modes          = {"Straight","Shuffle","Scatter"},
    selectedMode   = 1,
  }

  local function presetsDisplay()
    if #state.presets == 0 then return "None" end
    local buf = {}
    for i, pr in ipairs(state.presets) do
      buf[#buf+1] = (pr.pool .. "." .. pr.index)
    end
    return table.concat(buf, ", ")
  end

  ------------------------------------------------------------
  -- UI setup
  ------------------------------------------------------------
  -- Resolve target display
  local displayIndex = Obj.Index(GetFocusDisplay())
  if displayIndex > 5 then displayIndex = 1 end
  local display = GetDisplayByIndex(displayIndex)
  if not display or not display.W or not display.H then
    Echo("Warning: Invalid display dimensions, using defaults.")
    display = { W = 1920, H = 1080 }
  end
  local screenOverlay = display.ScreenOverlay
  screenOverlay:ClearUIChildren()

  -- Colors
  local CT = Root().ColorTheme.ColorGroups
  local colorTransparent     = CT.Global.Transparent
  local colorButtonPlease    = CT.Button.BackgroundPlease
  local colorFadeValue       = CT.ProgLayer.Fade
  local colorDelayValue      = CT.ProgLayer.Delay
  local colorMATx            = CT.MATricks.BackgroundX

  -- Base window
  local dialogWidth = math.floor(display.W * 0.75)
  local baseInput = screenOverlay:Append("BaseInput")
  baseInput.Name = "StabberProDlg"
  baseInput.W = dialogWidth
  baseInput.H = 0
  baseInput.MaxSize = string.format("%d,%d", math.floor(display.W*0.9), display.H)
  baseInput.MinSize = string.format("%d,0", math.max(1000, dialogWidth-200))
  baseInput.Columns = 1
  baseInput.Rows = 2
  baseInput[1][1].SizePolicy = "Fixed";   baseInput[1][1].Size = "80"
  baseInput[1][2].SizePolicy = "Stretch"
  baseInput.AutoClose = "No"
  baseInput.CloseOnEscape = "Yes"

  -- TitleBar
  local titleBar = baseInput:Append("TitleBar")
  titleBar.Columns = 10; titleBar.Rows = 1
  titleBar[2][2].SizePolicy = "Fixed"; titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"

  local titleIcon = titleBar:Append("TitleButton")
  titleIcon.Text = "StabberPro – LogicTestMode"
  titleIcon.Texture = "corner1"; titleIcon.Icon = "star"
  --titleIcon.Anchors = "1,0"

  local titleClose = titleBar:Append("CloseButton")
  titleClose.Anchors = "9,0"

  local titleSettings = titleBar:Append("Button")
  titleSettings.Icon = "settings"
  titleSettings.Anchors = "8,0"
  titleSettings.PluginComponent= "myHandle"
  titleSettings.Clicked = "OnOpenSettings"
  -- Frame grid
  local dlg = baseInput:Append("DialogFrame")
  dlg.W = "100%"; dlg.H = "100%"
  dlg.Columns = 1; dlg.Rows = 3
  dlg[1][1].SizePolicy = "Fixed";  dlg[1][1].Size = "60"     -- subtitle
  dlg[1][2].SizePolicy = "Fixed";  dlg[1][2].Size = "420"    -- main
  dlg[1][3].SizePolicy = "Fixed";  dlg[1][3].Size = "80"     -- buttons

  -- Subtitle
  local sub = dlg:Append("UIObject")
  sub.Text = "Configure Stabber Recipe builder"
  sub.Font = "Medium20"; sub.HasHover = "No"; sub.BackColor = colorTransparent
  sub.Padding = {left=20,right=20,top=15,bottom=15}
  sub.Anchors = {left=0,right=0,top=0,bottom=0}

  -- Main: two-column grid
  local main = dlg:Append("UILayoutGrid"); main.Columns = 2; main.Rows = 1
  main.BackColor = colorTransparent
  main.Anchors = {left=0,right=0,top=1,bottom=1}

  ------------------------------------------------------------
  -- Left Side: Group + Settings form
  ------------------------------------------------------------
  local form = main:Append("UILayoutGrid")
  form.Columns = 4; form.Rows = 6
  form.BackColor = colorTransparent
  form.Anchors = {left=0,right=0,top=0,bottom=0}

  local function mkLabel(txt, l, r, t, b)
    local o = form:Append("UIObject")
    o.Text = txt; o.TextalignmentH = "Right"; o.Font = "Medium20"; o.HasHover = "No"
    o.Anchors = {left=l,right=r,top=t,bottom=b}
    return o
  end
  local function mkLine(prompt, content, key, l, r, t, b, numeric, bg)
    mkLabel(prompt, l, l, t, b)
    local e = form:Append("LineEdit")
    e.Content = content or ""
    e.TextAutoAdjust = "Yes"
    e.Anchors = {left=l+1,right=r,top=t,bottom=b}
    e.Padding = "4,4"; e.MaxTextLength = 32; e.HideFocusFrame = "Yes"
    if numeric then e.Filter = "0123456789"; e.VkPluginName = "TextInputNumOnly" end
    if bg then e.BackColor = bg end
    e.PluginComponent = myHandle
    e.TextChanged = key
    return e
  end

  -- Row 1: Group, Seq #
  mkLabel("Group", 0,0,0,0)
  local bGroup = form:Append("Button")
  bGroup.Anchors={left=1,right=1,top=0,bottom=0}
  bGroup.Text = (state.groupStr~="" and ("Group"..state.groupStr)) or "Select Group"
  bGroup.PluginComponent=myHandle; bGroup.Clicked="OnOpenGroupPicker"
  bGroup.BackColor = colorButtonPlease; bGroup.TextalignmentH = "Center"

  mkLine("Sequence #",   state.seqNumStr,      "OnSeqNumChanged",      2,4,0,0, true)
  -- Row 2: Sequence Name (spans two)
  mkLabel("Sequence Name", 0,0,1,1)
  local eSeqName = form:Append("LineEdit"); eSeqName.Anchors={left=1,right=4,top=1,bottom=1}
  eSeqName.Content = state.seqName; eSeqName.TextAutoAdjust="Yes"; eSeqName.PluginComponent=myHandle; eSeqName.TextChanged="OnSeqNameChanged"; eSeqName.TextalignmentH = "Left"

  -- Row 3: MAtricks XGroup/XBlock
  mkLine("XGroup",       state.xGroupStr,      "OnXGroupChanged",      0,2,2,2, true, colorMATx)
  mkLine("XBlock",       state.xBlockStr,      "OnXBlockChanged",      2,4,2,2, true, colorMATx)
  -- Row 4: XWings / Shuffle Seed
  mkLine("XWings",       state.xWingsStr,      "OnXWingsChanged",      0,2,3,3, true, colorMATx)
  mkLine("Shuffle Seed", state.shuffleSeedStr, "OnShuffleSeedChanged", 2,4,3,3, true)
  -- Row 5: OffCue Fade / Delay
  mkLine("OffCue Fade",  state.offCueFade,     "OnOffFadeChanged",     0,2,4,4, false, colorFadeValue)
  mkLine("OffCue Delay", state.offCueDelay,    "OnOffDelayChanged",    2,4,4,4, false, colorDelayValue)

  -- Row 6: Mode selector
  mkLabel("Mode", 0,0,5,5)
  local mStraight = form:Append("CheckBox"); mStraight.Text="Straight"; mStraight.State=1; mStraight.Anchors={left=1,right=1,top=5,bottom=5}; mStraight.PluginComponent=myHandle; mStraight.Clicked="OnModeStraight"
  local mShuffle  = form:Append("CheckBox"); mShuffle.Text ="Shuffle" ; mShuffle.State=0; mShuffle.Anchors={left=2,right=2,top=5,bottom=5};  mShuffle.PluginComponent=myHandle;  mShuffle.Clicked ="OnModeShuffle"
  local mScatter  = form:Append("CheckBox"); mScatter.Text ="Scatter" ; mScatter.State=0; mScatter.Anchors={left=3,right=3,top=5,bottom=5};  mScatter.PluginComponent=myHandle;  mScatter.Clicked ="OnModeScatter"

  ------------------------------------------------------------
  -- Right Side: Preset Manager + status
  ------------------------------------------------------------
  local right = main:Append("UILayoutGrid"); right.Columns = 2; right.Rows = 6
  right.BackColor = colorTransparent
  right.Anchors = {left=1,right=1,top=0,bottom=0}

  -- Preset entry + picker row
  local pEntry = right:Append("LineEdit")
  pEntry.Anchors = {left=0,right=2,top=0,bottom=0}; pEntry.Content = ""; pEntry.MaxTextLength = 16; pEntry.VkPluginName = "TextInput"; pEntry.PluginComponent = myHandle
  local pickRow = right:Append("UILayoutGrid"); pickRow.Columns=2; pickRow.Rows=1; pickRow.Anchors={left=0,right=2,top=1,bottom=1}
  local pPick = pickRow:Append("Button"); pPick.Text = "Pick…"; pPick.PluginComponent=myHandle; pPick.Clicked="OnOpenPresetPicker"; pPick.Anchors={left=0,right=0,top=0,bottom=0}
  local pAdd  = pickRow:Append("Button"); pAdd.Text = "+ Add"; pAdd.PluginComponent = myHandle; pAdd.Clicked = "OnPresetAdd"; pAdd.Anchors={left=1,right=1,top=0,bottom=0}

  -- Preset list display (read-only Button for wrapped text)
  local pList = right:Append("Button")
  pList.Anchors = {left=0,right=2,top=2,bottom=3}; pList.HasHover = "No"; pList.TextalignmentH = "Left"
  pList.Text = "Presets: " .. presetsDisplay(); pList.Padding = "8,8"

  -- Clear presets
  local pClear = right:Append("Button")
  pClear.Anchors = {left=1,right=1,top=4,bottom=4}; pClear.Text = "Clear Presets"; pClear.PluginComponent = myHandle; pClear.Clicked = "OnPresetClear"

  -- Edit Sequ Dialoge Setting
    local sEditSequ = form:Append("CheckBox"); sEditSequ.Text="Straight"; sEditSequ.State=1; sEditSequ.Anchors={left=1,right=1,top=5,bottom=5}; sEditSequ.PluginComponent=myHandle; sEditSequ.Clicked="OnEditSequ"


  -- Status / preview
  local status = right:Append("Button")
  status.Anchors = {left=1,right=0,top=4,bottom=4}; status.HasHover = "No"; status.TextalignmentH = "Left"; status.Text = "Ready"

  -- Expected cue count preview
  local cuePreview = right:Append("Button")
  cuePreview.Anchors = {left=0,right=2,top=4,bottom=4}; cuePreview.HasHover = "No"; cuePreview.TextalignmentH = "Left"; cuePreview.Text = "Cue Count: —"

  ------------------------------------------------------------
  -- Button Row: Build / Cancel
  ------------------------------------------------------------
  local buttons = dlg:Append("UILayoutGrid"); buttons.Columns = 2; buttons.Rows = 1
  buttons.Anchors = {left=0,right=0,top=2,bottom=2}
  buttons.BackColor = colorTransparent
  local bBuild = buttons:Append("Button"); bBuild.Text = "Build Sequence"; bBuild.Font = "Medium20"; bBuild.PluginComponent=myHandle; bBuild.Clicked="OnBuild"; bBuild.Anchors={left=0,right=0,top=0,bottom=0}
  local bCancel= buttons:Append("Button"); bCancel.Text= "Cancel";         bCancel.Font= "Medium20"; bCancel.PluginComponent=myHandle; bCancel.Clicked="OnCancel"; bCancel.Anchors={left=1,right=1,top=0,bottom=0}

  ------------------------------------------------------------
  -- Internal helpers (UI <-> state)
  ------------------------------------------------------------
  local function refreshPresetList()
    pList.Text = "Presets: " .. presetsDisplay()
  end

  local function previewCueCount()
    local groupNum = toInt(state.groupStr)
    if not groupNum or groupNum < 1 then cuePreview.Text = "Cue Count: —"; return end
    local xGroup = toInt(state.xGroupStr) or 0
    local xBlock = toInt(state.xBlockStr) or 0
    local xWings = toInt(state.xWingsStr) or 0
    local totalCues
    if xGroup > 0 then totalCues = xGroup else
      local N = countGroupFixtures(groupNum)
      if N < 1 then cuePreview.Text = "Cue Count: 0 (group empty)"; return end
      local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
      if perX < 1 then perX = 1 end
      totalCues = math.ceil(N / perX)
    end
    cuePreview.Text = "Cue Count: " .. tostring(totalCues)
  end

  local function closeWindow()
    Obj.Delete(screenOverlay, Obj.Index(baseInput))
    safeCmd(string.format('Edit Sequence %d', seqNum))
  end

  ------------------------------------------------------------
  -- Signals (UI event handlers)
  ------------------------------------------------------------
  signalTable.OnCancel = function() closeWindow() end
  signalTable.OnBuild  = function()
    -- Validate
    if trim(state.groupStr) == "" then err("Group number required."); status.Text = "Error: Group required"; return end
    local groupNum = toInt(state.groupStr)
    if not groupNum or groupNum < 1 then err("Invalid group number: "..tostring(state.groupStr)); status.Text = "Error: Bad group"; return end
    if not groupSeemsToExist(groupNum) then
      if not PopupInput{title="Group "..groupNum.." not found. Continue?", caller=bBuild, items={"No","Yes"}}[1] == 2 then
        status.Text = "Canceled (group check)"; return
      end
    end

    local seqNum = toInt(state.seqNumStr)
    if not seqNum or seqNum < 1 then err("Invalid sequence number: "..tostring(state.seqNumStr)); status.Text = "Error: Bad seq #"; return end
    state.seqName = (trim(state.seqName) ~= "" and state.seqName) or "Stabber Recipe"

    local xGroup      = toInt(state.xGroupStr) or 0
    local xBlock      = toInt(state.xBlockStr) or 0
    local xWings      = toInt(state.xWingsStr) or 0
    local shuffleSeed = toInt(state.shuffleSeedStr) or 0

    if #state.presets == 0 then err("No presets entered."); status.Text = "Error: No presets"; return end

    -- Determine total cues
    local totalCues
    if xGroup > 0 then
      totalCues = xGroup
    else
      local N = countGroupFixtures(groupNum)
      if N < 1 then err("Group appears empty."); status.Text = "Error: Empty group"; return end
      local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
      if perX < 1 then perX = 1 end
      totalCues = math.ceil(N / perX)
    end

    -- Overwrite protection
   if seqExists(seqNum) then
      local idx = select(1, PopupInput{title = string.format("Sequence %d exists. Overwrite?", seqNum), caller=bBuild, items={"No","Yes"}}) or 1
      if idx ~= 2 then status.Text = "Canceled (preserve seq)"; return end
      if not safeCmd('Delete Sequence '..seqNum..' cue 1 thru /NC') then -- Added delete Cue to preserve sequence assignments
        if not safeCmd('Delete Sequence '..seqNum..' cue 1 thru /NC') then err("Unable to delete existing Sequence "..seqNum); status.Text = "Error: Delete failed"; return end
      end
    end

    -- Create target sequence
    if not safeCmd('Store Sequence '..seqNum) then status.Text = "Error: Store seq"; return end
    if not safeCmd('Set Sequence '..seqNum..' Property "Name" "'..state.seqName..'"') then status.Text = "Error: Name seq"; return end

    -- Prepare X values by mode
    local x_values = {}; for i=1,totalCues do x_values[i]=i end
    local mode = state.modes[state.selectedMode]
    if mode == "Shuffle" then
      math.randomseed(shuffleSeed > 0 and shuffleSeed or os.time())
      shuffle(x_values)
    elseif mode == "Scatter" then
      local low, high, idx = 1, totalCues, 1
      while low <= high do
        x_values[idx] = low; idx = idx + 1
        if low ~= high then x_values[idx] = high; idx = idx + 1 end
        low = low + 1; high = high - 1
      end
    end

    -- Build cues & parts
    for c = 1, totalCues do
      if not safeCmd('Store Sequence '..seqNum..' Cue '..c) then status.Text = "Error: store cue"; return end
      for p = 1, #state.presets do
        local partStr = '0.'..p
        local pr = state.presets[p]
        if not safeCmd('Store Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: store part"; return end
        if not safeCmd('Assign Group '..groupNum..' At Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: assign group"; return end
        if not safeCmd('Assign Preset '..pr.pool..'.'..pr.index..' At Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: assign preset"; return end
        if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "X" '..x_values[c]) then status.Text="Error: set X"; return end
        if xGroup > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XGroup" '..xGroup) then status.Text="Error: XGroup"; return end end
        if xBlock > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XBlock" '..xBlock) then status.Text="Error: XBlock"; return end end
        if xWings > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XWings" '..xWings) then status.Text="Error: XWings"; return end end
        if shuffleSeed > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XShuffle" '..shuffleSeed) then status.Text="Error: XShuffle"; return end end
      end
    end

    -- Finish
    local trueName = DataPool().Sequences[seqNum].name
    safeCmd('Store Macro "TempEditSequMacro')
    safeCmd('Store Macro "TempEditSequMacro" "EditSequ"')
    safeCmd('Store Macro "TempEditSequMacro" "DeleteMacro"')
    safeCmd(string.format('Set Macro "TempEditSequMacro"."EditSequ" Property "Command" "Edit Sequence %d"',seqNum))
    safeCmd('Set Macro "TempEditSequMacro"."DeleteMacro" Property Command "Delete Macro TempEditSequMacro /NC"')
    safeCmd(string.format('Set Sequence %d Cue * Property "Command" "Off Sequence \'%s\'"', seqNum, trueName))
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueFade" "\'%s\'"', seqNum, state.offCueFade))
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueDelay" "\'%s\'"', seqNum, state.offCueDelay))
    status.Text = "Done. Built "..totalCues.." cue(s)."
    safeCmd('Call Macro "TempEditSequMacro"')
    --safeCmd('Delete Macro "TempEditSequMacro"')
    closeWindow()
  end

  signalTable.OnSeqNumChanged       = function(c) state.seqNumStr      = trim(c.Content) end
  signalTable.OnSeqNameChanged      = function(c) state.seqName        = c.Content end
  signalTable.OnXGroupChanged       = function(c) state.xGroupStr      = trim(c.Content); previewCueCount() end
  signalTable.OnXBlockChanged       = function(c) state.xBlockStr      = trim(c.Content); previewCueCount() end
  signalTable.OnXWingsChanged       = function(c) state.xWingsStr      = trim(c.Content); previewCueCount() end
  signalTable.OnShuffleSeedChanged  = function(c) state.shuffleSeedStr = trim(c.Content) end
  signalTable.OnOffFadeChanged      = function(c) state.offCueFade     = trim(c.Content) end
  signalTable.OnOffDelayChanged     = function(c) state.offCueDelay    = trim(c.Content) end

  local function setMode(idx)
    state.selectedMode = idx
    mStraight.State = (idx==1) and 1 or 0
    mShuffle.State  = (idx==2) and 1 or 0
    mScatter.State  = (idx==3) and 1 or 0
  end
  signalTable.OnModeStraight = function() setMode(1) end
  signalTable.OnModeShuffle  = function() setMode(2) end
  signalTable.OnModeScatter  = function() setMode(3) end

  signalTable.OnPresetAdd = function()
    local s = trim(pEntry.Content or "")
    if s == "" then status.Text = "Enter Pool.Index to add"; return end
    local poolStr, idxStr = s:match("^(%d+)%.(%d+)$")
    local pool, idx = toInt(poolStr), toInt(idxStr)
    if not (pool and idx) then status.Text = "Invalid format. Use Pool.Index"; return end
    if not presetSeemsToExist(pool, idx) then
      local choose = select(1, PopupInput{title = string.format("Preset %d.%d not found. Add anyway?", pool, idx), caller=pAdd, items={"No","Yes"}}) or 1
      if choose ~= 2 then status.Text = "Canceled add"; return end
    end
    state.presets[#state.presets+1] = {pool=pool, index=idx}
    pEntry.Content = ""
    refreshPresetList()
    status.Text = string.format("Added %d.%d", pool, idx)
  end

  signalTable.OnPresetClear = function()
    state.presets = {}
    refreshPresetList()
    status.Text = "Cleared presets"
  end

  signalTable.OnCancel = function() closeWindow() end
  titleClose.Clicked = "OnCancel"

  signalTable.OnOpenSettings =  function ()

  local returnTable = MessageBox({

    
    title = 'My Example MessageBox',
    titleTextColor = 1.7,
    backColor = 1.11, 
    icon = 'object_smart',
    
    message = 'StabberPro Settings',

    autoCloseOnInput = false,

    commands = {
        {
      value = 1, name = 'Finished'
    }
},


    inputs = {
        {
      name = 'Preferred Default Group #',
      value = 'Numbers Only',
      whiteFilter = '1234567890',
      vkPlugin = 'NumericInput',
    }
},


  --[[  states = {{
      name = 'Enable Edit Sequence Dialoge on Build', -- The name displayed on the checkbox
      state = true -- Boolean determining if the checkbox defaults to checked (true) or unchecked (false)
    }},]]

    -- Selectors include two types of buttons: Swipe buttons (type 0) or Radio buttons (type 1). The selected value is returned by the function
    --'selectors' requires  a table of data for the selectors. That table of selectors requires an individual table for each selector
    -- Selectors are displayed in the order in which they appear in the table, but Radio buttons are always displayed before Swipe buttons
    selectors = {{
      name = 'Default Mode', -- The name displayed on the selector
      selectedValue = 1, -- The value that will be seleceted by default
      type = 0, -- The type of selector
      values = {['Straight'] = 1, ['Shuffle'] = 2, ['Scatter'] = 3} -- The values: ['Displayed Name'] = value (to be returned)
    }, {
      name = 'Edit Sequence Dialoge on Build',
      selectedValue = 1,
      type = 1,
      values = {['Enabled'] = 1, ['Disabled'] = 2, ['Option 3'] = 3}
    }}
  })

  -- The values returned by the MessageBox function are stored in a table. To read them, we must access the corresponding table values.
  settingsResult = returnTable.result -- Returns the value of the command button that is pressed or the timeoutResultID, if defined, depending on how the pop-up was closed
  settingsInputs = returnTable.inputs -- Returns a table with key/value pairs made up of the inputs' names and values
  settingsStates = returnTable.states -- Returns a table with key/value pairs made up of the states' names and boolean values
  settingsSelectors = returnTable.selectors -- Returns a table with key/value pairs made up of the selectors' names and boolean values


   if returnTable then
    Printf("Button Pressed: " .. tostring(returnTable.result))
    for k, v in pairs(returnTable.inputs or {}) do
      Printf("Input [" .. k .. "]: " .. v)
    end
    for k, v in pairs(returnTable.selectors or {}) do
      Printf("Selector [" .. k .. "]: " .. v)
    end
  end
end
  ------------------------------------------------------------------
  -- Popups: Group Picker + Preset Picker
  ------------------------------------------------------------------
  local function openGroupPicker(caller)
    local dp = DataPool()
    local groups = dp.Groups and dp.Groups:Children() or {}
    local items = {}
    for _,g in ipairs(groups) do
      local gNum = g.no or (Obj.Index(g) + 1)
      local count = #g:Children()
      items[#items+1] = string.format("%d: %s (%d)", gNum, g.name or "Group", count)
    end
    local _, choice = PopupInput{title = "Select Group", caller = caller, items = items, selectedValue = bGroup.Text}
    if choice then
      local selectedNum = tonumber(choice:match("^(%d+)"))
      if selectedNum then
        state.groupStr = tostring(selectedNum)
        bGroup.Text = "Group"..state.groupStr
        previewCueCount()
      end
    end
  end
 -- SIMPLE preset picker with MA3 pool labels; skips empty pools
local function openPresetPicker()
  local dp = DataPool()
  local pools = dp and dp.PresetPools
  if not pools then
    err("No PresetPools in this showfile.")
    return
  end

  -- Common MA3 preset pool names (extend as you wish)
  local POOL_LABEL = {
    [1]="Dimmer",[2]="Position",[3]="Gobo",[4]="Color",[5]="Beam",[6]="Focus",[7]="Control",
    [8]="Shapers",[9]="Video",[10]="Selection",[11]="Phaser",[12]="All",
    -- add/adjust beyond this if your show uses more typed pools
    [13]="Blind",[14]="Camera",[15]="User 15",[16]="User 16",[17]="User 17",[18]="User 18",
    [19]="User 19",[20]="User 20",[21]="All 1",[22]="All 2",[23]="All 3",[24]="Phaser",
  }
  local function poolLabel(i)
    local n = POOL_LABEL[i]
    return n and string.format("%d. %s", i, n) or string.format("Pool %d", i)
  end

  -- helper: robust child count
  local function childCount(p)
    local t = p and p:Children() or {}
    local c = 0
    for _, ch in ipairs(t) do if ch then c = c + 1 end end
    return c
  end

  -- Step 1: choose a (non-empty) Pool
  local poolItems, poolIndexMap = {}, {}
  for i = 1, #pools do
    local p = pools[i]
    if p and childCount(p) > 0 then
      local label = poolLabel(i)
      poolItems[#poolItems+1] = label
      poolIndexMap[label] = i  -- so we can recover the number from the label
    end
  end

  if #poolItems == 0 then
    PopupInput{title = "Pick Preset", caller = pPick, items = {"No non-empty preset pools found"}}
    return
  end

  local _, poolChoice = PopupInput{
    title  = "Pick Preset — choose Pool",
    caller = pPick,
    items  = poolItems,
    selectedValue = poolItems[1]
  }
  if not poolChoice then return end

  local poolNum = poolIndexMap[poolChoice] or tonumber(poolChoice:match("^(%d+)"))
  if not poolNum or not pools[poolNum] then return end

  -- Step 2: choose a Preset from the selected Pool
  local children = pools[poolNum]:Children() or {}
  local presetItems = {}
  for _, pr in ipairs(children) do
    local idx  = (pr and (pr.no or Obj.Index(pr) + 1)) or 0
    local name = (pr and pr.name) or "Preset"
    presetItems[#presetItems+1] = string.format("%d.%d  %s", poolNum, idx, name)
  end

  if #presetItems == 0 then
    PopupInput{title = ("Pool %d is empty"):format(poolNum), caller = pPick, items = {"OK"}}
    return
  end

  local _, pick = PopupInput{
    title  = ("Pick Preset — %s"):format(poolLabel(poolNum)),
    caller = pPick,
    items  = presetItems,
    selectedValue = presetItems[1]
  }
  if not pick then return end

  local pN, pI = pick:match("(%d+)%.(%d+)")
  local idxNum = tonumber(pI)
  if not idxNum then return end

  -- Add to list and refresh
  state.presets[#state.presets+1] = { pool = poolNum, index = idxNum }
  refreshPresetList()
end

  -- popup signal hooks
  signalTable.OnOpenGroupPicker  = function(caller) openGroupPicker(caller) end
  signalTable.OnOpenPresetPicker = function() openPresetPicker() end

  -- Initial previews
  previewCueCount()
end
