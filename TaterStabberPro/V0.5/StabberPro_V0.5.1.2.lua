-- grandMA3 Plugin: StabberPro
-- Author: LXTater
-- Version: 0.5.1.2
-- NOTE: Test and debug only. Backup your showfile first!
-- Github: https://github.com/LXTater/StabberPro
-- www.LXTater.com
-- Editable States are on Line 299!


--[[ Version History:
---------------  
    -------------
    |Version 0.5|
    -------------
---------------
    Changelog:

    -Version 0.5.1.2
        *Added LXTater logo <3
        *Added Command Delay Option
        *Changed cue command to be a state so you can edit it.
        *Made States easier to find in the code for user editing.
    -Version 0.5.1.1
        *
---------------
    Known Bugs:
        *
---------------        
    TODO:
            *Remove Settings Menu
            *Organize states and default values for easy user editing.
            *Finalize UI and other plugin elements for release
            *Clean up as many cmd functions into obj functions
            *Stress Test and Debug
            *Prepare for Release
            *Add atleast 1 or 2 more bugs
---------------              
    -------------
    |Version 0.4|
    -------------
---------------
    Changelog:
    -Version 0.4.2.8
        *Fixed issue where plugin would crash if no plugin was selected
        *Fixed issue where group popup would not give feedback to the user if there are no groups in the pool.
        *Fixed an issue where plugin would not set a default name for new sequences if plugin was started with no sequence selected.
    -Version 0.4.2.5 thru 0.4.2.7
        *Minor bug fixes and testing.
        *I just save a new version for a lot of little things incase I brick something
    -Version 0.4.2.4
        *Fixed Wings of 1 value.
    -Version 0.4.2.3
        *Tracking state defaults to sequence tracking value
    - Version 0.4.2.1
        *Removed ability to select or enable Z axis on GUI
        *Selected Sequence will be the default sequence that opens up in the plugin. It will populate the name, number, and if it is empty or not.
        *Added Tracking toggle, defaulted to off
        *Added a function that will make sure any stabber sequence that is built utilizes Next Cue for restart mode
        *Added Sequ Status
            *Red Text [Sequ State: Not Empty]
            *Orange Text [Sequ State: Invalid]  (you will most likely never see this, if you do restart the plugin or software. THis means there was an error in determining the selected sequence.
            *Green Text[Sequ State: Empty]
        *Removed Settings menu. All of our settings can be dealt with on the main page, or by editing default values on the states table.
    - Version 0.4.1.4a thru 0.4.1.4f
        *Minor bug fixes and testing.
        *Fixed a bug where MATricks values would not update properly when switching axes.
        *Fixed a bug where the cue count preview would not update properly when changing MATricks values.
        *Fixed a bug where the sequence status label would not update properly when changing sequence number.
        *Added functionality to toggle sequence tracking on/off based on checkbox state.
    - Version 0.4.1.4
        *UI Updated to latest version of mockup.
        *Still needs testing from UI Updates.
        *Added all MATricks axis!
        *Broke all MATricks axis!
    - Version 0.4.1.3
        *Started the New UI, removed some other stuff
    - Version 0.4.1.2Beta
        *Fixed MATricks... maybe. I was mistreating Wings.
        *Added a function to delete any extra cues the plugin might create. This will be removed once MAtricks verified
        *Fixed checkbox bug.
        *Probably gonna remove settings menu and have the user edit settings at the top of the plugin.
               This is because having multiple UIs stack, and also trying to get input from the UI to save after the plugin closes is hard.
---------------
   (OLD) Known Bugs:
            *Selecting Shuffle will give you a random value once you select it. To change the value, you can type something in or press the shuffle button again. 
               The bug is that sometimes you need to press the shuffle button two or three times to get it to generate a new seed.
    *Some UI Elements appear to not have a border until they are interacted with.
    *If the group does not have Y Axis information, and you try to add Y Axis MATricks, the plugin will only create one cue. This is how default MA works, because by default the selection will have 1 level of y axis. However, I plan to add a feature that will detect and fix this problem. For now, it is up to the user to only utilize Y MAtricks if the group has it in selection.
    *Some more issues persist with Y Axis. For example, if there are 20 X Axis values, and only 10 Y Axis values, everything past Y=10 will be a blank cue and will not be created. 
        Not sure if this is how you want it to function, but I can create something that works around this if needed.
---------------        
    TODO:
            *Change the way plugin handles Overwritting sequences.
            *Add MATricks axis detections to avoid unwanted MATricks confusion.
            *Remove Settings Menu
            *Organize states and default values for easy user editing.
            *Final touches to UI and additional changes as needed.

--]]
local pluginName, componentName, signalTable, myHandle = select(1, ...)

return function()
  ------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------
  -- Utility functions for common operations
  local function msg(s)        Printf("[StabberUI] %s", s) end  -- Console info message
  local function err(s)        ErrPrintf("[StabberUI] %s", s) end  -- Console error message
  local function trim(s)       return (tostring(s or ""):gsub("^%s+"," "):gsub("%s+$"," ")) end  -- Remove excess whitespace
  local function toInt(s)      s = trim(s); local n = tonumber(s); return n and math.floor(n) or nil end  -- Safe string-to-integer conversion
  
  -- Execute a command with error handling
  local function safeCmd(s)
    local ok, why = pcall(Cmd, s)
    if not ok then err("Cmd failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  -- Check if a sequence exists in the DataPool
  -- Used to warn user before overwriting and to update sequence status
  local function seqExists(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Sequences then return false end
    return dp.Sequences[num] ~= nil
  end

  -- Check if a group exists (used for validation before building)
  local function groupSeemsToExist(num)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.Groups then return true end
    return dp.Groups[num] ~= nil
  end

  -- Check if a preset exists in the specified pool
  local function presetSeemsToExist(poolIdx, presetIdx)
    local ok, dp = pcall(DataPool)
    if not ok or not dp or not dp.PresetPools then return true end
    local pool = dp.PresetPools[poolIdx]
    if not pool then return false end
    local ok2, child = pcall(function() return pool[presetIdx] end)
    if ok2 and child ~= nil then return true end
    return true
  end

  -- Fisher-Yates shuffle algorithm for randomizing table order
  local function shuffle(tbl)
    for i = #tbl, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
  end

  -- Count total fixtures in a group by selecting it and iterating selection
  -- Clears selection before and after to avoid affecting user's work
  local function countGroupFixtures(gNum)
    safeCmd("ClearAll")
    safeCmd("Group " .. gNum)
    local count, idx = 0, SelectionFirst()
    while idx do count = count + 1; idx = SelectionNext(idx) end
    safeCmd("ClearAll")
    return count
  end
  -- Clean up empty cues that may be created when Y-axis fixtures run out
  -- This happens when group has different X/Y dimensions (e.g., 20 X-axis but only 10 Y-axis)
  -- Collects empty cues first to avoid iterator issues during deletion
local function deleteEmptyCues(seqNum)
  local dp = DataPool()
  local seq = dp.Sequences and dp.Sequences[seqNum]
  if not seq then
    msg("Sequence not found: " .. tostring(seqNum))
    return
  end
  
  -- Collect empty cues first to avoid iterator issues during deletion
  local cuesToDelete = {}
  for _, cue in ipairs(seq:Children() or {}) do
    local isEmpty = true
    for _, part in ipairs(cue:Children() or {}) do
      if GetPresetData(part).count > 0 then isEmpty = false break end
    end
    if isEmpty then
      cuesToDelete[#cuesToDelete + 1] = cue
    end
  end
  
  -- Delete collected empty cues using Lua API
  for _, cue in ipairs(cuesToDelete) do
    local cueNo = cue.no
    local actualCueNo = cueNo and (cueNo / 1000) or '?'
    local ok, why = pcall(function()
      Obj.Delete(seq, Obj.Index(cue))
    end)
    if ok then
      msg('Deleted empty cue: ' .. actualCueNo)
    else
      err('Failed to delete cue ' .. actualCueNo .. ': ' .. tostring(why))
    end
  end
end

 local function openSettings(caller)   --Still actively working on the settings menu.
      local returnTable = MessageBox(
                {
                title = 'Stabber Pro Settings',
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
                value = "1",
                whiteFilter = '1234567890',
                vkPlugin = 'NumericInput',
                }
            },







--[[        
            states = {{
                name = 'Enable Edit Sequence Dialoge on Build', -- The name displayed on the checkbox
                state = true -- Boolean determining if the checkbox defaults to checked (true) or unchecked (false)
                }},]]

                -- Selectors include two types of buttons: Swipe buttons (type 0) or Radio buttons (type 1). The selected value is returned by the function
                --'selectors' requires  a table of data for the selectors. That table of selectors requires an individual table for each selector
                -- Selectors are displayed in the order in which they appear in the table, but Radio buttons are always displayed before Swipe buttons
                selectors = {
                    {
                name = 'Default Mode', -- The name displayed on the selector
                selectedValue = 1, -- The value that will be seleceted by default
                type = 0, -- The type of selector
                values = {['Straight'] = 1, ['Shuffle'] = 2, ['Scatter'] = 3} -- The values: ['Displayed Name'] = value (to be returned)
                }, 
                {
                name = 'Edit Sequence Dialoge on Build',
                selectedValue = 1,
                type = 1,
                values = {['Enabled'] = 1, ['Disabled'] = 2, ['Option 3'] = 3}
                }
            }
            })

            -- The values returned by the MessageBox function are stored in a table. To read them, we must access the corresponding table values.
            SettingsResult = returnTable.result -- Returns the value of the command button that is pressed or the timeoutResultID, if defined, depending on how the pop-up was closed
            SettingsInputs = returnTable.inputs -- Returns a table with key/value pairs made up of the inputs' names and values
            SettingsStates = returnTable.states -- Returns a table with key/value pairs made up of the states' names and boolean values
            SettingsSelectors = returnTable.selectors -- Returns a table with key/value pairs made up of the selectors' names and boolean values
           -- GroupString = SettingsInputs{1}
           -- ModeString = SettingsSelectors{2}

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
  
  -- Get currently selected sequence information
  local function getSelectedSeq()
    local ok, seq = pcall(SelectedSequence)
    if ok and seq and seq.no then
      return {
        no = tostring(seq.no),
        name = seq.name or "Stabber Recipe"
      }
    end
    return nil
  end
--    ############################################################################################################################################################################
--    ############################################################################################################################################################################
--    #############                                  EDIT THESE STATES IF YOU WANT!!                                                                                 #############      
--    ############################################################################################################################################################################
--    ############################################################################################################################################################################






  -- Central state table holding all plugin configuration and UI values
  -- Edit these default values to change initial plugin behavior
  local SelectedSeq = getSelectedSeq()  -- Get selected sequence at startup
  local state = {
  -- Target group and sequence settings
  groupStr       = " Selection",  -- Group number or "Selection" for current selection
  seqNumStr      = (SelectedSeq and SelectedSeq.no) or "0",  -- Sequence number to create/overwrite
  seqName        = (SelectedSeq and SelectedSeq.name) or "Stabber Recipe",  -- Name for the sequence
  
  -- MAtricks axis selection and values
  maTricksAxis   = "X",  -- Currently selected axis for editing (X, Y, or Z)
  xBlock = 0, xGroup = 0, xWings = 0,  -- X-axis MAtricks parameters
  yBlock = 0, yGroup = 0, yWings = 0,  -- Y-axis MAtricks parameters
  -- zBlock = 0, zGroup = 0, zWings = 0,  -- Z axis disabled per user request
  
  -- Enable/disable flags - controls which axes are applied during sequence build
  enableMaTricksX = false,  -- When true, X-axis MAtricks will be applied
  enableMaTricksY = false,  -- When true, Y-axis MAtricks will be applied
  -- enableMaTricksZ = false,  -- Z axis disabled
  
  -- Cue timing and organization
  shuffleSeedStr = "0",  -- Seed for shuffle mode (0 = random)
  offCueFade     = "0",  -- Fade time for OffCue
  offCueDelay    = "0",  -- Delay time for OffCue
  commandDelay   = "0", -- Delay time for cue command
  presets        = {},  -- Array of {pool, index} preset references to include
  modes          = {"Straight","Shuffle","Scatter"},  -- Available cue ordering modes
  selectedMode   = 1,  -- Currently selected mode (1=Straight, 2=Shuffle, 3=Scatter)
  seqTracking = SeqTrackValue,  -- Tracking state (synced with sequence)
  cueCommand = 'Set Sequence %d Cue * Property "Command" "Goto Sequence \'%s\' cue offcue"' --Defualt is Set Sequence %d Cue * Property "Command" "Goto Sequence \'%s\' cue offcue" %s is sequenceName
}





--    ############################################################################################################################################################################
--    ############################################################################################################################################################################
--    #############                                  END OF STATES TO EDIT!!!!                                                                                       #############      
--    ############################################################################################################################################################################
--    ############################################################################################################################################################################

  -- Colors
  local CT = Root().ColorTheme.ColorGroups
  local colorTransparent     = CT.Global.Transparent
  local colorButtonPlease    = CT.Button.BackgroundPlease
  local colorFadeValue       = CT.ProgLayer.Fade
  local colorDelayValue      = CT.ProgLayer.Delay
  local colorMATx            = CT.MATricks.BackgroundX
  local colorMATy            = CT.MATricks.BackgroundY
  -- local colorMATz            = CT.MATricks.BackgroundZ  -- Z axis disabled
  -- Terrible way to fix some bugs lmao
  local cuePreview, lblBlock, lblGroup, lblWings, mX, mY, mZ, enableX, enableY, enableZ, chkTracking, seqStatusLabel

  
-- MAtricks helpers
-- These functions handle MAtricks value calculation and preview
-- MAtricks divides fixtures into groups for sequencing:
-- - Block: Fixtures per cue step
-- - Group: Total number of cue groups (overrides Block/Wings)
-- - Wings: Symmetrical wings around center block

local function previewCueCount()
  -- Calculate and display the number of cues that will be created
  -- based on current group size and enabled MAtricks settings
  local groupNum = toInt(state.groupStr)
  if not groupNum or groupNum < 1 then if cuePreview then cuePreview.Text = "—" end; return end
  
  local N = countGroupFixtures(groupNum)  -- Total fixtures in group
  if N < 1 then if cuePreview then cuePreview.Text = "0 (empty)" end; return end
  
  -- Check if ANY MATricks are enabled
  if not state.enableMaTricksX and not state.enableMaTricksY then  -- and not state.enableMaTricksZ (Z axis disabled)
    -- No MATricks: one cue per fixture (default behavior)
    if cuePreview then cuePreview.Text = tostring(N) end
    return
  end
  
  -- Use the enabled axis values to calculate cue count
  local xBlock, xGroup, xWings = 0, 0, 0
  local yBlock, yGroup, yWings = 0, 0, 0
  -- local zBlock, zGroup, zWings = 0, 0, 0  -- Z axis disabled
  
  if state.enableMaTricksX then
    xBlock = state.xBlock
    xGroup = state.xGroup
    xWings = state.xWings
  end
  
  if state.enableMaTricksY then
    yBlock = state.yBlock
    yGroup = state.yGroup
    yWings = state.yWings
  end
  
  -- if state.enableMaTricksZ then  -- Z axis disabled
  --   zBlock = state.zBlock
  --   zGroup = state.zGroup
  --   zWings = state.zWings
  -- end
  
  local totalCues
  -- Group value directly specifies cue count and overrides Block/Wings calculation
  -- This is MA3's standard behavior - Group takes priority over other MAtricks parameters
  if xGroup > 0 or yGroup > 0 then  -- or zGroup > 0 (Z axis disabled)
    totalCues = math.max(xGroup, yGroup)  -- Use the highest group value from enabled axes
  else
    -- When no Group is set, calculate cue count from Block and Wings
    -- Formula: totalCues = ceil(fixtures / (Block * Wings))
    local xCues = N  -- Default to fixture count
    local yCues = N
    -- local zCues = N  -- Z axis disabled
    
    if state.enableMaTricksX then
      local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
      if perX > 0 then xCues = math.ceil(N / perX) end
    end
    
    if state.enableMaTricksY then
      local perY = (yBlock > 0 and yBlock or 1) * (yWings > 0 and yWings or 1)
      if perY > 0 then yCues = math.ceil(N / perY) end
    end
    
    -- if state.enableMaTricksZ then  -- Z axis disabled
    --   local perZ = (zBlock > 0 and zBlock or 1) * (zWings > 0 and zWings or 1)
    --   if perZ > 0 then zCues = math.ceil(N / perZ) end
    -- end
    
    -- Use the maximum needed cues from all enabled axes
    totalCues = math.max(xCues, yCues)  -- , zCues (Z axis disabled)
  end
  
  if cuePreview then cuePreview.Text = tostring(totalCues) end
end
-- Get MAtricks values for the currently selected axis
-- Returns table with block, group, wings values
local function getCurrentMaTricksValues()
  local axis = state.maTricksAxis
  return {
    block = state[axis:lower().."Block"],
    group = state[axis:lower().."Group"],
    wings = state[axis:lower().."Wings"]
  }
end

-- Update UI labels to display current MAtricks values for selected axis
local function updateMaTricksLabels()
  local vals = getCurrentMaTricksValues()
  local axis = state.maTricksAxis
  if lblBlock then lblBlock.Text = axis.."Block: "..vals.block end
  if lblGroup then lblGroup.Text = axis.."Group: "..vals.group end
  if lblWings then lblWings.Text = axis.."Wings: "..vals.wings end
  previewCueCount()  -- Recalculate cue count with new values
end

-- Set a MAtricks value for the currently selected axis
-- Value is clamped to minimum of 0
local function setCurrentMaTricksValue(key, val)
  local axis = state.maTricksAxis:lower()
  state[axis..key] = math.max(0, val)  -- Prevent negative values
  updateMaTricksLabels()
end

-- Update the sequence status display and sync tracking state
-- Called when sequence number changes or plugin initializes
local function updateSeqStatus()
  if not seqStatusLabel then return end
  
  local seqNum = toInt(state.seqNumStr)
  if not seqNum or seqNum < 1 then
    seqStatusLabel.Text = "Sequ State: Invalid"
    seqStatusLabel.TextAlignmentH = "Center"
    seqStatusLabel.TextColor = 1.31  -- Yellow for invalid
    return
  end
  
  if seqExists(seqNum) then
    seqStatusLabel.Text = "Sequ State: Not Empty"
    seqStatusLabel.TextAlignmentH = "Center"
    seqStatusLabel.TextColor = 1.32  -- Red warns user of potential overwrite
    
    -- Sync tracking checkbox with sequence's current tracking state
    -- This ensures UI reflects the actual sequence setting when switching sequences
    local ok, dp = pcall(DataPool)
    if ok and dp and dp.Sequences then
      local seq = dp.Sequences[seqNum]
      if seq and seq.tracking ~= nil then
        state.seqTracking = seq.tracking
        if chkTracking then 
          chkTracking.State = state.seqTracking 
        end
      end
    end
  else
    seqStatusLabel.Text = "Sequ State: Empty"
    seqStatusLabel.TextAlignmentH = "Center"
    seqStatusLabel.TextColor = 1.33  -- Green indicates safe to build
  end
end

local function toggleSeqTracking(seqNum) --This handles toggling sequence tracking. It also ensures RestartMode is set to Next Cue.
  -- Validate sequence number
  if not seqNum or seqNum < 1 then
    err("Invalid sequence number for tracking: " .. tostring(seqNum))
    return
  end
  
  -- Safely get DataPool and sequence
  local ok, dp = pcall(DataPool)
  if not ok or not dp or not dp.Sequences then
    err("Cannot access DataPool for tracking")
    return
  end
  
  local seq = dp.Sequences[seqNum]
  if not seq then
    err("Sequence " .. tostring(seqNum) .. " not found for tracking")
    return
  end
  
  -- Always set RestartMode to Next Cue
  local success1, error1 = pcall(function()
    seq:Set("RestartMode", "Next Cue")
  end)
  
  if not success1 then
    err("Failed to set RestartMode on Sequence " .. tostring(seqNum) .. ": " .. tostring(error1))
  else
    msg("RestartMode set to Next Cue for Sequence " .. tostring(seqNum))
  end
end

-- Switch the currently selected MAtricks axis for editing
-- Updates radio buttons and label colors to match MA3 color scheme
local function setMaTricksAxis(axis)
  state.maTricksAxis = axis
  
  -- Update radio button states
  if mX then mX.State = (axis=="X") and 1 or 0 end
  if mY then mY.State = (axis=="Y") and 1 or 0 end
  -- if mZ then mZ.State = (axis=="Z") and 1 or 0 end  -- Z axis disabled
  
  -- Update MAtricks label colors to match selected axis (uses MA3 theme colors)
  local axisColor
  if axis == "X" then
    axisColor = colorMATx  -- Red for X
  elseif axis == "Y" then
    axisColor = colorMATy  -- Green for Y
  -- elseif axis == "Z" then  -- Z axis disabled
  --   axisColor = colorMATz  -- Blue for Z
  end
  
  if lblBlock then lblBlock.BackColor = axisColor end
  if lblGroup then lblGroup.BackColor = axisColor end
  if lblWings then lblWings.BackColor = axisColor end
  
  updateMaTricksLabels()  -- Refresh labels to show values for new axis
end


  local function presetsDisplay() --Gatheres the current presets added to the table. The UI will call this function to update all selected presets.
    if #state.presets == 0 then return "None" end
    local buf = {}
    for i, pr in ipairs(state.presets) do
      buf[#buf+1] = (pr.pool .. "." .. pr.index)
    end
    return table.concat(buf, ", ")
  end

  ------------------------------------------------------------
  -- Main UI setup
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
  titleBar.Columns = 10  
  titleBar.Rows = 1
  titleBar.Anchors = "0,0"
  titleBar[2][2].SizePolicy = "Fixed"
  titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"
  
  local titleBarIcon = titleBar:Append("TitleButton")
  titleBarIcon.Text = "StabberPro"
  titleBarIcon.Texture = "corner1"
  --titleBarIcon.Anchors = "0,0"
  titleBarIcon.Icon = "star"
  
  local titleBarCloseButton = titleBar:Append("CloseButton")
  titleBarCloseButton.Anchors = "9,0"
  titleBarCloseButton.Texture = "corner2"

  local titleBarSettings = titleBar:Append("TitleButton")
  titleBarSettings.Icon = "settings"
  titleBarSettings.Anchors = "8,0"
  titleBarSettings.Clicked = "OnOpenSettings"
  titleBarSettings.PluginComponent=myHandle;
  
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
form.Columns = 4; form.Rows = 8  -- Increased rows for new layout
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

-- Row 0: Selection + Value label, Group Picker, Preset Picker
mkLabel("Selection + Value", 0,0,0,0)

local bGroup = form:Append("Button")
bGroup.Anchors={left=1,right=1,top=0,bottom=0}  -- Only column 1
bGroup.Text = (state.groupStr~="" and ("Group"..state.groupStr)) or "Select Group"
bGroup.PluginComponent=myHandle
bGroup.Clicked="OnOpenGroupPicker"
bGroup.BackColor = colorButtonPlease
bGroup.TextalignmentH = "Center"

local pPick = form:Append("Button")
pPick.Text = "Pick Preset"
pPick.PluginComponent=myHandle
pPick.Clicked="OnOpenPresetPicker"
pPick.Anchors={left=2,right=3,top=0,bottom=0}  -- Columns 2-3

-- Row 1: Sequence Name (columns 0-2) and Sequence # (column 3)
mkLabel("Seq Name", 0,0,1,1)
local eSeqName = form:Append("LineEdit")
eSeqName.Anchors={left=1,right=1,top=1,bottom=1}
eSeqName.Content = state.seqName
eSeqName.TextAutoAdjust="Yes"
eSeqName.PluginComponent=myHandle
eSeqName.TextChanged="OnSeqNameChanged"
eSeqName.TextalignmentH = "Left"

mkLabel("Seq #", 2,2,1,1)
local eSeqNum = form:Append("LineEdit")
eSeqNum.Content = state.seqNumStr
eSeqNum.TextAutoAdjust = "Yes"
eSeqNum.Anchors = {left=3,right=3,top=1,bottom=1}
eSeqNum.Padding = "4,4"
eSeqNum.MaxTextLength = 32
eSeqNum.HideFocusFrame = "Yes"
eSeqNum.Filter = "0123456789"
eSeqNum.VkPluginName = "TextInputNumOnly"
eSeqNum.PluginComponent = myHandle
eSeqNum.TextChanged = "OnSeqNumChanged"

-- Row 2: Tracking checkbox + Sequence Exist Check
mkLabel("Tracking", 0,0,2,2)
chkTracking = form:Append("CheckBox")
chkTracking.Text=""
chkTracking.State=state.seqTracking
chkTracking.Anchors={left=1,right=1,top=2,bottom=2}
chkTracking.PluginComponent=myHandle
chkTracking.Clicked="OnSeqTracking"

seqStatusLabel = form:Append("Button")
seqStatusLabel.Text = "Sequ State: Empty"
seqStatusLabel.TextalignmentH = "Left"
seqStatusLabel.Font = "Medium20"
seqStatusLabel.TextColor = 1.33  -- Green by default
seqStatusLabel.Anchors = {left=2,right=3,top=2,bottom=2}
seqStatusLabel.PluginComponent = myHandle
seqStatusLabel.Clicked = "OnSeqStatusClick"


-- Row 3: OffCue Fade
mkLine("OffCue Fade", state.offCueFade, "OnOffFadeChanged", 0,3,3,3, false, colorFadeValue)

-- Row 4: OffCue Delay
mkLine("OffCue Delay", state.offCueDelay, "OnOffDelayChanged", 0,3,4,4, false, colorDelayValue)
-- Row 5: Command Delay
mkLine("Command Delay",state.commandDelay, "OnCommandDelayChanged", 0,3,5,5, false, colorDelayValue)

-- Row 6: Shuffle Seed
local editShuffleSeed = mkLine("Shuffle Seed", state.shuffleSeedStr, "OnShuffleSeedChanged", 0,3,6,6, true)

-- Row 7: Mode selector (Straight/Shuffle/Scatter)
mkLabel("Mode", 0,0,7,7)
local mStraight = form:Append("CheckBox")
mStraight.Text="Straight"
mStraight.State=1
mStraight.Anchors={left=1,right=1,top=7,bottom=7}
mStraight.PluginComponent=myHandle
mStraight.Clicked="OnModeStraight"

local mShuffle = form:Append("CheckBox")
mShuffle.Text="Shuffle"
mShuffle.State=0
mShuffle.Anchors={left=2,right=2,top=7,bottom=7}
mShuffle.PluginComponent=myHandle
mShuffle.Clicked="OnModeShuffle"

local mScatter = form:Append("CheckBox")
mScatter.Text="Scatter"
mScatter.State=0
mScatter.Anchors={left=3,right=3,top=7,bottom=7}
mScatter.PluginComponent=myHandle
mScatter.Clicked="OnModeScatter"

------------------------------------------------------------
-- Right Side: Preset Manager + MAtricks
------------------------------------------------------------
local right = main:Append("UILayoutGrid")
right.Columns = 4; right.Rows = 8  -- Changed to 4 columns, back to 8 rows
right.BackColor = colorTransparent
right.Anchors = {left=1,right=1,top=0,bottom=0}

-- Row 0-1: Preset list display (full width)
local pList = right:Append("Button")
pList.Anchors = {left=0,right=3,top=0,bottom=1}
pList.HasHover = "No"
pList.TextalignmentH = "Left"
pList.Text = "Presets: " .. presetsDisplay()
pList.Padding = "8,8"

-- Row 2: Clear Presets, Status, and Cue Count
local pClear = right:Append("Button")
pClear.Anchors = {left=0,right=0,top=2,bottom=2}
pClear.Text = "Clear Presets"
pClear.PluginComponent = myHandle
pClear.Clicked = "OnPresetClear"

local status = right:Append("Button")
status.Anchors = {left=1,right=2,top=2,bottom=2}
status.HasHover = "No"
status.TextalignmentH = "Left"
status.Text = "Ready"

local cueCountLabel = right:Append("UIObject")
cueCountLabel.Text = "Made by LXTater"
cueCountLabel.TextalignmentH = "Right"
cueCountLabel.Font = "Medium20"
cueCountLabel.HasHover = "No"
cueCountLabel.Anchors = {left=2,right=2,top=2,bottom=2}


cuePreview = right:Append("AppearancePreview")
cuePreview.Appearance = GetObject('Image 3.LXTaterLogo')
cuePreview.Interactive = 'No'
cuePreview.Anchors = {left=3,right=3,top=2,bottom=3}


-- Row 3: MAtricks selector (X/Y/Z) - for editing which axis
local maTricksLabel = right:Append("UIObject")
maTricksLabel.Text = "MAtricks"
maTricksLabel.TextalignmentH = "Right"
maTricksLabel.Font = "Medium20"
maTricksLabel.HasHover = "No"
maTricksLabel.Anchors = {left=0,right=0,top=3,bottom=3}

mX = right:Append("CheckBox")
mX.Text="X"
mX.State=1
mX.Anchors={left=1,right=1,top=3,bottom=3}
mX.PluginComponent=myHandle
mX.Clicked="OnMaTricksX"

mY = right:Append("CheckBox")
mY.Text="Y"
mY.State=0
mY.Anchors={left=2,right=2,top=3,bottom=3}
mY.PluginComponent=myHandle
mY.Clicked="OnMaTricksY"

-- mZ = right:Append("CheckBox")  -- Z axis disabled
-- mZ.Text="Z"
-- mZ.State=0
-- mZ.Anchors={left=3,right=3,top=3,bottom=3}
-- mZ.PluginComponent=myHandle
-- mZ.Clicked="OnMaTricksZ"

-- Helper to create +/- buttons with label (now uses 4 columns)
local function mkMaTricksRow(label, row, subtractKey, addKey, labelClickKey)
  local btnSub = right:Append("Button")
  btnSub.Text = "-"
  btnSub.Anchors = {left=0,right=0,top=row,bottom=row}
  btnSub.PluginComponent = myHandle
  btnSub.Clicked = subtractKey
  
  local lblVal = right:Append("Button")
  lblVal.Text = label .. ": 0"
  lblVal.Anchors = {left=1,right=2,top=row,bottom=row}  -- Spans 2 columns for more space
  lblVal.TextalignmentH = "Center"
  lblVal.PluginComponent = myHandle
  lblVal.Clicked = labelClickKey
  lblVal.BackColor = colorMATx  -- Default to X color, will update when axis changes
  
  local btnAdd = right:Append("Button")
  btnAdd.Text = "+"
  btnAdd.Anchors = {left=3,right=3,top=row,bottom=row}
  btnAdd.PluginComponent = myHandle
  btnAdd.Clicked = addKey
  
  return lblVal
end

-- Row 4: Block
lblBlock = mkMaTricksRow("XBlock", 4, "OnBlockSubtract", "OnBlockAdd", "OnBlockClick")

-- Row 5: Group
lblGroup = mkMaTricksRow("XGroup", 5, "OnGroupSubtract", "OnGroupAdd", "OnGroupClick")

-- Row 6: Wings
lblWings = mkMaTricksRow("XWings", 6, "OnWingsSubtract", "OnWingsAdd", "OnWingsClick")

-- Row 7: Enable MAtricks selector (X/Y/Z) - controls which axes are applied
local enableLabel = right:Append("UIObject")
enableLabel.Text = "Enable MATricks"
enableLabel.TextalignmentH = "Right"
enableLabel.Font = "Medium20"
enableLabel.HasHover = "No"
enableLabel.Anchors = {left=0,right=0,top=7,bottom=7}

enableX = right:Append("CheckBox")
enableX.Text="X"
enableX.State=0
enableX.Anchors={left=1,right=1,top=7,bottom=7}
enableX.PluginComponent=myHandle
enableX.Clicked="OnEnableX"

enableY = right:Append("CheckBox")
enableY.Text="Y"
enableY.State=0
enableY.Anchors={left=2,right=2,top=7,bottom=7}
enableY.PluginComponent=myHandle
enableY.Clicked="OnEnableY"

-- enableZ = right:Append("CheckBox")  -- Z axis disabled
-- enableZ.Text="Z"
-- enableZ.State=0
-- enableZ.Anchors={left=3,right=3,top=7,bottom=7}
-- enableZ.PluginComponent=myHandle
-- enableZ.Clicked="OnEnableZ"
  ------------------------------------------------------------
  -- Button Row: Build / Cancel
  ------------------------------------------------------------
  local buttons = dlg:Append("UILayoutGrid"); buttons.Columns = 2; buttons.Rows = 1
  buttons.Anchors = {left=0,right=0,top=2,bottom=2}
  buttons.BackColor = colorTransparent
  local bBuild = buttons:Append("Button"); bBuild.Text = "Build Sequence"; bBuild.Font = "Medium20"; bBuild.PluginComponent=myHandle; bBuild.Clicked="OnBuild"; bBuild.Anchors={left=0,right=0,top=0,bottom=0;}
  local bCancel= buttons:Append("Button"); bCancel.Text= "Cancel";         bCancel.Font= "Medium20"; bCancel.PluginComponent=myHandle; bCancel.Clicked="OnCancel"; bCancel.Anchors={left=1,right=1,top=0,bottom=0}

  ------------------------------------------------------------
  -- Internal helpers (UI <-> state)
  ------------------------------------------------------------
  local function refreshPresetList()  --Dynamically update selected preset table display
    pList.Text = "Presets: " .. presetsDisplay()
  end


  local function closeWindow()
    Obj.Delete(screenOverlay, Obj.Index(baseInput))
  end

  ------------------------------------------------------------
  -- Signals (UI event handlers) 
  ------------------------------------------------------------
  -- These functions respond to user interactions with UI elements
  -- Input validation prevents crashes and provides helpful error messages
  
  signalTable.OnOpenSettings = function(caller) openSettings(caller) end
  signalTable.OnCancel = function() closeWindow() end
  
  -- Main "Build Sequence" button handler
  -- This is where all the magic happens - validates input and creates the sequence
  signalTable.OnBuild  = function()
    -- === Step 1: Validate all input values ===
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

    -- === Step 2: Gather MATricks values from enabled axes only ===
    -- Only axes with "Enable" checkbox checked will affect the sequence
    local xBlock, xGroup, xWings = 0, 0, 0
    local yBlock, yGroup, yWings = 0, 0, 0
    local zBlock, zGroup, zWings = 0, 0, 0
    
    if state.enableMaTricksX then
      xBlock = state.xBlock
      xGroup = state.xGroup
      xWings = state.xWings
    end
    
    if state.enableMaTricksY then
      yBlock = state.yBlock
      yGroup = state.yGroup
      yWings = state.yWings
    end
    
    -- if state.enableMaTricksZ then  -- Z axis disabled
    --   zBlock = state.zBlock
    --   zGroup = state.zGroup
    --   zWings = state.zWings
    -- end
    local shuffleSeed = toInt(state.shuffleSeedStr) or 0

    if #state.presets == 0 then err("No presets entered."); status.Text = "Error: No presets"; return end

if #state.presets == 0 then err("No presets entered."); status.Text = "Error: No presets"; return end

    -- Determine total cues based on ALL enabled axes
    local totalCues
    local N = countGroupFixtures(groupNum)
    if N < 1 then err("Group appears empty."); status.Text = "Error: Empty group"; return end
    
    -- Check if ANY MATricks are enabled
    if not state.enableMaTricksX and not state.enableMaTricksY then  -- and not state.enableMaTricksZ (Z axis disabled)
      -- No MATricks: one cue per fixture
      totalCues = N
    else
      -- Check if any Group is set (Group overrides Block/Wings)
      if xGroup > 0 or yGroup > 0 then  -- or zGroup > 0 (Z axis disabled)
        totalCues = math.max(xGroup, yGroup)  -- , zGroup (Z axis disabled)
      else
        -- Calculate based on enabled Block/Wings values
        local xCues = N  -- Default to fixture count
        local yCues = N
        -- local zCues = N  -- Z axis disabled
        
        if state.enableMaTricksX then
          local perX = (xBlock > 0 and xBlock or 1) * (xWings > 0 and xWings or 1)
          if perX > 0 then xCues = math.ceil(N / perX) end
        end
        
        if state.enableMaTricksY then
          local perY = (yBlock > 0 and yBlock or 1) * (yWings > 0 and yWings or 1)
          if perY > 0 then yCues = math.ceil(N / perY) end
        end
        
        -- if state.enableMaTricksZ then  -- Z axis disabled
        --   local perZ = (zBlock > 0 and zBlock or 1) * (zWings > 0 and zWings or 1)
        --   if perZ > 0 then zCues = math.ceil(N / perZ) end
        -- end
        
        -- Use the maximum needed cues from all enabled axes
        totalCues = math.max(xCues, yCues)  -- , zCues (Z axis disabled)
      end
    end

    -- Overwrite protection
   if seqExists(seqNum) then
      local idx = select(1, PopupInput{title = string.format("Sequence %d exists. Overwrite?", seqNum), caller=bBuild, items={"No","Yes"}}) or 1 --Need to change these from Commands to Lua API
      if idx ~= 2 then status.Text = "Canceled (preserve seq)"; return end
      if not safeCmd('Delete Sequence '..seqNum..' cue * /NC') then
        if not safeCmd('Delete Sequence '..seqNum..' cue * /NC') then err("Unable to delete existing Sequence "..seqNum); status.Text = "Error: Delete failed"; return end
      end
    end

    -- Create target sequence
    if not safeCmd('Store Sequence '..seqNum) then status.Text = "Error: Store seq"; return end --Need to change these from Commands to Lua API
    if not safeCmd('Set Sequence '..seqNum..' Property "Name" "'..state.seqName..'"') then status.Text = "Error: Name seq"; return end

    -- === Step 3: Prepare sequence values based on selected mode ===
    -- Straight: 1, 2, 3, 4... (sequential order)
    -- Shuffle: Random order based on seed
    -- Scatter: Alternating from ends towards center (1, N, 2, N-1, 3, N-2...)
    local seq_values = {}; for i=1,totalCues do seq_values[i]=i end
    local mode = state.modes[state.selectedMode]
    if mode == "Shuffle" then
      math.randomseed(shuffleSeed > 0 and shuffleSeed or os.time())
      shuffle(seq_values)
    elseif mode == "Scatter" then
      local low, high, idx = 1, totalCues, 1
      while low <= high do
        seq_values[idx] = low; idx = idx + 1
        if low ~= high then seq_values[idx] = high; idx = idx + 1 end
        low = low + 1; high = high - 1
      end
    end

    -- === Step 4: Build cues and parts ===
    -- Each cue gets a part for each preset selected
    for c = 1, totalCues do
      if not safeCmd('Store Sequence '..seqNum..' Cue '..c) then status.Text = "Error: store cue"; return end --Need to change these from Commands to Lua API
      for p = 1, #state.presets do
        local partStr = '0.'..p
        local pr = state.presets[p]
        if not safeCmd('Store Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: store part"; return end --Need to change these from Commands to Lua API
        if not safeCmd('Assign Group '..groupNum..' At Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: assign group"; return end
        if not safeCmd('Assign Preset '..pr.pool..'.'..pr.index..' At Sequence '..seqNum..' Cue '..c..' Part '..partStr) then status.Text="Error: assign preset"; return end
        
        -- X value is always applied (MA3 requires at least one axis)
        if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "X" '..seq_values[c]) then status.Text="Error: set X"; return end --Need to change these from Commands to Lua API
        
        -- Y and Z values only applied if those axes are enabled
        if state.enableMaTricksY then
          if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "Y" '..seq_values[c]) then status.Text="Error: set Y"; return end --Need to change these from Commands to Lua API
        end
        
        -- -- Only apply Z value if Z MATricks is enabled  -- Z axis disabled
        -- if state.enableMaTricksZ then
        --   if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "Z" '..seq_values[c]) then status.Text="Error: set Z"; return end
        -- end
        
        -- Apply X MATricks
        if xGroup > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XGroup" '..xGroup) then status.Text="Error: XGroup"; return end end
        if xBlock > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XBlock" '..xBlock) then status.Text="Error: XBlock"; return end end
        if xWings > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XWings" '..xWings) then status.Text="Error: XWings"; return end end
        
        -- Apply Y MATricks
        if yGroup > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "YGroup" '..yGroup) then status.Text="Error: YGroup"; return end end
        if yBlock > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "YBlock" '..yBlock) then status.Text="Error: YBlock"; return end end
        if yWings > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "YWings" '..yWings) then status.Text="Error: YWings"; return end end
        
        -- -- Apply Z MATricks  -- Z axis disabled
        -- if zGroup > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "ZGroup" '..zGroup) then status.Text="Error: ZGroup"; return end end
        -- if zBlock > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "ZBlock" '..zBlock) then status.Text="Error: ZBlock"; return end end
        -- if zWings > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "ZWings" '..zWings) then status.Text="Error: ZWings"; return end end
        if shuffleSeed > 0 then if not safeCmd('Set Sequence '..seqNum..' Cue '..c..' Part '..partStr..' Property "XShuffle" '..shuffleSeed) then status.Text="Error: XShuffle"; return end end --Need to change these from Commands to Lua API
      end
    end

    -- Finish
    local trueName = DataPool().Sequences[seqNum].name --Need to change these from Commands to Lua API
    safeCmd('Store Macro "TempEditSequMacro')
    safeCmd('Store Macro "TempEditSequMacro" "EditSequ"')
    safeCmd('Store Macro "TempEditSequMacro" "DeleteMacro"')
    safeCmd(string.format('Set Macro "TempEditSequMacro"."EditSequ" Property "Command" "Edit Sequence %d"',seqNum))
    safeCmd('Set Macro "TempEditSequMacro"."DeleteMacro" Property Command "Delete Macro TempEditSequMacro /NC"')
    safeCmd(string.format(state.cueCommand, seqNum, trueName)) --state.cuecommand line to change command
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueFade" "\'%s\'"', seqNum, state.offCueFade))
    safeCmd(string.format('Set Sequence %d Cue "OffCue" Property "CueDelay" "\'%s\'"', seqNum, state.offCueDelay))
    safeCmd(string.format('Set Sequence %d Property "CommandDelay" "\'%s\'', seqNum, state.commandDelay))
    deleteEmptyCues(seqNum)
    status.Text = "Done. Built "..totalCues.." cue(s)."
    safeCmd('Call Macro "TempEditSequMacro"')
    safeCmd('Delete Macro "TempEditSequMacro"')
    toggleSeqTracking(seqNum)  -- Run tracking toggle before exit
    closeWindow()
  end

  signalTable.OnSeqNumChanged       = function(c) state.seqNumStr      = trim(c.Content); updateSeqStatus() end
  signalTable.OnSeqNameChanged      = function(c) state.seqName        = c.Content end
  signalTable.OnSeqStatusClick      = function()
    -- Update to currently selected sequence
    local currentSeq = SelectedSequence()
    SelectedSequence = 1
    if currentSeq then
      state.seqNumStr = tostring(currentSeq.no or "201")
      state.seqName = currentSeq.name or "Stabber Recipe"
      -- Update UI elements
      if eSeqNum then eSeqNum.Content = state.seqNumStr end
      if eSeqName then eSeqName.Content = state.seqName end
      updateSeqStatus()
      msg("Updated to selected sequence: "..state.seqNumStr)
    else
      err("No sequence selected")
      state.seqNumStr = tostring("0")
      state.seqName = "No Sequence Selected"
      status.Text = "Error: No sequence selected"
    end
  end
  signalTable.OnXGroupChanged       = function(c) state.xGroupStr      = trim(c.Content); previewCueCount() end
  signalTable.OnXBlockChanged       = function(c) state.xBlockStr      = trim(c.Content); previewCueCount() end
  signalTable.OnXWingsChanged       = function(c) state.xWingsStr      = trim(c.Content); previewCueCount() end
  signalTable.OnShuffleSeedChanged  = function(c) state.shuffleSeedStr = trim(c.Content) end
  signalTable.OnOffFadeChanged      = function(c) state.offCueFade     = trim(c.Content) end
  signalTable.OnOffDelayChanged     = function(c) state.offCueDelay    = trim(c.Content) end
  -- MAtricks axis selection
signalTable.OnMaTricksX = function() setMaTricksAxis("X") end
signalTable.OnMaTricksY = function() setMaTricksAxis("Y") end
-- signalTable.OnMaTricksZ = function() setMaTricksAxis("Z") end  -- Z axis disabled

-- Block controls
signalTable.OnBlockSubtract = function() setCurrentMaTricksValue("Block", getCurrentMaTricksValues().block - 1) end
signalTable.OnBlockAdd = function() setCurrentMaTricksValue("Block", getCurrentMaTricksValues().block + 1) end
signalTable.OnBlockClick = function()
  local val = PopupInput{title="Enter "..state.maTricksAxis.."Block value", caller=lblBlock, items={}, textInput=tostring(getCurrentMaTricksValues().block)}
  if val then setCurrentMaTricksValue("Block", toInt(val) or 0) end
end

-- Group controls
signalTable.OnGroupSubtract = function() setCurrentMaTricksValue("Group", getCurrentMaTricksValues().group - 1) end
signalTable.OnGroupAdd = function() setCurrentMaTricksValue("Group", getCurrentMaTricksValues().group + 1) end
signalTable.OnGroupClick = function()
  local val = PopupInput{title="Enter "..state.maTricksAxis.."Group value", caller=lblGroup, items={}, textInput=tostring(getCurrentMaTricksValues().group)}
  if val then setCurrentMaTricksValue("Group", toInt(val) or 0) end
end

-- Wings controls
-- Wings value of 1 is invalid (produces same result as 0)
-- So we skip it: 0 -> 2 when incrementing, 2 -> 0 when decrementing
signalTable.OnWingsSubtract = function() 
  local currentWings = getCurrentMaTricksValues().wings
  local newWings = currentWings - 1
  if newWings == 1 then newWings = 0 end  -- Skip invalid value
  setCurrentMaTricksValue("Wings", newWings)
end
signalTable.OnWingsAdd = function() 
  local currentWings = getCurrentMaTricksValues().wings
  local newWings = currentWings + 1
  if newWings == 1 then newWings = 2 end  -- Skip invalid value
  setCurrentMaTricksValue("Wings", newWings)
end
signalTable.OnWingsClick = function()
  local val = PopupInput{title="Enter "..state.maTricksAxis.."Wings value", caller=lblWings, items={}, textInput=tostring(getCurrentMaTricksValues().wings)}
  if val then setCurrentMaTricksValue("Wings", toInt(val) or 0) end
end

  local function setMode(idx)
  state.selectedMode = tonumber(idx)
  mStraight.State = (state.selectedMode == 1) and 1 or 0
  mShuffle.State  = (state.selectedMode == 2) and 1 or 0
  mScatter.State  = (state.selectedMode == 3) and 1 or 0
  
  -- Generate random shuffle seed when shuffle mode is selected
  if state.selectedMode == 2 then
    math.randomseed(os.time())
    local randomSeed = math.random(1, 32766)
    state.shuffleSeedStr = tostring(randomSeed)
    if editShuffleSeed then
      editShuffleSeed.Content = state.shuffleSeedStr
    end
  end
end
  signalTable.OnModeStraight = function() setMode(1) end
  signalTable.OnModeShuffle  = function() setMode(2) end
  signalTable.OnModeScatter  = function() setMode(3) end

  signalTable.OnPresetClear = function()
    state.presets = {}
    refreshPresetList()
    status.Text = "Cleared presets"
  end

  -- Enable MATricks toggles
signalTable.OnEnableX = function() 
  state.enableMaTricksX = not state.enableMaTricksX
  if enableX then enableX.State = state.enableMaTricksX and 1 or 0 end
  previewCueCount()
end

signalTable.OnEnableY = function() 
  state.enableMaTricksY = not state.enableMaTricksY
  if enableY then enableY.State = state.enableMaTricksY and 1 or 0 end
  previewCueCount()
end

-- Handle tracking checkbox toggle
-- Important: Tracking state is READ from sequence when switching sequences,
-- but only WRITTEN to sequence when user manually toggles this checkbox
signalTable.OnSeqTracking = function() 
  state.seqTracking = (state.seqTracking == 1) and 0 or 1  -- Toggle between 0 and 1
  if chkTracking then chkTracking.State = state.seqTracking end
  
  -- Apply tracking change to the actual sequence immediately
  local seqNum = toInt(state.seqNumStr)
  if seqNum and seqNum >= 1 then
    local ok, dp = pcall(DataPool)
    if ok and dp and dp.Sequences then
      local seq = dp.Sequences[seqNum]
      if seq then
        local success, error = pcall(function()
          seq:Set("Tracking", state.seqTracking)
        end)
        if success then
          msg("Tracking " .. (state.seqTracking == 1 and "enabled" or "disabled") .. " for Sequence " .. tostring(seqNum))
        else
          err("Failed to set tracking on Sequence " .. tostring(seqNum) .. ": " .. tostring(error))
        end
      end
    end
  end
end

 ------------------------------------------------------------------
  -- Popups: Group Picker + Preset Picker
  ------------------------------------------------------------------
  local function openGroupPicker(caller)
    local dp = DataPool()
    local groups = dp.Groups and dp.Groups:Children() or {}
    local selectedNum = 1
    local items = {}
    for _,g in ipairs(groups) do
      local gNum = g.no or (Obj.Index(g) + 1)
      local count = #g:Children()
      items[#items+1] = string.format("%d: %s (%d)", gNum, g.name or "Group", count)
    end
    
    if #items == 0 then
      PopupInput{title = "Select Group", caller = caller, items = {"No groups found"}}
      return
    end
    
    local _, choice = PopupInput{title = "Select Group", caller = caller, items = items, selectedValue = bGroup.Text}
    if choice then
      local selectedNum = tonumber(choice:match("^(%d+)"))
      if selectedNum then
        local selectedGroupName = dp.Groups[selectedNum].name or "Select Group"
        bGroup.Text = "Group "..selectedGroupName
        state.groupStr = tostring(selectedNum)
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
updateSeqStatus()  -- Initialize sequence status display
updateMaTricksLabels()  -- Initialize MAtricks labels
previewCueCount()
setMaTricksAxis("X")  -- Initialize colors to X axis
end
