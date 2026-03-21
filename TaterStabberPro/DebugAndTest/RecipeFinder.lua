return function()
    -- Specify your targets (1-based indices; adjust for your show)
    local seqIndex = 1  -- Sequence number
    local cueIndex = 1  -- Cue number (may need +2 if off-cue/cue-zero exists)
    local partIndex = 0.1 -- Cue part (usually 1 for single-part cues)
    local recipeIndex = 1 -- Recipe line number

    -- Get the recipe handle via data pool path
    local seqHandle = DataPool().Sequences[seqIndex]
    if not seqHandle then
        Printf("Sequence " .. seqIndex .. " not found.")
        return
    end

    local cueHandle = seqHandle[cueIndex]
    if not cueHandle then
        Printf("Cue " .. cueIndex .. " in sequence " .. seqIndex .. " not found.")
        return
    end

    local partHandle = cueHandle[partIndex]
    if not partHandle then
        Printf("Part " .. partIndex .. " in cue " .. cueIndex .. " not found.")
        return
    end

    local recipeHandle = partHandle[recipeIndex]
    if not recipeHandle then
        Printf("Recipe line " .. recipeIndex .. " in part " .. partIndex .. " not found.")
        return
    end

    -- Grab specific info: e.g., selection name (group/fixture list used in recipe)
    local selectionName = recipeHandle.Selection and recipeHandle.Selection.Name or "No selection"
    Printf("Recipe line selection: " .. selectionName)

    -- Example: Grab preset reference (if it's a preset-based recipe)
    local presetRef = recipeHandle.Preset  -- May be a handle; use .Name or :Dump() for details
    if presetRef then
        Printf("Preset in recipe: " .. (presetRef.Name or "Unknown"))
    else
        Printf("No preset in this recipe line.")
    end

    -- Dump all properties for full inspection (outputs to console)
    recipeHandle:Dump()

    -- Alternative: If working with the CURRENT cue (e.g., in a running sequence)
    -- local currentCue = GetCurrentCue()
    -- if currentCue then
    --     local parts = currentCue:Children()  -- Get all parts
    --     for i, part in ipairs(parts) do
    --         local recipes = part:Children()  -- Get all recipe lines in part
    --         for j, recipe in ipairs(recipes) do
    --             local selName = recipe.Selection and recipe.Selection.Name or "No selection"
    --             Printf("Part " .. i .. ", Recipe " .. j .. " selection: " .. selName)
    --             recipe:Dump()  -- Inspect this specific recipe
    --         end
    --     end
    -- end
end