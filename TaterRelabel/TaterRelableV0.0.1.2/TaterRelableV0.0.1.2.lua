-- grandMA3 Plugin: TaterRelabel
-- Author: LXTater
-- https://www.lxtater.com
-- Plugin Version: 0.0.1.2
-- Tested on MA3 Version: 2.3.2.0
-- https://github.com/LXTater/LXTaterPlugins/

--[[ Version History:
---------------
    -----------------
    |Version 0.0.1.2|
    -----------------
    Changelog:
        -Version 0.0.1.2
            *Complete UI rewrite - all-in-one single window.
            *Removed multi-step MessageBox chain.
            *Added simultaneous Prefix + Suffix (both optional, blank = ignored).
            *Datapool type selected via PopupInput inside the window.
            *Copy checkbox updates action button label dynamically.
        -Skip a few UI building BS versions...
        -Version 0.0.0.3
            *Begin structured development.
        -Version 0.0.0.2
            *Plugin parses MA auto numbering (#2, #3, etc.)
            *Pool items properly copy empty spaces at destination.
        -Version 0.0.0.1
            *Added ability to Copy and Rename datapool items.
        -Version 0.0.0.0
            *Outline and basic structure created.
---------------
Known Bugs:
        *NONE... Yet!
--]]
local pluginName = select(1, ...)
local componentName = select(2, ...)
local signalTable = select(3, ...)
local myHandle = select(4, ...)


return function()

  -- =========================================================================
  -- Helpers
  -- =========================================================================

  local pluginTag = "TaterRelabel"
  local function msg(s) Printf("[%s] %s", pluginTag, s) end
  local function err(s) ErrPrintf("[%s] %s", pluginTag, s) end
  local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

  local function safeCmdIndirect(s)
    local ok, why = pcall(CmdIndirect, s)
    if not ok then err("CmdIndirect failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  local function safeCmd(s)
    local ok, why = pcall(Cmd, s)
    if not ok then err("Cmd failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  -- =========================================================================
  -- Datapool Type Definitions  { displayName, datapoolKey, cmdKeyword }
  -- =========================================================================

  local datapoolTypes = {
    { "Sequence",   "Sequences",   "Sequence"   },
    { "Group",      "Groups",      "Group"      },
    { "Macro",      "Macros",      "Macro"      },
    { "Preset",     "PresetPools", "Preset"     },
    { "MAtricks",   "MAtricks",    "MAtricks"   },
    { "Appearance", "Appearances", "Appearance" },
    { "Timecode",   "Timecodes",   "Timecode"   },
    { "Page",       "Pages",       "Page"       },
  }

  -- =========================================================================
  -- Pool / Label Helpers
  -- =========================================================================

  local function getPool(datapoolKey)
    local ok, dp = pcall(DataPool)
    if not ok or not dp then return nil end
    return dp[datapoolKey]
  end

  local function hasAutoNumber(name)
    return name and name:match(" #%d+$") ~= nil
  end

  local function stripAutoNumber(name)
    if not name then return "" end
    return name:gsub(" #%d+$", "")
  end

  local function collectItems(pool, startNum, endNum)
    local items = {}
    if not pool then return items end
    for i = startNum, endNum do
      local obj = pool[i]
      if obj and obj.name and obj.name ~= "" then
        table.insert(items, { no = i, name = obj.name })
      end
    end
    return items
  end

  local function anyAutoNumbered(items)
    for _, item in ipairs(items) do
      if hasAutoNumber(item.name) then return true end
    end
    return false
  end

  local function computeNewName(origName, prefix, suffix, doStripAuto)
    local base = origName
    if doStripAuto then base = stripAutoNumber(base) end
    return prefix .. base .. suffix
  end

  local function applyRelabel(items, prefix, suffix, doStripAuto, cmdKeyword)
    local count = 0
    for _, item in ipairs(items) do
      local newName = computeNewName(item.name, prefix, suffix, doStripAuto)
      local cmdStr  = string.format('Label %s %d "%s"', cmdKeyword, item.no, newName)
      msg(string.format("Label %s %d -> \"%s\"", cmdKeyword, item.no, newName))
      if safeCmdIndirect(cmdStr) then count = count + 1 end
    end
    return count
  end

  local function applyCopyAndRelabel(items, sourceStart, sourceEnd, destStart, prefix, suffix, doStripAuto, cmdKeyword)
    local copyCmd = string.format("Copy %s %d Thru %d At %s %d",
      cmdKeyword, sourceStart, sourceEnd, cmdKeyword, destStart)
    msg(copyCmd)
    if not safeCmd(copyCmd) then
      err("Bulk copy failed. Aborting.")
      return 0, 0
    end
    local labelCount = 0
    for _, item in ipairs(items) do
      local destSlot = destStart + (item.no - sourceStart)
      local newName  = computeNewName(item.name, prefix, suffix, doStripAuto)
      local labelCmd = string.format('Label %s %d "%s"', cmdKeyword, destSlot, newName)
      msg(string.format("Relabel %s %d -> \"%s\"", cmdKeyword, destSlot, newName))
      if safeCmd(labelCmd) then labelCount = labelCount + 1 end
    end
    return #items, labelCount
  end

  -- =========================================================================
  -- Plugin State
  -- =========================================================================

  local state = {
    datapoolTypeIdx = 1,
    startStr        = "1",
    endStr          = "10",
    prefix          = "",
    suffix          = "",
    doCopy          = false,
    destStr         = "101",
  }

  -- =========================================================================
  -- Display Setup
  -- =========================================================================

   -- Get the index of the display on which to create the dialog.
  local displayIndex = Obj.Index(GetFocusDisplay())
  if displayIndex > 5 then
    displayIndex = 1
  end
  -- Colors
  local CT               = Root().ColorTheme.ColorGroups
  local colorTransparent = CT.Global.Transparent
  local colorBtnPlease   = CT.Button.BackgroundPlease
  local colorBlack = CT.FixtureSheetCell.SymbolsBackground
  local colorYellow = CT.Global.ErrorText

  -- Get the overlay.
  local display = GetDisplayByIndex(displayIndex)
  local screenOverlay = display.ScreenOverlay
  -- =========================================================================
  -- UI Forward Declarations
  -- =========================================================================

  local baseInput, btnDatapoolType, eStart, eEnd, ePrefix, eSuffix
  local chkCopy, eDest, btnAction

  -- =========================================================================
  -- BaseInput  (1 col, 2 rows: TitleBar row | Content row)
  -- =========================================================================
    screenOverlay:ClearUIChildren()   

  local dialogWidth = 900
  baseInput = screenOverlay:Append("BaseInput")
  baseInput.Name          = "TaterRelabel"
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
  baseInput.BackColor = colorBlack
  

  -- =========================================================================
  -- TitleBar  (explicitly anchored to baseInput row 0)
  -- =========================================================================

  local titleBar = baseInput:Append("TitleBar")
  titleBar.Columns = 10 
  titleBar.Rows = 1
  titleBar.Anchors = {left=0,right=0,top=0,bottom=0}
  titleBar[2][2].SizePolicy = "Fixed"
  titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"
  titleBar.BackColor = colorBlack


  --TaterIcon
  local titleBarIcon = titleBar:Append("AppearancePreview")
  titleBarIcon.Appearance = GetObject('Appearance LXTaterPlugIcon')
  titleBarIcon.Anchors = {left=0,right=0,top=0,bottom=0}
  titleBarIcon.TextColor = colorYellow
  titleBarIcon.BackColor = colorBlack
  titleBarIcon.W = "50"
  titleBarIcon.interactive = "Yes"

  local titleBarHead = titleBar:Append("TitleButton")
  titleBarHead.Anchors = {left=1,right=8,top=0,bottom=0}
  titleBarHead.Text = "                "
  titleBarHead.BackColor = colorBlack
  --Exit Button
  local titleBarCloseButton = titleBar:Append("CloseButton")
  titleBarCloseButton.Anchors = "9,0"
  titleBarCloseButton.Texture = "corner2"
  titleBarCloseButton.BackColor = colorBlack

  -- =========================================================================
  -- DialogFrame  (explicitly anchored to baseInput row 1)
  -- 1 col, 2 rows: FrameGrid | ButtonRow
  -- =========================================================================

  local dlgFrame = baseInput:Append("DialogFrame")
  dlgFrame.H = "100%"
  dlgFrame.W = "100%"
  dlgFrame.Columns = 1  
  dlgFrame.Rows = 3
  dlgFrame.BackColor = colorBlack
  dlgFrame.Anchors = {
    left = 0,
    right = 0,
    top = 1,
    bottom = 1
  }
  -- subtitle row
  dlgFrame[1][1].SizePolicy = "Fixed"
  dlgFrame[1][1].Size = "100"
  -- main grid row
  dlgFrame[1][2].SizePolicy = "Fixed"
  dlgFrame[1][2].Size = "400"
  -- button button row
  dlgFrame[1][3].SizePolicy = "Fixed"  
  dlgFrame[1][3].Size = "80"  

  -- =========================================================================
  -- FrameGrid  (flat UILayoutGrid, 2 cols, 7 rows — one row per input)
  --   Col 0 : right-aligned labels
  --   Col 1 : inputs / controls
  -- =========================================================================
  --
  -- Rows (0-based anchors):
  --   0  Datapool Type
  --   1  Start Range
  --   2  End Range
  --   3  Prefix
  --   4  Suffix
  --   5  Copy Checkbox  (spans both columns)
  --   6  Destination Pool #
  --
  -- =========================================================================
local subTitle = dlgFrame:Append("AppearancePreview")
  subTitle.Appearance = GetObject('Appearance LXTaterLogo')
  subTitle.Interactive = 'No'
  subTitle.BackColor = colorBlack
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

  
  -- Main inputs grid
  local form = dlgFrame:Append("UILayoutGrid"); form.Columns = 2; form.Rows = 7
  form.BackColor = colorBlack
  form.Anchors = {left=0,right=0,top=1,bottom=1}

  local function mkLabel(txt, l, r, t, b)
    local o = form:Append("UIObject")
    o.Text = txt;o.BackColor = colorBlack; o.TextalignmentH = "Right"; o.Font = "Medium20"; o.HasHover = "No"
    o.Anchors = {left=l,right=r,top=t,bottom=b}
    return o
  end

  local function mkLine(prompt, content, key, l, r, t, b, numeric, bg)
    mkLabel(prompt, l, l, t, b)
    local e = form:Append("LineEdit")
    e.Content = content or ""
    e.TextAutoAdjust = "Yes"
    e.BackColor = colorBlack
    e.Anchors = {left=l+1,right=r,top=t,bottom=b}
    e.Padding = "4,4"; e.MaxTextLength = 32; e.HideFocusFrame = "Yes"
    if numeric then e.Filter = "0123456789"; e.VkPluginName = "TextInputNumOnly" end
    if bg then e.BackColor = bg end
    e.PluginComponent = myHandle
    e.TextChanged = key
    return e
  end

  -- Row 0: Datapool Type
  mkLabel("Datapool Type", 0, 0, 0, 0)
  btnDatapoolType = form:Append("Button")
  btnDatapoolType.Anchors         = {left=1,right=1,top=0,bottom=0}
  btnDatapoolType.Text            = datapoolTypes[state.datapoolTypeIdx][1]
  btnDatapoolType.PluginComponent = myHandle
  btnDatapoolType.Clicked         = "OnDatapoolTypePick"
  btnDatapoolType.BackColor       = colorYellow
  btnDatapoolType.TextAlignmentH  = "Center"

  -- Row 1: Start Range
  eStart = mkLine("Start Range", state.startStr, "OnStartChanged", 0, 1, 1, 1, true)

  -- Row 2: End Range
  eEnd = mkLine("End Range", state.endStr, "OnEndChanged", 0, 1, 2, 2, true)

  -- Row 3: Prefix
  ePrefix = mkLine("Prefix", state.prefix, "OnPrefixChanged", 0, 1, 3, 3)

  -- Row 4: Suffix
  eSuffix = mkLine("Suffix", state.suffix, "OnSuffixChanged", 0, 1, 4, 4)

  -- Row 5: Copy Checkbox (spans both columns)
  chkCopy = form:Append("CheckBox")
  chkCopy.Text            = "Also copy these items?"
  chkCopy.State           = 0
  chkCopy.Anchors         = {left=0,right=1,top=5,bottom=5}
  chkCopy.PluginComponent = myHandle
  chkCopy.Clicked         = "OnCopyToggled"
  chkCopy.BackColor = colorBlack

  -- Row 6: Destination Pool #
  eDest = mkLine("Copy to Pool #", state.destStr, "OnDestChanged", 0, 1, 6, 6, true)

  ------------------------------------------------------------
  -- Button Row: Cancel / Relabel
  ------------------------------------------------------------
  local buttons = dlgFrame:Append("UILayoutGrid"); buttons.Columns = 2; buttons.Rows = 1
  buttons.Anchors = {left=0,right=0,top=2,bottom=2}
  buttons.BackColor = colorTransparent
  local bCancel = buttons:Append("Button"); bCancel.Text = "Cancel"; bCancel.Font = "Medium20"; bCancel.PluginComponent = myHandle; bCancel.Clicked = "OnCancel"; bCancel.Anchors = {left=0,right=0,top=0,bottom=0}
  btnAction = buttons:Append("Button"); btnAction.Text = "Relabel"; btnAction.Font = "Medium20"; btnAction.PluginComponent = myHandle; btnAction.Clicked = "OnAction"; btnAction.Anchors = {left=1,right=1,top=0,bottom=0}
  btnAction.BackColor = colorBtnPlease

  -- =========================================================================
  -- Internal Helpers
  -- =========================================================================

  local function closeWindow()
    Obj.Delete(screenOverlay, Obj.Index(baseInput))
  end

  -- =========================================================================
  -- Signal Handlers
  -- =========================================================================

  signalTable.OnDatapoolTypePick = function()
    local items = {}
    for _, dp in ipairs(datapoolTypes) do
      items[#items + 1] = dp[1]
    end
    local idx = select(1, PopupInput{
      title         = "Select Datapool Type",
      caller        = btnDatapoolType,
      items         = items,
      selectedValue = datapoolTypes[state.datapoolTypeIdx][1],
    })
    if idx then
      state.datapoolTypeIdx = idx
      btnDatapoolType.Text  = datapoolTypes[idx][1]
    end
  end

  signalTable.OnStartChanged  = function(c) state.startStr = trim(c.Content) end
  signalTable.OnEndChanged    = function(c) state.endStr   = trim(c.Content) end
  signalTable.OnPrefixChanged = function(c) state.prefix   = c.Content end
  signalTable.OnSuffixChanged = function(c) state.suffix   = c.Content end
  signalTable.OnDestChanged   = function(c) state.destStr  = trim(c.Content) end

  -- Checkbox only updates the action button label — no show/hide
  signalTable.OnCopyToggled = function()
    state.doCopy   = not state.doCopy
    chkCopy.State  = state.doCopy and 1 or 0
    btnAction.Text = state.doCopy and "Copy & Relabel" or "Relabel"
  end

  signalTable.OnCancel = function() closeWindow() end

  signalTable.OnAction = function()
    -- Validate range
    local startNum = tonumber(state.startStr)
    local endNum   = tonumber(state.endStr)
    if not startNum or startNum < 1 then err("Invalid Start Range."); return end
    if not endNum   or endNum   < 1 then err("Invalid End Range.");   return end
    if startNum > endNum then err("Start Range must be <= End Range."); return end

    -- Validate prefix / suffix (at least one must be non-empty)
    local prefix = state.prefix
    local suffix = state.suffix
    if trim(prefix) == "" and trim(suffix) == "" then
      MessageBox({
        title    = "TaterRelabel - No Text Entered",
        icon     = "warning_triangle_big",
        message  = "Please enter at least a Prefix or a Suffix.",
        commands = { { value = 1, name = "OK" } },
      })
      return
    end
    if trim(prefix) == "" then prefix = "" end
    if trim(suffix) == "" then suffix = "" end

    -- Resolve datapool type
    local dpType      = datapoolTypes[state.datapoolTypeIdx]
    local displayName = dpType[1]
    local datapoolKey = dpType[2]
    local cmdKeyword  = dpType[3]

    local pool = getPool(datapoolKey)
    if not pool then
      err("Cannot access DataPool()." .. datapoolKey); return
    end

    -- Collect items in range
    local items = collectItems(pool, startNum, endNum)
    if #items == 0 then
      MessageBox({
        title    = "TaterRelabel - No Items Found",
        icon     = "warning_triangle_big",
        message  = string.format("No labeled %s objects found in range %d to %d.",
          displayName, startNum, endNum),
        commands = { { value = 1, name = "OK" } },
      })
      return
    end

    -- Auto-number detection
    local doStripAuto = false
    if anyAutoNumbered(items) then
      local examples = {}
      for _, item in ipairs(items) do
        if hasAutoNumber(item.name) and #examples < 4 then
          examples[#examples + 1] = string.format('  %d: "%s"', item.no, item.name)
        end
      end
      local box = MessageBox({
        title          = "TaterRelabel - Auto-Number Detected",
        icon           = "warning_triangle_big",
        titleTextColor = "Global.AlertText",
        message        = "Some items have MA auto-number suffixes (#2, #3...).\n\n"
                      .. table.concat(examples, "\n") .. "\n\n"
                      .. "Remove the #N suffixes before applying prefix/suffix?",
        commands       = {
          { value = 1, name = "Yes, Strip #" },
          { value = 2, name = "No, Keep #"   },
          { value = 0, name = "Cancel"        },
        },
      })
      if not box or box.result == 0 then return end
      doStripAuto = (box.result == 1)
    end

    -- Close window before executing
    closeWindow()

    -- Execute
    if state.doCopy then
      local destStart = tonumber(state.destStr)
      if not destStart or destStart < 1 then
        err("Invalid destination pool number."); return
      end

      local rangeSpan = endNum - startNum
      local destEnd   = destStart + rangeSpan

      -- Overlap warning
      if destStart <= endNum and destEnd >= startNum then
        local box = MessageBox({
          title          = "TaterRelabel - Overlap Warning",
          icon           = "warning_triangle_big",
          titleTextColor = "Global.AlertText",
          message        = string.format(
            "Destination %d to %d overlaps source %d to %d!\n\nContinue?",
            destStart, destEnd, startNum, endNum),
          commands       = {
            { value = 1, name = "Continue" },
            { value = 0, name = "Cancel"   },
          },
        })
        if not box or box.result ~= 1 then msg("Cancelled."); return end
      end

      local copyCount, labelCount = applyCopyAndRelabel(
        items, startNum, endNum, destStart,
        prefix, suffix, doStripAuto, cmdKeyword
      )
      MessageBox({
        title          = "TaterRelabel - Complete!",
        icon           = "object_smart",
        titleTextColor = "Global.Focus",
        message        = string.format(
          "Copied %d %s item(s) to slots %d to %d.\nRelabeled %d of %d copies.",
          copyCount, displayName, destStart, destEnd, labelCount, #items),
        commands       = { { value = 1, name = "OK" } },
      })
      msg(string.format("Done. Copied %d, relabeled %d of %d.", copyCount, labelCount, #items))

    else
      local count = applyRelabel(items, prefix, suffix, doStripAuto, cmdKeyword)
      MessageBox({
        title          = "TaterRelabel - Complete!",
        icon           = "object_smart",
        titleTextColor = "Global.Focus",
        message        = string.format(
          "Relabeled %d of %d %s item(s).", count, #items, displayName),
        commands       = { { value = 1, name = "OK" } },
      })
      msg(string.format("Done. Relabeled %d of %d.", count, #items))
    end
  end

end
