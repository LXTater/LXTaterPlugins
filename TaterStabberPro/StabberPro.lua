-- working MA3 2.1.1.5 on 12/21/24
-- notes:

--

-- Plugin metadata: These are standard parameters passed to the plugin function.
local pluginName = select(1, ...)     -- Name of the plugin.
local componentName = select(2, ...)  -- Component name.
local signalTable = select(3, ...)    -- Table for signal handlers (event callbacks).
local myHandle = select(4, ...)       -- Handle to the plugin instance.

-- Main function to create the input dialog UI on a specified display.
function CreateInputDialog(displayHandle)  

  -- Initialize global variables for fixture count and interleave (used for step calculations).
  FixtureCount = SelectionCount()  -- Get the number of selected fixtures.
  Interleave = SelectionCount()    -- Initial interleave value matches fixture count.

   -- Determine the display index for the dialog (fallback to 1 if >5 to avoid invalid displays).
  local displayIndex = Obj.Index(GetFocusDisplay())
  if displayIndex > 5 then
    displayIndex = 1
  end
  
  -- Retrieve color theme values for UI styling (transparency, backgrounds, etc.).
  local colorTransparent = Root().ColorTheme.ColorGroups.Global.Transparent
  local colorBackground = Root().ColorTheme.ColorGroups.Button.Background
  local colorBackgroundPlease = Root().ColorTheme.ColorGroups.Button.BackgroundPlease
  local colorPartlySelected = Root().ColorTheme.ColorGroups.Global.PartlySelected
  local colorPartlySelectedPreset = Root().ColorTheme.ColorGroups.Global.PartlySelectedPreset
  local colorBlack = Root().ColorTheme.ColorGroups.Global.Transparent  -- Note: Reusing transparent as black.
  -- MAtricks-specific colors for X, Y, Z axes.
  local colorXMAtricks = Root().ColorTheme.ColorGroups.MATricks.BackgroundX
  local colorYMAtricks = Root().ColorTheme.ColorGroups.MATricks.BackgroundY
  local colorZMAtricks = Root().ColorTheme.ColorGroups.MATricks.BackgroundZ

  -- Value-specific colors for fade and delay inputs.
  local colorFadeValue = Root().ColorTheme.ColorGroups.ProgLayer.Fade
  local colorDelayValue = Root().ColorTheme.ColorGroups.ProgLayer.Delay
  
  -- Get the display and its overlay for UI rendering.
  local display = GetDisplayByIndex(displayIndex)
  local screenOverlay = display.ScreenOverlay
  
  -- Clear any existing UI children on the overlay to start fresh.
  screenOverlay:ClearUIChildren()   
  
  -- Define dialog dimensions and create the base input container.
  -- size of the box
  local dialogWidth = 1200
  local baseInput = screenOverlay:Append("BaseInput")
  baseInput.Name = "DMXTesterWindow"
  baseInput.H = "0"  -- Height set to 0 initially (will expand).
  baseInput.W = dialogWidth
  baseInput.MaxSize = string.format("%s,%s", display.W * 0.8, display.H)  -- Max size based on display.
  baseInput.MinSize = string.format("%s,0", dialogWidth - 100)  -- Min width fixed.
  baseInput.Columns = 1  
  baseInput.Rows = 2
  baseInput[1][1].SizePolicy = "Fixed"
  baseInput[1][1].Size = "80"  -- Fixed row for title bar.
  baseInput[1][2].SizePolicy = "Stretch"  -- Stretchable content row.
  baseInput.AutoClose = "No"  -- Dialog doesn't auto-close.
  baseInput.CloseOnEscape = "Yes"  -- Closes on Escape key.
  
  -- Create the title bar with icon and close button.
  local titleBar = baseInput:Append("TitleBar")
  titleBar.Columns = 2  
  titleBar.Rows = 1
  titleBar.Anchors = "0,0"
  titleBar[2][2].SizePolicy = "Fixed"
  titleBar[2][2].Size = "50"
  titleBar.Texture = "corner2"
  
  local titleBarIcon = titleBar:Append("TitleButton")
  titleBarIcon.Text = "StabberPro"  -- Plugin title.
  titleBarIcon.Texture = "corner1"
  titleBarIcon.Anchors = "0,0"
  titleBarIcon.Icon = "star"  -- Icon for visual appeal.
  
  local titleBarCloseButton = titleBar:Append("CloseButton")
  titleBarCloseButton.Anchors = "1,0"
  titleBarCloseButton.Texture = "corner2"
  
  -- Create the main dialog frame (divided into subtitle, inputs, and buttons).
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
  dlgFrame[1][1].Size = "60"  -- Fixed height for subtitle.
  -- main grid row
  dlgFrame[1][2].SizePolicy = "Fixed"
  dlgFrame[1][2].Size = "400"  -- Fixed height for inputs grid.
  -- button row
  dlgFrame[1][3].SizePolicy = "Fixed"  
  dlgFrame[1][3].Size = "80"  -- Fixed height for buttons.
  
  -- Create subtitle text.
  local subTitle = dlgFrame:Append("UIObject")
  subTitle.Text = "Set MATricks for Stabs"  -- Subtitle describing purpose.
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
  subTitle.BackColor = colorBlack  -- Black background for subtitle.
  
  -- Commented-out attempt to create a background for X area (unused).
  --local xBacking = dlgFrame:Append("UIObject")
  --xBacking.Anchors = {
  --    left = 0,
  --    right = 0,
  --    top = 1,
  --    bottom = 1
  --}

  --xBacking.HasHover = "No"
  --xBacking.BackColor = colorXMAtricks
  
    -- Create the main inputs grid (10 columns, 5 rows for various inputs).
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
    inputsGrid.BackColor = colorTransparent  -- Transparent background.


    -- Define common margins for inputs.
    local inputMargins = {
    left = 0,
    right = 10,
    top = 0,
    bottom = 20

    }


-- Display fixture count (non-editable, shows selection count).
    local fixtureCountInputLine = inputsGrid:Append("Button")
    fixtureCountInputLine.Margin = inputMargins
    fixtureCountInputLine.Anchors = {
        left = 0,
        right = 2,
        top = 0,
        bottom = 0
    }
    fixtureCountInputLine.Text = "Selection Count: "..FixtureCount..""  -- Displays current fixture count.
    fixtureCountInputLine.TextalignmentH = "Left"
    fixtureCountInputLine.Padding = '5,5'
    fixtureCountInputLine.HasHover = 'No'
    fixtureCountInputLine.PluginComponent = myHandle

    

    -- Checkbox for "Straight Stabs" type (mutually exclusive with others).
    local stabsTypeStraight = inputsGrid:Append("CheckBox")
    stabsTypeStraight.Margin = inputMargins
    stabsTypeStraight.Anchors = {
        left = 3,
        right = 4,
        top = 0,
        bottom = 0
        }
    stabsTypeStraight.Text = "Straight Stabs"
    stabsTypeStraight.TextalignmentH = "Center"
    stabsTypeStraight.State = 1;  -- Default selected.
    stabsTypeStraight.Padding = '5,5'
    stabsTypeStraight.PluginComponent = myHandle
    stabsTypeStraight.Clicked = "StraightStabsSelected"  -- Handler for selection.

    -- Checkbox for "Scatter Stabs".
    local stabsTypeScatter = inputsGrid:Append("CheckBox")
    stabsTypeScatter.Margin = inputMargins
    stabsTypeScatter.Anchors = {
        left = 5,
        right = 6,
        top = 0,
        bottom = 0
    }
    stabsTypeScatter.Text = "Scatter Stabs"
    stabsTypeScatter.TextalignmentH = "Center"
    stabsTypeScatter.State = 0;
    stabsTypeScatter.Padding = '5,5'
    stabsTypeScatter.PluginComponent = myHandle
    stabsTypeScatter.Clicked = "ScatterStabsSelected"

    -- Checkbox for "Shuffle Stabs".
    local stabsTypeShuffle = inputsGrid:Append("CheckBox")
    stabsTypeShuffle.Margin = inputMargins
    stabsTypeShuffle.Anchors = {
        left = 7,
        right = 8,
        top = 0,
        bottom = 0
    }
    stabsTypeShuffle.Text = "Shuffle Stabs"
    stabsTypeShuffle.TextalignmentH = "Center"
    stabsTypeShuffle.State = 0;
    stabsTypeShuffle.Padding = '5,5'
    stabsTypeShuffle.PluginComponent = myHandle
    stabsTypeShuffle.Clicked = "ShuffleStabsSelected"








  -- Checkbox to use currently selected sequence.
  local sequenceLineSelect = inputsGrid:Append("CheckBox")
    sequenceLineSelect.Anchors = {
     left = 0,
     right = 1,
     top = 1,
     bottom = 1
   }  
    sequenceLineSelect.Text = "Sequence Selected"
    sequenceLineSelect.TextalignmentH = "Center";
    sequenceLineSelect.State = 0;
    sequenceLineSelect.Padding = "5,5"
    sequenceLineSelect.PluginComponent = myHandle
    sequenceLineSelect.Clicked = "SequenceSelected"  -- Toggles use of selected sequence.
    sequenceLineSelect.BackColor = colorPartlySelected  -- Highlight color.


   -- Input for manual sequence number.
   local sequenceInputLine = inputsGrid:Append("LineEdit")
   sequenceInputLine.Anchors = {
    left = 2,
    right = 3,
    top = 1,
    bottom = 1
   }
    sequenceInputLine.Prompt = "Sequence #: " 
    sequenceInputLine.TextAutoAdjust = "Yes"
    sequenceInputLine.Filter = "0123456789"  -- Numeric only.
    sequenceInputLine.VkPluginName = "TextInputNumOnly"  -- Virtual keyboard for numbers.
    sequenceInputLine.Content = ""
    sequenceInputLine.MaxTextLength = 6
    sequenceInputLine.HideFocusFrame = "Yes"
    sequenceInputLine.PluginComponent = myHandle
    sequenceInputLine.TextChanged = "OnInputSequenceTextChanged"  -- Handler for changes.
    sequenceLineSelect.BackColor = colorPartlySelected  -- Typo? Should be sequenceInputLine.BackColor.





    ----------------
    ---Direction 
    ---
    -- Checkbox for forward direction (default).
    local directionForwardSelect = inputsGrid:Append("CheckBox")
    directionForwardSelect.Anchors = {
     left = 7,
     right = 8,
     top = 4,
     bottom = 4
   }

    directionForwardSelect.Text = "Direction Forward"
    directionForwardSelect.TextalignmentH = "Center";
    directionForwardSelect.State = 1;
    directionForwardSelect.Padding = "5,5"
    directionForwardSelect.PluginComponent = myHandle
    directionForwardSelect.Clicked = "DirectionForward"  -- Sets direction to ">".

    -- Checkbox for backward direction.
    local directionBackwardSelect = inputsGrid:Append("CheckBox")
    directionBackwardSelect.Anchors = {
     left = 5,
     right = 6,
     top = 4,
     bottom = 4
   }

    directionBackwardSelect.Text = "Direction Backward"
    directionBackwardSelect.TextalignmentH = "Center";
    directionBackwardSelect.State = 0;
    directionBackwardSelect.Padding = "5,5"
    directionBackwardSelect.PluginComponent = myHandle
    directionBackwardSelect.Clicked = "DirectionBackward"  -- Sets direction to "<".
     
    ---
    ---
    ---Fade and Delay
    ---
    ---
    -- Input for fade off time.
    local fadeTime = inputsGrid:Append("LineEdit")
    fadeTime.Margin = inputMargins
    fadeTime.Prompt = "Fade Off: "
    fadeTime.TextAutoAdjust = "Yes"
    fadeTime.Anchors = {
      left = 0,
      right = 1,
      top = 4,
      bottom = 4
    }
    fadeTime.Padding = "5,5"
    fadeTime.Filter = ".0123456789"  -- Allows decimals.
    fadeTime.VkPluginName = "TextInputNumOnly"
    fadeTime.Content = "0"
    fadeTime.MaxTextLength = 6
    fadeTime.HideFocusFrame = "Yes"
    fadeTime.PluginComponent = myHandle
    fadeTime.TextChanged = "OnInputFadeTimeChanged"  -- Updates OffFade variable.
    fadeTime.BackColor = colorFadeValue
    OffFade = 0  -- Default fade time.

    -- Input for delay off time.
    local delayTime = inputsGrid:Append("LineEdit")
    delayTime.Margin = inputMargins
    delayTime.Prompt = "Delay Off: "
    delayTime.TextAutoAdjust = "Yes"
    delayTime.Anchors = {
      left = 2,
      right = 3,
      top = 4,
      bottom = 4
    }
    delayTime.Padding = "5,5"
    delayTime.Filter = ".0123456789"
    delayTime.VkPluginName = "TextInputNumOnly"
    delayTime.Content = "0.25"
    delayTime.MaxTextLength = 6
    delayTime.HideFocusFrame = "Yes"
    delayTime.PluginComponent = myHandle
    delayTime.TextChanged = "OnInputDelayTimeChanged"  -- Updates OffTime variable.
    delayTime.BackColor = colorDelayValue
    OffTime = 0.25  -- Default delay time.
    

   

    ---
    ---
    ---
    ---
    

    -- Button to reset all MAtricks settings.
   local resetAllButton = inputsGrid:Append("Button")
   resetAllButton.Anchors = {
     left = 9,
     right = 9,
     top = 0,
     bottom = 0
   }
   resetAllButton.Margin = inputMargins
   resetAllButton.Text = "Reset All"
   resetAllButton.TextalignmentH = "Center";
   resetAllButton.Padding = "5,5"
   resetAllButton.PluginComponent = myHandle
   resetAllButton.Clicked = "ResetAllButtonClicked"  -- Resets all inputs and commands.
    





   -- Display for number of steps (non-editable).
   local displayNumSteps = inputsGrid:Append("Button")
   displayNumSteps.Anchors = {
    left = 6,
    right = 7,
    top = 1,
    bottom = 1
   }
   displayNumSteps.HasHover = "No"
   displayNumSteps.Text = ("Number of Steps: "..FixtureCount.."")  -- Shows calculated steps.
   displayNumSteps.TextalignmentH = "Center"
   displayNumSteps.Padding = "5,5"
   displayNumSteps.PluginComponent = myHandle

-- Number of steps display (seems redundant, possibly for dynamic update).
   local numberofsteps = inputsGrid:Append("Button")
   numberofsteps.Anchors = {
    left = 8,
    right = 8,
    top = 1,
    bottom = 1
   }
   numberofsteps.HasHover = "No"
   numberofsteps.Text = fixtureCountInputLine.Text
   numberofsteps.TextalignmentH = "Center";
   numberofsteps.Padding = "5,5"
   numberofsteps.PluginComponent = myHandle

   -- Display for store sequence number.
   local storetoseqdisplay = inputsGrid:Append("Button")
   storetoseqdisplay.Anchors = {
    left = 4,
    right = 5,
    top = 1,
    bottom = 1
   }
   storetoseqdisplay.HasHover = "No"
   storetoseqdisplay.Text = ''
   storetoseqdisplay.TextalignmentH = "Center";
   storetoseqdisplay.Padding = "5,5"
   storetoseqdisplay.PluginComponent = myHandle




---------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------



  -- X MAtricks inputs: Groups, Blocks, Wings.
  -- X Groups input.
  local input1ALineEdit = inputsGrid:Append("LineEdit")
  input1ALineEdit.Margin = inputMargins
  input1ALineEdit.Prompt = "XGroups: "
  input1ALineEdit.TextAutoAdjust = "Yes"
  input1ALineEdit.Anchors = {
    left = 0,
    right = 1,
    top = 2,
    bottom = 2
  }
  input1ALineEdit.Padding = "5,5"
  input1ALineEdit.Filter = "0123456789"
  input1ALineEdit.VkPluginName = "TextInputNumOnly"
  input1ALineEdit.Content = ""
  input1ALineEdit.MaxTextLength = 6
  input1ALineEdit.HideFocusFrame = "Yes"
  input1ALineEdit.PluginComponent = myHandle
  input1ALineEdit.TextChanged = "OnInput1ATextChanged"  -- Updates XGroups and interleave.
  input1ALineEdit.BackColor = colorXMAtricks
  XGroups = 0  -- Default.

  -- X Blocks input.
  local input1BLineEdit = inputsGrid:Append("LineEdit")
  input1BLineEdit.Margin = inputMargins
  input1BLineEdit.Prompt = "XBlocks: "
  input1BLineEdit.TextAutoAdjust = "Yes"
  input1BLineEdit.Anchors = {
    left = 2,
    right = 3,
    top = 2,
    bottom = 2
  }
  input1BLineEdit.Padding = "5,5"
  input1BLineEdit.Filter = "0123456789"
  input1BLineEdit.VkPluginName = "TextInputNumOnly"
  input1BLineEdit.Content = ""
  input1BLineEdit.MaxTextLength = 6
  input1BLineEdit.HideFocusFrame = "Yes"
  input1BLineEdit.PluginComponent = myHandle
  input1BLineEdit.TextChanged = "OnInput1BTextChanged"  -- Updates XBlocks and interleave.
  input1BLineEdit.BackColor = colorXMAtricks
  XBlocks = 0


   -- X Wings input.
   local input1CLineEdit = inputsGrid:Append("LineEdit")
   input1CLineEdit.Margin = inputMargins
   input1CLineEdit.Prompt = "XWings: "
   input1CLineEdit.TextAutoAdjust = "Yes"
   input1CLineEdit.Anchors = {
     left = 4,
     right = 5,
     top = 2,
     bottom = 2
   }
   input1CLineEdit.Padding = "5,5"
   input1CLineEdit.Filter = "0123456789"
   input1CLineEdit.VkPluginName = "TextInputNumOnly"
   input1CLineEdit.Content = ""
   input1CLineEdit.MaxTextLength = 6
   input1CLineEdit.HideFocusFrame = "Yes"
   input1CLineEdit.PluginComponent = myHandle
   input1CLineEdit.TextChanged = "OnInput1CTextChanged"  -- Updates XWings and interleave.
   input1CLineEdit.BackColor = colorXMAtricks
   XWings = 0

   -- Checkbox to prefer X Axis (mutually exclusive with Y).
   local checkBox1 = inputsGrid:Append("CheckBox")
   checkBox1.Margin = inputMargins
   checkBox1.Anchors = {
     left = 6,
     right = 7,
     top = 2,
     bottom = 2
   }  
   checkBox1.Text = "Prefer X Axis"
   checkBox1.TextalignmentH = "Left";
   checkBox1.State = 1;  -- Default selected.
   checkBox1.Padding = "5,5"
   checkBox1.PluginComponent = myHandle
   checkBox1.Clicked = "CheckBoxXClicked"  -- Toggles X axis preference.
   checkBox1.BackColor = colorXMAtricks
   XAxisSelected = 0  -- Initial value (set to 1 later).

   -- Button to reset X MAtricks.
   local resetXButton = inputsGrid:Append("Button")
   resetXButton.Anchors = {
     left = 8,
     right = 8,
     top = 2,
     bottom = 2
   }
   resetXButton.Margin = inputMargins
   resetXButton.Text = "Reset X"
   resetXButton.TextalignmentH = "Center";
   resetXButton.Padding = "5,5"
   resetXButton.PluginComponent = myHandle
   resetXButton.Clicked = "ResetXButtonClicked"  -- Resets X inputs and commands.



-------
---Y elements
---


  -- Y MAtricks inputs (similar to X).
    -- Y Groups input.
    local input2ALineEdit = inputsGrid:Append("LineEdit")
    input2ALineEdit.Margin = inputMargins
    input2ALineEdit.Prompt = "YGroups: "
    input2ALineEdit.TextAutoAdjust = "Yes"
    input2ALineEdit.Anchors = {
      left = 0,
      right = 1,
      top = 3,
      bottom = 3
    }
    input2ALineEdit.Padding = "5,5"
    input2ALineEdit.Filter = "0123456789"
    input2ALineEdit.VkPluginName = "TextInputNumOnly"
    input2ALineEdit.Content = ""
    input2ALineEdit.MaxTextLength = 6
    input2ALineEdit.HideFocusFrame = "Yes"
    input2ALineEdit.PluginComponent = myHandle
    input2ALineEdit.TextChanged = "OnInput2ATextChanged"  -- Updates YGroups and interleave.
    input2ALineEdit.BackColor = colorYMAtricks
    YGroups = 0
  
    -- Y Blocks input.
    local input2BLineEdit = inputsGrid:Append("LineEdit")
    input2BLineEdit.Margin = inputMargins
    input2BLineEdit.Prompt = "YBlocks: "
    input2BLineEdit.TextAutoAdjust = "Yes"
    input2BLineEdit.Anchors = {
      left = 2,
      right = 3,
      top = 3,
      bottom = 3
    }
    input2BLineEdit.Padding = "5,5"
    input2BLineEdit.Filter = "0123456789"
    input2BLineEdit.VkPluginName = "TextInputNumOnly"
    input2BLineEdit.Content = ""
    input2BLineEdit.MaxTextLength = 6
    input2BLineEdit.HideFocusFrame = "Yes"
    input2BLineEdit.PluginComponent = myHandle
    input2BLineEdit.TextChanged = "OnInput2BTextChanged"  -- Updates YBlocks and interleave.
    input2BLineEdit.BackColor = colorYMAtricks
    YBlocks = 0
  
     -- Y Wings input.
    local input2CLineEdit = inputsGrid:Append("LineEdit")
    input2CLineEdit.Margin = inputMargins
    input2CLineEdit.Prompt = "YWings: "
    input2CLineEdit.TextAutoAdjust = "Yes"
    input2CLineEdit.Anchors = {
       left = 4,
       right = 5,
       top = 3,
       bottom = 3
     }
    input2CLineEdit.Padding = "5,5"
    input2CLineEdit.Filter = "0123456789"
    input2CLineEdit.VkPluginName = "TextInputNumOnly"
    input2CLineEdit.Content = ""
    input2CLineEdit.MaxTextLength = 6
    input2CLineEdit.HideFocusFrame = "Yes"
    input2CLineEdit.PluginComponent = myHandle
    input2CLineEdit.TextChanged = "OnInput2CTextChanged"  -- Updates YWings and interleave.
    input2CLineEdit.BackColor = colorYMAtricks
    YWings = 0
  
    -- Checkbox to prefer Y Axis.
    local checkBox2 = inputsGrid:Append("CheckBox")
    checkBox2.Anchors = {
     left = 6,
     right = 7,
     top = 3,
     bottom = 3
    }
    checkBox2.Margin = inputMargins
    checkBox2.Text = "Prefer Y Axis"
    checkBox2.TextalignmentH = "Left";
    checkBox2.State = 0;
    checkBox2.Padding = "5,5"
    checkBox2.PluginComponent = myHandle
    checkBox2.Clicked = "CheckBoxYClicked"  -- Toggles Y axis preference.
    checkBox2.BackColor = colorYMAtricks
    YAxisSelected = 0  -- Initial value.

   -- Button to reset Y MAtricks.
   local resetYButton = inputsGrid:Append("Button")
   resetYButton.Anchors = {
     left = 8,
     right = 8,
     top = 3,
     bottom = 3
   }
   resetYButton.Margin = inputMargins
   resetYButton.Text = "Reset Y"
   resetYButton.TextalignmentH = "Center";
   resetYButton.Padding = "5,5"
   resetYButton.PluginComponent = myHandle
   resetYButton.Clicked = "ResetYButtonClicked"  -- Resets Y inputs and commands.




  -- Button grid for Apply and Cancel.
  local buttonGrid = dlgFrame:Append("UILayoutGrid")
  buttonGrid.Columns = 2
  buttonGrid.Rows = 1
  buttonGrid.Anchors = {
    left = 0,
    right = 0,
    top = 2,
    bottom = 2
  }
  
  -- Apply button.
  local applyButton = buttonGrid:Append("Button");
  applyButton.Anchors = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0
  }
  applyButton.Textshadow = 1;
  applyButton.HasHover = "Yes";
  applyButton.Text = "Apply";
  applyButton.Font = "Medium20";
  applyButton.TextalignmentH = "Centre";
  applyButton.PluginComponent = myHandle
  applyButton.Clicked = "ApplyButtonClicked"  -- Triggers sequence creation.

  -- Cancel button.
  local cancelButton = buttonGrid:Append("Button");
  cancelButton.Anchors = {
    left = 1,
    right = 1,
    top = 0,
    bottom = 0
  }
  cancelButton.Textshadow = 1;
  cancelButton.HasHover = "Yes";
  cancelButton.Text = "Cancel";
  cancelButton.Font = "Medium20";
  cancelButton.TextalignmentH = "Centre";
  cancelButton.PluginComponent = myHandle
  cancelButton.Clicked = "CancelButtonClicked"  -- Closes dialog.
  cancelButton.Visible = "Yes"  
  




-------------------------------------------------------------------------------------------------------------------------------------------
  ------------------------------------------------------- Handlers ------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------------------------------------------------
  ---
  ---
  
  ---
  --- Var set
  --- 
  TYPE = 1  -- Default stab type (Straight).
  Direction = ">"  -- Default direction (forward).
  XAxisSelected = 1  -- Default axis preference.
  
  ---

  -- Function to update the displayed number of steps based on interleave.
  function UpdateNumSteps(input)
    numberofsteps.Text = math.floor(tonumber(input))
    
end



------- Apply and cancel Buttons


  -- Cancel handler: Logs and deletes the dialog.
  signalTable.CancelButtonClicked = function(caller)
    
    Echo("Cancel button clicked.")
    Obj.Delete(screenOverlay, Obj.Index(baseInput))
    
  end  
  
  -- Apply handler: Logs, toggles button color (visual feedback), creates sequence, deletes dialog.
  signalTable.ApplyButtonClicked = function(caller)
    
    Echo("Apply button clicked.")    
    
    if (applyButton.BackColor == colorBackground) then
      applyButton.BackColor = colorBackgroundPlease
    else
      applyButton.BackColor = colorBackground
    end 
    Create_Seq()  -- Core function to generate the sequence.
    Obj.Delete(screenOverlay, Obj.Index(baseInput))
    
  end



  -- var sets

  -- Handler for "Sequence Selected" checkbox: Toggles and sets Storeseq to current selected sequence.
  signalTable.SequenceSelected = function(caller)
  
    Echo("Sequence Selected '" .. caller.Text .. "' clicked. State = " .. caller.State)
    
    if (caller.State == 1) then
      caller.State = 0
    else
      caller.State = 1
      Storeseq = SelectedSequence()  -- Get current selected sequence number.
      Echo("Selected Sequence number is "..Storeseq.." ")
      sequenceInputLine.Content = ''
      storetoseqdisplay.Text = ("Store Seq: "..Storeseq)  -- Update display.
    end
  end

  -- Handler for manual sequence input: Updates Storeseq and display, unchecks selected option.
    signalTable.OnInputSequenceTextChanged = function(caller)
 
        Echo("InputSequencechanged: '" .. caller.Content .. "'")
        if caller.Content ~= '' then
            Storeseq = caller.Content
            storetoseqdisplay.Text = ("Store Seq: "..Storeseq)
            if sequenceLineSelect.State == 1 then
                sequenceLineSelect.State = 0
            end
        end
      end

    -- Commented-out handler for fixture count input (unused in this version).
    --signalTable.OnInputFixtureCountTextChanged = function (caller)
    --    Echo("Fixture Count text changed: '"..caller.Content.."'")
    --    Interleave = caller.Content
    --    UpdateNumSteps(Interleave)

        
    --end


    -- Handlers for stab types: Set TYPE and ensure mutual exclusivity.
    signalTable.StraightStabsSelected = function(caller)
        Echo("Straight Stabs Selected")
        if (caller.State == 1) then
                  caller.State = 0
        else
                  caller.State = 1
                  TYPE = 1
                  stabsTypeScatter.State = 0
                  stabsTypeShuffle.State = 0
        end
    end

    signalTable.ScatterStabsSelected = function(caller)
        Echo("Scatter Stabs Selected")
        if (caller.State == 1) then
                  caller.State = 0
        else
                  caller.State = 1
                  TYPE = 2
                  stabsTypeStraight.State = 0
                  stabsTypeShuffle.State = 0
        end
    end

    signalTable.ShuffleStabsSelected = function(caller)
        Echo("Shuffle Stabs Selected")
        if (caller.State == 1) then
                  caller.State = 0
        else
                  caller.State = 1
                  TYPE = 3
                  stabsTypeStraight.State = 0
                  stabsTypeScatter.State = 0
        end
    end

    ------Direction selection
    -- Handlers for direction: Set Direction and ensure mutual exclusivity.
    signalTable.DirectionForward = function(caller)
      Echo("Forward direction selected")
      if (caller.State == 1) then
                caller.State = 0
      else
                caller.State = 1
                Direction = ">"
                directionBackwardSelect.State = 0
      end
  end

  signalTable.DirectionBackward = function(caller)
    Echo("Backward direction selected")
    if (caller.State == 1) then
              caller.State = 0
    else
              caller.State = 1
              Direction = "<"
              directionForwardSelect.State = 0
    end
end

    

    -- Reset All handler: Resets all MAtricks properties and UI inputs.
    signalTable.ResetAllButtonClicked = function(caller)
  
        Echo("Reset All Button '" .. caller.Text .. "' clicked. State = " .. caller.State)
        -- send commands
        Cmd('Set selection Property "XGroup" "None"')
        Cmd('Set selection Property "XBlock" "None"')
        Cmd('Set selection Property "XWings" "None"')
        -- change visible values
    
        input1ALineEdit.Content = ""
        input1BLineEdit.Content = ""
        input1CLineEdit.Content = ""
        checkBox1.State = 0

        Cmd('Set selection Property "YGroup" "None"')
        Cmd('Set selection Property "YBlock" "None"')
        Cmd('Set selection Property "YWings" "None"')
    -- change visible values

        input2ALineEdit.Content = ""
        input2BLineEdit.Content = ""
        input2CLineEdit.Content = ""
        checkBox2.State = 0

        Cmd("Reset Selection MAtricks")

        
        end



  
  -- X MAtricks handlers: Update properties, interleave, and call UpdateNumSteps.
  signalTable.OnInput1ATextChanged = function(caller)
 
    Echo("Input1A changed: '" .. caller.Content .. "'")
    if caller.Content ~= '' then
        Cmd('Set selection Property "XGroup" '..caller.Content..'')
        Interleave = caller.Content
        XGroups = tonumber(caller.Content)
    elseif caller.Content == '' then
      Interleave = FixtureCount
      XGroups = 0
    end
    UpdateNumSteps(Interleave)
  end

  signalTable.OnInput1BTextChanged = function(caller)
 
    Echo("Input1B changed: '" .. caller.Content .. "'")
    if caller.Content ~= '' then
        Cmd('Set selection Property "XBlock" '..caller.Content..'')
        Interleave = (Interleave / caller.Content)
        XBlocks = tonumber(caller.Content)
    elseif caller.Content == '' then
        Interleave = FixtureCount
        XBlocks = 0
    end
    UpdateNumSteps(Interleave) 
  end

  signalTable.OnInput1CTextChanged = function(caller)
    Echo("Input1C changed: '" .. caller.Content .. "'")
    if caller.Content ~= ''then
        Cmd('Set selection Property "XWings" '..caller.Content..'')
        Interleave = (Interleave / caller.Content)
        XWings = tonumber(caller.Content)
    elseif caller.Content == '' then
      Interleave = FixtureCount
      XWings = 0
    end
    UpdateNumSteps(Interleave)
  end

  -- X Axis preference handler: Toggles and ensures mutual exclusivity with Y.
  signalTable.CheckBoxXClicked = function(caller)
    if (caller.State == 1) then
      caller.State = 0
      Echo("Checkbox '" .. caller.Text .. "' clicked. State = " .. caller.State)
      XAxisSelected = 0
      
   else
      caller.State = 1
      XAxisSelected = 1
      YAxisSelected = 0
      ZAxisSelected = 0  -- Z not used, but reset.
      checkBox2.State = 0
      Echo("Checkbox '" .. caller.Text .. "' clicked. State = " .. caller.State)
      Echo("X Axis Selected")
    
      
    end
  end

-- Reset X handler: Resets X properties and UI, restores interleave.
signalTable.ResetXButtonClicked = function(caller)
  
    Echo("Reset X MAtricks Button '" .. caller.Text .. "' clicked. State = " .. caller.State)
    -- send commands
    Cmd('Set selection Property "XGroup" "None"')
    Cmd('Set selection Property "XBlock" "None"')
    Cmd('Set selection Property "XWings" "None"')
    -- change visible values

    input1ALineEdit.Content = ""
    input1BLineEdit.Content = ""
    input1CLineEdit.Content = ""
    checkBox1.State = 1
    Interleave = FixtureCount
    
    end
    



  -- Y MAtricks handlers (similar to X).
  signalTable.OnInput2ATextChanged = function(caller)
 
    Echo("Input2A changed: '" .. caller.Content .. "'")
    if caller.Content ~= '' then
        Cmd('Set selection Property "YGroup" '..caller.Content..'')
        Interleave = caller.Content
        YGroups = tonumber(caller.Content)
    elseif caller.Content == '' then
        Interleave = FixtureCount
        YGroups = 0
    end
    UpdateNumSteps(Interleave)
  end

  signalTable.OnInput2BTextChanged = function(caller)
 
    Echo("Input2B changed: '" .. caller.Content .. "'")
    if caller.Content ~= '' then
        Cmd('Set selection Property "YBlock" '..caller.Content..'')
        Interleave = (Interleave / caller.Content)
        YBlocks = tonumber(caller.Content)
    elseif caller.Content == '' then
      Interleave = FixtureCount
      YBlocks = 0
    end
    UpdateNumSteps(Interleave)
  end

  signalTable.OnInput2CTextChanged = function(caller)
 
    Echo("Input2C changed: '" .. caller.Content .. "'")
    if caller.Content ~= '' then
        Cmd('Set selection Property "YWings" '..caller.Content..'')
        Interleave = (Interleave / caller.Content)
        YWings = tonumber(caller.Content)
    elseif caller.Content == '' then
        YWings = 0
        Interleave = FixtureCount
    end
    UpdateNumSteps(Interleave)
  end 

-- Y Axis preference handler.
  signalTable.CheckBoxYClicked = function(caller)
    if (caller.State == 1) then
      Echo("Checkbox2 '" .. caller.Text .. "' clicked. State = " .. caller.State)
      caller.State = 0
      YAxisSelected = 0
  
      
    else
      caller.State = 1
      Echo("Checkbox2 '" .. caller.Text .. "' clicked. State = " .. caller.State)
      Echo("Y Axis Selected")
      XAxisSelected = 0
      YAxisSelected = 1
      ZAxisSelected = 0
      checkBox1.State = 0

    end
 end

  -- Reset Y handler.
  signalTable.ResetYButtonClicked = function(caller)
    Echo("Reset Y MAtricks Button '" .. caller.Text .. "' clicked. State = " .. caller.State)
    -- send commands
    Cmd('Set selection Property "YGroup" "None"')
    Cmd('Set selection Property "YBlock" "None"')
    Cmd('Set selection Property "YWings" "None"')
    -- change visible values

    input2ALineEdit.Content = ""
    input2BLineEdit.Content = ""
    input2CLineEdit.Content = ""
    checkBox2.State = 1
    Interleave = FixtureCount
    end

---
--- Set Fade and Delay Times
---
  -- Fade time handler.
  signalTable.OnInputFadeTimeChanged = function(caller)
    if caller.Content ~= '' then
      OffFade = tonumber(caller.Content)
    elseif caller.Content == '' then
      OffFade = 0
    end
  end

  -- Delay time handler.
  signalTable.OnInputDelayTimeChanged = function(caller)
    if caller.Content ~= '' then
      OffTime = tonumber(caller.Content)
    elseif caller.Content == '' then
      OffTime = 0
    end
  end

  

-- Initial update of steps display.
UpdateNumSteps(Interleave)
  
end

---- CREATE THE STABS
-- BASIC TOOLS -----------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Utility function for text input (unused in main logic).
function get_input(input_prompt)
  local input = TextInput(input_prompt)
  return input
end

-- Utility for message box (unused).
function msg_box(message)
  gma.gui.msgbox(message)
end

---------
-- Navigate forward in selection by 'number' steps.
function Go_next(number)
  for i = 1, number, 1 do
      Cmd('next')
  end
end

-- Navigate backward.
function Go_prev(number)
  for i = 1, number, 1 do
      Cmd('Previous')
  end
end

-- Store a cue in the target sequence with specific properties (goto offcue, etc.).
function Store_cue(seqnumber, cuenumber)
  Cmd('at seq 9999 cue 1')  -- Reference a temp sequence cue.
  Cmd('store '.. seqnumber .. ' cue '..cuenumber .. '/o')  -- Store with overwrite.
  Cmd('Set '..Storeseq..' cue '..cuenumber..'Property "Command" "Goto #['..Storeseq..'] cue Offcue')  -- Set command to goto offcue.
  Cmd('Set '..Storeseq..' cue "Offcue" Property "Command" "Off #['..Storeseq..'] ')  -- Off command for offcue.
end






-- Main sequence creation function: Deletes old cues, creates new based on TYPE, sets properties.
function Create_Seq()
  Cmd("Grid 'Linearize' 'LeftToRight'")  -- Linearize grid for consistent selection.
  Cmd('delete '..Storeseq..' cue 2 thru /nc')  -- Delete existing cues in target seq.
  
  

  
  if TYPE == 1 then
      Label = '"'..Interleave..'-Hits"'  -- Label for straight type.
      Straight_Seq()
  end

  if TYPE == 2 then
      Scatter_seq()
      Label = '"'..Interleave..'-Scatter"'
  end

  if TYPE == 3 then
      Label = '"'..Interleave..'-Shuffle"'
      Shuffle_Seq()
  end


  Cmd('ClearAll')  -- Clear selections.
  Cmd('set '..Storeseq..'Property Wraparound 1')  -- Enable wraparound.
  Cmd('set '..Storeseq..'Property RestartMode 2')  -- Set restart mode.
  Cmd('set cue offcue property ')
  Cmd('set '..Storeseq..'Property Tracking 0')  -- Disable tracking.
  Cmd('Label '..Storeseq..' '..Label)  -- Apply label.
  
  Cmd('set '..Storeseq..' cue offcue CueDelay '..OffTime)  -- Set delay on offcue.
  

  Cmd('Set '..Storeseq..' cue offcue CueFade '..OffFade)  -- Set fade on offcue.

end

-- Apply MAtricks settings based on user inputs.
function CheckMAtricks()
  -- X
  if XGroups > 0 or XGroups ~= '' then
    Cmd('set selection property "XGroup" '..XGroups..'')
  else
    Cmd('set selection property "XGroup" "None"')
  end
  if XBlocks > 0 or XBlocks ~= '' then
    Cmd('set selection property "XBlock" '..XBlocks..'')
  else
    Cmd('set selection property "XBlock" "None"')
  end
  if XWings > 0 or XWings ~= '' then
    Cmd('set selection property "XWings" '..XWings..'')
  else
    Cmd('set selection property "XWings" "None"')
  end
  -- Y
  if YGroups > 0 or YGroups ~= '' then
    Cmd('set selection property "YGroup" '..YGroups..'')
  else
    Cmd('set selection property "YGroup" "None"')
  end
  if YBlocks > 0 or YBlocks ~= '' then
    Cmd('set selection property "YBlock" '..YBlocks..'')
  else
    Cmd('set selection property "YBlock" "None"')
  end
  if YWings > 0 or YWings ~= '' then
    Cmd('set selection property "YWings" '..YWings..'')
  else
    Cmd('set selection property "YWings" "None"')
  end
end

-- Create scatter sequence (alternating from ends).
function Scatter_seq()
  -- stutter seq creation, ex, 1-6: 1,6,2,5,3,4
  Cmd('Store seq 9999 cue 1 /o')  -- Temp store.
    if Direction == "<" then
      local cueStoreNum = 1
        for i = Interleave, 1, -1 do
            if i % 2 == 1 then
                if i == 1 then
                    if XAxisSelected == 1 then
                    Cmd('set selection property "X" '..i)
                    end
                    if YAxisSelected == 1 then
                    Cmd('set selection property "Y" '..i)
                    end
                    Store_cue(Storeseq, cueStoreNum)
                else
                    local n = i - 1
                    Go_next(n)
                    Store_cue(Storeseq, cueStoreNum)
                end
            elseif i % 2 == 0 then
                if i == 2 then
                    Cmd('Previous')
                    Store_cue(Storeseq, cueStoreNum)
                else
                    local n = i - 1
                    Go_prev(n)
                    Store_cue(Storeseq, cueStoreNum)
                    
                end
            end
            cueStoreNum = (cueStoreNum + 1)     
        end
    else
        for i = 1, Interleave, 1 do
            if i % 2 == 1 then
                if i == 1 then
                    if XAxisSelected == 1 then
                    Cmd('set selection property "X" '..i)
                    end
                    if YAxisSelected == 1 then
                    Cmd('set selection property "Y" '..i)
                    end
                    
                    Store_cue(Storeseq, i)
                else
                    local n = i - 1
                    Go_next(n)
                    Store_cue(Storeseq, i)
                end
            elseif i % 2 == 0 then
                if i == 2 then
                    Cmd('Previous')
                    Store_cue(Storeseq, i)
                else
                    local n = i - 1
                    Go_prev(n)
                    Store_cue(Storeseq, i)
                end
            end     
        end
    end
end



-- Create straight sequence (sequential steps).
function Straight_Seq( ... )
  -- striaght seq creation
  Cmd('Store seq 9999 cue 1 /o')
  if Direction == '<' then
    CheckMAtricks()
    local cueStoreNum = 1
    for i = Interleave, 1, -1 do
        if XAxisSelected == 1 then
          Cmd('set selection property "X" '..i)
        elseif YAxisSelected == 1 then
          Cmd('set selection property "Y" '..i)
        end
      Store_cue(Storeseq, cueStoreNum)
      cueStoreNum = (cueStoreNum + 1)
    end

  else
      CheckMAtricks()
        for i = 1, Interleave, 1 do
            if XAxisSelected == 1 then
              Cmd('set selection property "X" '..i)
            elseif YAxisSelected == 1 then
              Cmd('set selection property "Y" '..i)
          end
          
          Store_cue(Storeseq, i)
        end
  end
  
end

-- Unused utility function to check if value in table.
function Has_value (tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return true
      end
  end

  return false
end

-- Create shuffle sequence: Shuffles selection, stores temp group, creates cues.
function Shuffle_Seq()
  --shuffled seq creation
  Cmd('Store seq 9999 cue 1 /o')
  local randomInt = math.random( 126 )  -- Random shuffles (up to 126 times).
  CheckMAtricks()
  for i = 1, randomInt, 1 do
    Cmd('Shuffle')
  end
  Cmd('store group 9999 /o')  -- Temp group for shuffled selection.
  Cmd('Clear')
  Cmd('group 9999')
  if Direction == "<" then
    local cueStoreNum = 1
    for i = Interleave, 1, -1 do
        Cmd('set selection property "X" '..i)
        Store_cue(Storeseq, cueStoreNum)
        cueStoreNum = (cueStoreNum + 1)
      end
  else
    for i = 1, Interleave, 1 do
        Cmd('set selection property "X" '..i)
        Store_cue(Storeseq, i)
      end
  end
  
  Cmd('ClearAll')
  Cmd('Delete group 9999 /nc')  -- Clean up temp group.
  Cmd("Delete Seq 9999 /nc")  -- Clean up temp seq.

end








-- run the damn thing


return CreateInputDialog