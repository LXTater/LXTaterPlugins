-- Sudo CODE!
-- Tater StabberPro v0.0.0
-- For Nick!
--[[
local cmd = Cmd -- This is beecause I forget to capitlize cmd sometimes.

--Create PluginStartMacro
                   --Creating a macro to enable the recipe editor, and upon finishing creating the recipe, the macro will call the plugin.
    cmd("Store Macro 'StabberProStartup'")
    cmd("ChangeDestinataion 'Macro StabberProStartup'") -- CD to the Macro to insert lines
    cmd("Insert") -- Line 1
    cmd("Insert") -- Line 2
    cmd("Insert") -- Line 3
    cmd("Insert") -- Line 4
    cmd("Set Macro 'StabberProStartup'.1 Property 'Command' 'ChangeDestination CurrentUserProfile'")
    cmd("Set Macro 'StabberProStartup'.2 Property 'Command' 'Set \"Environments\".\"UserEnvironment 1\".\"RecipeEditor\" Property \"Enabled\" \"Yes\"'")
    cmd("Set Macro 'StabberProStartup'.3 Property 'Command' 'ChangeDestination Root'")
    
--Enable Recipe Editor:



    Cmd("ChangeDestination CurrentUserProfile") -- Required to set user environment properties globally
    Cmd("Set 'Environments'.'UserEnvironment 1'.'RecipeEditor' Property 'Enabled' 'Yes'")
    Cmd("ChangeDestination Root") -- retuns back to root destination

--Disable Recipe Editor:
    Cmd("ChangeDestination CurrentUserProfile")
    Cmd("Set 'Environments'.'UserEnvironment 1'.'RecipeEditor' Property 'Enabled' 'No'")
    Cmd("ChangeDestination Root")

-- User Selects recipe, we will create a temporary sequ to store the recipe in.

    Cmd("Store Sequence 'StabberProRecipeTemp'") --This will ask you if you want to override, merge, or cancel if already exists.
    Cmd("Select Sequence 'StabberProRecipeTemp'") --Select the sequence to more easily parse.

    -- OLD local StabberRecipe = ObjectList("Sequence 'StabberPro-RecipeTemp' Cue 1 Part 0.1")[1] --Variable that will be set to the newly created recipe.

    
    local StabberTempSequNo = SelectedSequence().No -- Grab the stabberPro Recipe number for an easier time later. 

    local StabberRecipe = DataPool().Sequences[StabberTempSequNo][3][1][1]  --This will grab the recipe line of the temporary sequ. Need to expand this incase there are multiple recipe lines. [3] = cue 1, [1] = First Part, [1] == First Recipe
     --Instead of setting the MAtricks during the recipe creation, we will set the MATricks in the menu after creating the stabber selection and value recipe.

     
        local sequ = DataPool().Sequences[StabberTempSequNo] --CallOurTemporarySequence.
            local StabberRecipe = sequ[3] and sequ[3][1] and sequ[3][1][1]
      local selectionName = StabberRecipe.Selection and StabberRecipe.Selection.Name or "No selection" --Grabs the name of the group
      local selectionNo = StabberRecipe.Selection and StabberRecipe.Selection.No or "No selection" --Grabs the number of the group
                local StabberPreset = StabberRecipe.Preset   --Grabs the value of the recipe
                local presetFormatted = StabberPreset and string.format("Preset %s '%s'", StabberPreset.No, StabberPreset.Name or "Unnamed") or "No preset" --Formats the preset

]]
                -- GUI Sudo:


                --For a popup:
                local plugintable, thiscomponent = select(3, ...)

                        local StabberCurrentGroupList = DataPool().Groups[i].name --this is sudo code that doesn't work, but you get the idea. Need to populate a table with all of the group names and numnbers. And then we will add them to the popupmenu
                        local popuplists = {StabberCurrentGroupList}

                    function plugintable.mypopup(caller)
                        local itemlist = popuplists[caller.Name]
                        local _, choice = PopupInput{title = caller.Name, caller = caller:GetDisplay(), items = itemlist, selectedValue = caller.Text}
                        caller.Text = choice or caller.Text
                        end
                    
                    return function ()
                            local dialog = GetFocusDisplay().ScreenOverlay:Append('BaseInput')
                            dialog.H, dialog.W = x,x
                            dialog = dialog:Append('UILayoutGrid')
                            dialog.Rows = x
                            
                            local button = dialog:Append('Button')
                            button.Anchors = '0,0'
                            button.Name, button.Text = StabberGroup[i], if StabberGroup = true then 'StabberGroupName' else 'Please make a selection'
                            button.PluginComponent, button.Clicked = thiscomponent, 'mypopup' 

                            end

--[[
                -- Sequence creation sudo

                local StabbberSequName = --StabberSelectedSequ or StabberUserInputSequName
                local StabbberSequNo = --StabberSelectedNo or StabberUserInputNo

                --Need to: 1) Create a cue for each selection, If no MATricks it will = the same amount of fixtures in the selection.
                -- if MATricks, we will need to divide the amount of fixtures by the MATricks value to get the amount of cues needed.
                -- 2) Create a part for each cue
                -- 3) Create a recipe for each part with the stabber preset and the selection.
                -- 4) Set the MATricks value if needed.
                -- 5) Set the fade time if needed.


                for i = 
                function createTheDamnThing()
                    if i <= StabberFinalAmount then
                        cmd("Store Cue " .. i .. " Part 0.".. %d .., StabberRecipeNo)
                    end


                --Sequence settings
                local StabberSequApp = --Default to none, if user selects appearance set the var to equal to the appearance number.
                local StabberSequSettings = --A table with all of the settings of the sequence. Might just be easier to scrap this and just go with settings in the sequ itself. Maybe have a few common sequ settings, like priority, etc.
                local StabberExecStore = --Where the user would like to assign the sequence to. If they want to, if user has no input then it will not assign the sequ.

                
]]


--]]            -- RecipeEditor
                --Grab the info from the UI Editor, and update the temporary recipe with the stabber preset and group selection.
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'Selection' 'Group " .. StabberSelectionNo .. "'") -- Set the selection of the group for the recipe line
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'Preset' 'Preset " .. StabberPresetType .. ".".. StabberPresetNumber) -- Set the preset for the recipe line
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'XBlock'" .. stabberXblock .."'")
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'XGroup'" .. stabberXgroup .."'")
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'XWings' '".. stabberXwings .."'")
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'YBlock'" .. stabberYblock .."'")
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'YGroup'" .. stabberYgroup .."'")
                    cmd("Set Sequence ' StabberProRecipeTemp' Cue ".. i .. "Part 0." .. j .. "Property 'YWings' '".. stabberYwings .."'")




