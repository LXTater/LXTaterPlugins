-- grandMA3 Plugin: StabberPro LogicTestMode (dlgframe UI)
-- Author: LXTater (UI port scaffold by ChatGPT)
-- Version: 0.2.0-dlg
-- NOTE: Test and debug only. Backup your showfile first!
--
-- WHAT CHANGED:
-- • Replaced MessageBox UI with a full dlgframe UI (BaseInput/TitleBar/DialogFrame)
-- • Live inputs for Group, Sequence #/Name, MAtricks (XGroup/XBlock/XWings), Shuffle Seed, OffCue Fade/Delay
-- • Preset manager (enter Pool.Index, add/clear, live list)
-- • Mode selector (Straight / Shuffle / Scatter)
-- • Build & Cancel buttons; Close button in TitleBar
-- • Uses existing build logic from the MessageBox version
--
-- HOW TO RUN:
-- Drop into a plugin and run. The window appears on the focused display. Close via [Cancel] or the TitleBar close button.

local pluginName, componentName, signalTable, myHandle = select(1, ...)

return function()
  ------------------------------------------------------------
  -- Helpers (unchanged where possible)
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
  local colorButtonBG        = CT.Button.Background
  local colorButtonPlease    = CT.Button.BackgroundPlease
  local colorPartlySelected  = CT.Global.PartlySelected
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
  titleBar.Columns = 2; titleBar.Rows = 1
  titleBar[2][2].SizePolicy = "Fixed"; titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"

  local titleIcon = titleBar:Append("TitleButton")
  titleIcon.Text = "StabberPro – LogicTestMode"
  titleIcon.Texture = "corner1"; titleIcon.Icon = "star"

  local titleClose = titleBar:Append("CloseButton")
  titleClose.Anchors = "1,0"

  -- Frame grid
  local dlg = baseInput:Append("DialogFrame")
  dlg.W = "100%"; dlg.H = "100%"
  dlg.Columns = 1; dlg.Rows = 3
  dlg[1][1].SizePolicy = "Fixed";  dlg[1][1].Size = "60"     -- subtitle
  -- main grid row (give it real height so it can't collapse)
  dlg[1][2].SizePolicy = "Fixed"
  dlg[1][2].Size = "420"                          -- main
  dlg[1][3].SizePolicy = "Fixed";  dlg[1][3].Size = "80"     -- buttons

  -- Subtitle
  local sub = dlg:Append("UIObject")
  sub.Text = "Configure Stabber Recipe builder"
  sub.Font = "Medium20"; sub.HasHover = "No"; sub.BackColor = colorTransparent
  sub.Padding = {left=20,right=20,top=15,bottom=15}
  sub.Anchors = {left=0,right=0,top=0,bottom=0}

  -- MAIN: two-column grid
  local main = dlg:Append("UILayoutGrid"); main.Columns = 2; main.Rows = 1
  main.BackColor = colorTransparent
  main.Anchors = {left=0,right=0,top=1,bottom=1}

  ------------------------------------------------------------
  -- LEFT: Settings form
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
    -- no prompt inside input; separate label handles caption
    e.Content = content or ""
    e.TextAutoAdjust = "Yes"
    --e.TextAlignmentH = "Center"
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
  local bGroup = form:Append("Button"); bGroup.Anchors={left=1,right=1,top=0,bottom=0}; bGroup.Text = (state.groupStr~="" and ("Group"..state.groupStr)) or "Select Group"; bGroup.PluginComponent=myHandle; bGroup.Clicked="OnOpenGroupPicker"; bGroup.backcolor = colorButtonPlease; bGroup.TextalignmentH = "Center";
  mkLine("Sequence #",   state.seqNumStr,      "OnSeqNumChanged",      2,4,0,0, true)
  -- Row 2: Sequence Name (spans two)
  mkLabel("Sequence Name", 0,0,1,1)
  local eSeqName = form:Append("LineEdit"); eSeqName.Anchors={left=1,right=4,top=1,bottom=1}
  eSeqName.Content = state.seqName; eSeqName.TextAutoAdjust="Yes"; eSeqName.PluginComponent=myHandle; eSeqName.TextChanged="OnSeqNameChanged"; eSeqName.TextalignmentH = "Left";

  -- Row 3: MAtricks XGroup/XBlock
  mkLine("XGroup",       state.xGroupStr,      "OnXGroupChanged",      0,2,2,2, true, colorMATx)
  mkLine("XBlock",       state.xBlockStr,      "OnXBlockChanged",      2,4,2,2, true, colorMATx)
  -- Row 4: XWings / Shuffle Seed
  mkLine("XWings",       state.xWingsStr,      "OnXWingsChanged",      0,2,3,3, true, colorMATx)
  mkLine("Shuffle Seed", state.shuffleSeedStr, "OnShuffleSeedChanged", 2,4,3,3, true)
  -- Row 5: OffCue Fade / Delay
  mkLine("OffCue Fade",  state.offCueFade,     "OnOffFadeChanged",     0,2,4,4, false, colorFadeValue)
  mkLine("OffCue Delay", state.offCueDelay,    "OnOffDelayChanged",    2,4,4,4, false, colorDelayValue)

  -- Row 6: Mode selector (three radio-like checkboxes)
  mkLabel("Mode", 0,0,5,5)
  local mStraight = form:Append("CheckBox"); mStraight.Text="Straight"; mStraight.State=1; mStraight.Anchors={left=1,right=1,top=5,bottom=5}; mStraight.PluginComponent=myHandle; mStraight.Clicked="OnModeStraight"
  local mShuffle  = form:Append("CheckBox"); mShuffle.Text ="Shuffle" ; mShuffle.State=0; mShuffle.Anchors={left=2,right=2,top=5,bottom=5};  mShuffle.PluginComponent=myHandle;  mShuffle.Clicked ="OnModeShuffle"
  local mScatter  = form:Append("CheckBox"); mScatter.Text ="Scatter" ; mScatter.State=0; mScatter.Anchors={left=3,right=3,top=5,bottom=5};  mScatter.PluginComponent=myHandle;  mScatter.Clicked ="OnModeScatter"

  ------------------------------------------------------------
  -- RIGHT: Preset Manager + status
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
  pList.Anchors = {left=0,right=2,top=2,bottom=4}; pList.HasHover = "No"; pList.TextalignmentH = "Left"
  pList.Text = "Presets: " .. presetsDisplay(); pList.Padding = "8,8"

  -- Clear presets
  local pClear = right:Append("Button")
  pClear.Anchors = {left=0,right=0,top=4,bottom=4}; pClear.Text = "Clear Presets"; pClear.PluginComponent = myHandle; pClear.Clicked = "OnPresetClear"

  -- Status / preview
  local status = right:Append("Button")
  status.Anchors = {left=1,right=1,top=4,bottom=4}; status.HasHover = "No"; status.TextalignmentH = "Left"; status.Text = "Ready"

  -- Expected cue count preview
  local cuePreview = right:Append("Button")
  cuePreview.Anchors = {left=0,right=2,top=5,bottom=5}; cuePreview.HasHover = "No"; cuePreview.TextalignmentH = "Left"; cuePreview.Text = "Cue Count: —"

  ------------------------------------------------------------
  -- BUTTON ROW: Build / Cancel
  ------------------------------------------------------------
  local buttons = dlg:Append("UILayoutGrid"); buttons.Columns = 2; buttons.Rows = 1
  buttons.Anchors = {left=0,right=0,top=2,bottom=2}
  buttons.BackColor = colorTransparent
  -- Make sure each button sits in its own cell
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
  end

  ------------------------------------------------------------
  -- SIGNALS (UI event handlers)
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
      if not safeCmd('Delete Sequence '..seqNum..' /NC') then
        if not safeCmd('Delete Sequence '..seqNum) then err("Unable to delete existing Sequence "..seqNum); status.Text = "Error: Delete failed"; return end
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
    safeCmd(string.format('Set Sequence %d Cue * Property "Command" "Off Sequence \'%s\'"', seqNum, trueName))
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueFade" "\'%s\'"', seqNum, state.offCueFade))
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueDelay" "\'%s\'"', seqNum, state.offCueDelay))
    status.Text = "Done. Built "..totalCues.." cue(s)."
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

  ------------------------------------------------------------------
  -- Popups: Group picker and Preset picker (with tabs)
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

 -- Preset picker window: % for outer size, px for grid internals
local function openPresetPicker()
  local overlay = display.ScreenOverlay

  -- --- window in % ---
  local popW      = math.floor(display.W * 0.88)
  local popH      = math.floor(display.H * 0.86)
  local titleH    = 56
  local leftPct   = 0.20                      -- ~20% for pools column
  local leftW     = math.floor(popW * leftPct)
  local rightW    = popW - leftW

  -- --- BaseInput (percent look, pixel internals) ---
  local pop = overlay:Append("BaseInput")
  pop.Name = "PresetPicker"
  pop.W = popW
  pop.H = 0
  pop.MaxSize = string.format("%d,%d", popW, popH)
  pop.MinSize = string.format("%d,0",   popW)
  pop.Columns = 1
  pop.Rows = 2
  pop[1][1].SizePolicy = "Fixed"; pop[1][1].Size = tostring(titleH)
  pop[1][2].SizePolicy = "Fixed"; pop[1][2].Size = tostring(popH - titleH)
  pop.CloseOnEscape = "Yes"

  -- --- Title bar ---
  local tb = pop:Append("TitleBar"); tb.Columns = 2; tb.Rows = 1
  tb[2][2].SizePolicy = "Fixed"; tb[2][2].Size = "50"; tb.Texture = "corner2"
  local tbtn = tb:Append("TitleButton"); tbtn.Text = "Pick Preset"
  local tclose = tb:Append("CloseButton"); tclose.Anchors="1,0"; tclose.Texture="corner2"
  tclose.Clicked = "OnCloseChildPopup"; tclose.PluginComponent = myHandle

  -- --- Main frame: 2 columns (tabs | content) ---
  local frame = pop:Append("DialogFrame")
  frame.Columns = 2; frame.Rows = 1; frame.Anchors = {left=0,right=0,top=1,bottom=1}
  frame[1][1].SizePolicy = "Fixed"; frame[1][1].Size = tostring(leftW)
  frame[2][1].SizePolicy = "Fixed"; frame[2][1].Size = tostring(rightW)

  -- Right side holder; each pool page becomes a grid child here
  local container = frame:Append("DialogContainer")
  container.Name = "tab_contents"; container.anchors = '1,0'

  -- --- Pool tab list (vertical) ---
  local tab = frame:Append("UITab")
  tab.Name = "presetTabs"
  tab.Type = "Vertical"
  tab.Texture = "corner5"
  tab.ItemSize = 48
  tab.PluginComponent = myHandle
  tab.TabChanged = "OnPresetTabChanged"
  tab.W = leftW
  tab.H = popH - titleH
  tab:WaitInit()

  -- --- Build pool pages ---
  local pools = DataPool().PresetPools
  local tabCount = 0
  if pools then
    for i = 1, #pools do
      local pool = pools[i]
      if pool then
        tabCount = tabCount + 1

        -- Page grid (right side)
        local rowH = 44
        local page = container:Append("UILayoutGrid")
        page.Name = "pool"..i
        page.Margin = {left=10,right=12,top=10,bottom=10}
        page.Columns = 2              -- label | note
        page.Rows = 1                 -- will grow by setting row sizes below

        -- Fill rows with presets (2 columns: main text + note)
        local children = pool:Children() or {}
        local r = 0
        for _, pr in ipairs(children) do
          local idx = pr and (pr.no or (Obj.Index(pr) + 1)) or 0
          local name = (pr and pr.name) or "Preset"
          local leftBtn = page:Append("Button")
          leftBtn.Anchors = {left=0,right=0,top=r,bottom=r}
          leftBtn.Text = string.format("%d.%d  %s", i, idx, name)
          leftBtn.TextAutoAdjust = "Yes"
          leftBtn.Name = string.format("preset|%d|%d", i, idx)
          leftBtn.PluginComponent = myHandle
          leftBtn.Clicked = "OnChoosePreset"
          leftBtn.Padding = "6,6"

          local noteBtn = page:Append("Button")
          noteBtn.Anchors = {left=1,right=1,top=r,bottom=r}
          noteBtn.Text = pr and (pr.Display or pr.Info or "") or ""
          noteBtn.TextAutoAdjust = "Yes"
          noteBtn.HasHover = "No"
          noteBtn.Padding = "6,6"

          -- enforce row height
          page[1][r+1].SizePolicy = "Fixed"; page[1][r+1].Size = tostring(rowH)
          r = r + 1
        end

        -- Column sizing inside the page (≈ 65% | 35%)
        local leftColW = math.floor(rightW * 0.64)
        local rightColW = rightW - leftColW - page.Margin.left - page.Margin.right
        page[2][1].SizePolicy = "Fixed"; page[2][1].Size = tostring(leftColW)
        page[2][2].SizePolicy = "Fixed"; page[2][2].Size = tostring(rightColW)

        -- Add tab entry
        tab:AddListStringItem(("Pool %d"):format(i), page.Name)
      end
    end
  end

  if tabCount > 0 and tab[1] then tab[1]:WaitChildren(tabCount) end
  tab.SelectedItem = 1

  -- Ensure only the selected page is visible initially
  local fakeCaller = tab
  signalTable.OnPresetTabChanged(fakeCaller)
end


  -- popup signal hooks
  signalTable.OnOpenGroupPicker = function(caller) openGroupPicker(caller) end
  signalTable.OnOpenPresetPicker = function() openPresetPicker() end
  signalTable.OnCloseChildPopup = function(caller)
    local ov = caller:GetOverlay(); local bi = ov and ov:FindRecursive("PresetPicker","BaseInput"); if bi then Obj.Delete(ov, Obj.Index(bi)) end
  end
  signalTable.OnPresetTabChanged = function(caller)
  local overlay = caller:GetOverlay()
  local count = caller:GetListItemsCount()
  local active = caller.SelectedItemValueStr
  for i = 1, count do
    local name = caller:GetListItemValueStr(i)          -- this is the page name we stored
    local page = overlay:FindRecursive(name, "UILayoutGrid")
    if page then page.Visible = (name == active) and "Yes" or "No" end
  end
end
  signalTable.OnChoosePreset = function(caller)
    local pool, idx
    if caller.Name and caller.Name:find('|') then
      local a,b,c = caller.Name:match("([^|]*)|([^|]*)|([^|]*)")
      pool = tonumber(b); idx = tonumber(c)
    end
    if (not pool) or (not idx) then
      local p,i = caller.Text:match("(%d+)%.(%d+)")
      pool = tonumber(p); idx = tonumber(i)
    end
    if pool and idx then
      state.presets[#state.presets+1] = {pool=pool,index=idx}
      refreshPresetList()
    end
    local ov = caller:GetOverlay(); local bi = ov and ov:FindRecursive("PresetPicker","BaseInput"); if bi then Obj.Delete(ov, Obj.Index(bi)) end
  end

  -- Initial previews
  previewCueCount()
end