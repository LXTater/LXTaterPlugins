-- Stabber_ProgrammerPeek.lua
-- A read-only inspector for the grandMA3 Programmer, providing insights into the current selection,
-- matching groups, referenced presets, and MAtricks state. Creates a temporary sequence with blank
-- cues and recipe lines based on detected MAtricks (focusing on XGroup) and presets.
--
-- Key Features:
-- - Reports selection count (subfixtures).
-- - Identifies exact-matching groups (by subfixture indices).
-- - Lists unique presets referenced in the Programmer (absolute/relative).
-- - Details MAtricks activation and source (Pool or Preset).
-- - Creates 'StabberRecipeTemp' sequence with cues and recipe parts:
--   - If MAtricks active and XGroup > 1, uses XGroup as number of slices.
--   - If no MAtricks or XGroup <= 1, uses fixture count as number of slices.
--   - Each cue represents one slice, with one part per preset.
--   - Sets MAtricks property X for each cue; sets XGroup only if explicitly defined (> 0).
--
-- Limitations:
-- - Assumes a single exact group match; uses the first if multiple.
-- - Preset detection uses the first selected subfixture's Programmer phasers.
-- - Focuses on XGroup for MAtricks; other parameters (XWings, XBlocks, Y versions) not handled.
-- - Temporary sequence is created but not deleted; user can manage it.
--
-- Author: Senior Engineer
-- Version: 1.2
-- Date: September 11, 2025

return function()
  -- Utility: Checks if a specific bit is set in a value.
  -- @param val number The value to check.
  -- @param bitNum number The bit position (0-based).
  -- @return boolean True if the bit is set.
  local function stabberBitCheck(val, bitNum)
    return (((val or 0) & (0x01 << bitNum)) >> bitNum) == 1
  end

  -- Collects the list of selected subfixture indices using SelectionFirst/Next.
  -- @return table List of selected subfixture indices.
  local function stabberGetSelectedSFList()
    local stabberList = {}
    local stabberIdx = SelectionFirst()
    while stabberIdx do
      table.insert(stabberList, stabberIdx)
      stabberIdx = SelectionNext(stabberIdx)
    end
    return stabberList
  end

  -- Converts a list to a set for efficient lookups.
  -- @param t table The list to convert.
  -- @return table The set (keys are values from the list).
  local function stabberToSet(t)
    local stabberSet = {}
    for _, v in ipairs(t) do
      stabberSet[v] = true
    end
    return stabberSet
  end

  -- Checks if two lists contain exactly the same elements (order-independent).
  -- @param a table First list.
  -- @param b table Second list.
  -- @return boolean True if sets are equal.
  local function stabberSetsEqual(a, b)
    if #a ~= #b then return false end
    local stabberSetB = stabberToSet(b)
    for _, v in ipairs(a) do
      if not stabberSetB[v] then return false end
    end
    return true
  end

  -- Finds groups whose SELECTIONDATA exactly matches the current selection.
  -- @param selectedSF table List of selected subfixture indices.
  -- @return table List of matching groups {index, name}.
  local function stabberFindMatchingGroups(selectedSF)
    local stabberMatches = {}
    local stabberGroups = DataPool().Groups
    if not stabberGroups then return stabberMatches end

    for stabberI = 1, #stabberGroups do
      local stabberGroup = stabberGroups[stabberI]
      if stabberGroup and stabberGroup.SELECTIONDATA then
        local stabberGroupList = {}
        for stabberZ = 1, #stabberGroup.SELECTIONDATA do
          table.insert(stabberGroupList, stabberGroup.SELECTIONDATA[stabberZ].sf_index)
        end
        if stabberSetsEqual(selectedSF, stabberGroupList) then
          table.insert(stabberMatches, { index = stabberGroup.index, name = stabberGroup.name or "" })
        end
      end
    end
    return stabberMatches
  end

  -- Parses preset pool and index from a handle address string (e.g., "Preset 4.12").
  -- Handles potential format variations.
  -- @param addr string The address string.
  -- @return number|nil Pool index.
  -- @return number|nil Preset index.
  local function stabberParsePresetAddr(addr)
    if not addr then return nil, nil end
    local stabberPool, stabberIdx = addr:match("Preset%s+(%d+)%.(%d+)")
    if stabberPool and stabberIdx then
      return tonumber(stabberPool), tonumber(stabberIdx)
    end
    -- Fallback for partial matches
    stabberPool = addr:match("Preset%s+(%d+)")
    stabberIdx = addr:match("%.(%d+)")
    return tonumber(stabberPool), tonumber(stabberIdx)
  end

  -- Resolves preset details (type/pool name, index, name) from a handle.
  -- @param h handle The preset handle.
  -- @return table Preset info {pool, index, typeName, name, addr}.
  local function stabberGetPresetInfoFromHandle(h)
    local stabberAddr = ToAddr(h) or ""
    local stabberPoolIndex, stabberPresetIndex = stabberParsePresetAddr(stabberAddr)
    local stabberPoolName = ("Pool %s"):format(tostring(stabberPoolIndex or "?"))
    local stabberPresetName = h and (h.name or "") or ""

    -- Fetch from PresetPools if available
    local stabberPresetPools = DataPool().PresetPools or (DataPool():Children() and DataPool():Children()[4])
    if stabberPresetPools and stabberPoolIndex and stabberPresetPools[stabberPoolIndex] then
      stabberPoolName = stabberPresetPools[stabberPoolIndex].name or stabberPoolName
      local stabberPresetItem = stabberPresetPools[stabberPoolIndex][stabberPresetIndex]
      if stabberPresetItem and stabberPresetItem.name then
        stabberPresetName = stabberPresetItem.name
      end
    end

    return {
      pool = stabberPoolIndex,
      index = stabberPresetIndex,
      typeName = stabberPoolName,
      name = stabberPresetName,
      addr = stabberAddr
    }
  end

  -- Collects unique presets referenced in the Programmer's phasers (abs/rel).
  -- Uses the first selected subfixture for attribute scanning.
  -- @param selectedSF table List of selected subfixture indices.
  -- @return table List of unique preset info tables.
  local function stabberCollectActivePresets(selectedSF)
    local stabberFirstSF = selectedSF[1]
    if not stabberFirstSF then return {} end

    local stabberAttributes = ShowData().LivePatch.AttributeDefinitions.Attributes
    local stabberUniques = {}
    local stabberSeen = {}

    for stabberI = 1, #stabberAttributes do
      local stabberAttrName = stabberAttributes[stabberI].NAME
      local stabberAttrIdx = GetAttributeIndex(stabberAttrName)
      local stabberUIChan = GetUIChannelIndex(stabberFirstSF, stabberAttrIdx)
      local stabberPhaser = stabberUIChan and GetProgPhaser(stabberUIChan, false) or nil

      if stabberPhaser then
        local stabberMask = stabberPhaser.mask_active_phaser or 0
        if stabberPhaser.abs_preset and stabberBitCheck(stabberMask, 0) then
          local stabberKey = HandleToStr(stabberPhaser.abs_preset)
          if not stabberSeen[stabberKey] then
            stabberSeen[stabberKey] = true
            table.insert(stabberUniques, stabberGetPresetInfoFromHandle(stabberPhaser.abs_preset))
          end
        end
        if stabberPhaser.rel_preset and stabberBitCheck(stabberMask, 1) then
          local stabberKey = HandleToStr(stabberPhaser.rel_preset)
          if not stabberSeen[stabberKey] then
            stabberSeen[stabberKey] = true
            table.insert(stabberUniques, stabberGetPresetInfoFromHandle(stabberPhaser.rel_preset))
          end
        end
      end
    end

    return stabberUniques
  end

  -- Extracts MAtricks information from the Selection object.
  -- Handles variations in property casing (uppercase/camelCase).
  -- @return table MAtricks info {active, source, addr}.
  local function stabberGetMAtricksInfo()
    local stabberSelObj = Selection()
    local stabberInfo = { active = false, source = nil, addr = nil }

    if stabberSelObj then
      -- Check for active state (handle casing variations)
      stabberInfo.active = (stabberSelObj.ACTIVE == true) or (stabberSelObj.Active == true) or false
      -- Get initial MAtricks (handle casing)
      local stabberInit = stabberSelObj.INITIALMATRICKS or stabberSelObj.InitialMAtricks
      if stabberInit then
        stabberInfo.addr = ToAddr(stabberInit)
        if stabberInfo.addr and stabberInfo.addr:match("^Preset") then
          stabberInfo.source = "Preset"
        else
          stabberInfo.source = "Pool"
        end
      end
    end
    return stabberInfo
  end

  -- Creates a helper MAtricks pool item from the current programmer MAtricks.
  -- Optionally searches for an existing pool item match.
  -- @param poolItem boolean True to search for existing pool item.
  -- @return number|nil Helper index if created.
  -- @return number|string|nil Existing pool index or preset address if found.
  local function stabberRecipeMAtricksProg(poolItem)
    Echo("Start Function stabberRecipeMAtricksProg")
    local stabberMAtricksCount = DataPool().MAtricks:Children()
    local stabberMAtricks = DataPool().MAtricks
    local stabberLastMAtricks = #stabberMAtricksCount
    local stabberHelperMAtricksIndex
    if stabberLastMAtricks == 0 then
      stabberHelperMAtricksIndex = 9000
    else
      stabberHelperMAtricksIndex = stabberMAtricksCount[stabberLastMAtricks].index + 1
      if stabberHelperMAtricksIndex < 800 then stabberHelperMAtricksIndex = stabberHelperMAtricksIndex + 9000 end
    end
    local stabberHelperMAtricksName = "HelperMAtricksStabber"
    local stabberMAtricksPreset = nil

    Cmd("Store Matricks " .. stabberHelperMAtricksIndex .. " \"" .. stabberHelperMAtricksName .. "\"")
    Cmd("Reset Selection MAtricks")

    local stabberReferenceMAtricks = stabberMAtricks[stabberHelperMAtricksIndex]

    if poolItem then
      for stabberI = 1, #stabberMAtricks - 1 do
        local stabberCurrentMAtricks = stabberMAtricks[stabberI]
        if stabberReferenceMAtricks:Compare(stabberCurrentMAtricks) and (stabberCurrentMAtricks.index) ~= stabberHelperMAtricksIndex then
          stabberMAtricksPreset = stabberCurrentMAtricks.index
          stabberHelperMAtricksIndex = nil
          Echo("Found MAtricks " .. stabberCurrentMAtricks.index)
          break
        end
      end
      if stabberMAtricksPreset == nil then
        stabberMAtricksPreset = ToAddr(Selection().InitialMAtricks)
        if stabberMAtricksPreset ~= nil then
          stabberHelperMAtricksIndex = nil
          Echo("Found MAtricks in " .. stabberMAtricksPreset)
        end
      end
    else
      Echo("MAtricks Helper Index " .. stabberHelperMAtricksIndex)
    end

    Echo("End Function stabberRecipeMAtricksProg")
    return stabberHelperMAtricksIndex, stabberMAtricksPreset
  end

  -- Main Execution: Print the Programmer inspection readout and create temporary sequence.
  Printf("[StabberPro]: ===== Programmer Peek =====")

  local stabberSelectedSF = stabberGetSelectedSFList()
  local stabberSelCount = #stabberSelectedSF
  Printf("[StabberPro]: Selection Amount: %d", stabberSelCount)
  if stabberSelCount == 0 then
    Printf("[StabberPro]: No fixtures selected. (Nothing in selection grid)")
    Printf("[StabberPro]: ===== End =====")
    return
  end

  -- Matching Groups
  local stabberMatches = stabberFindMatchingGroups(stabberSelectedSF)
  if #stabberMatches == 0 then
    Printf("[StabberPro]: Group: (no exact group match)")
    Printf("[StabberPro]: ===== End =====")
    return
  else
    for _, stabberG in ipairs(stabberMatches) do
      Printf("[StabberPro]: Group %s \"%s\"", tostring(stabberG.index or "?"), tostring(stabberG.name or ""))
    end
  end
  -- Assume first matching group for sequence creation
  local stabberGroupIndex = stabberMatches[1].index
  local stabberGroupName = stabberMatches[1].name

  -- Active Presets
  local stabberPresets = stabberCollectActivePresets(stabberSelectedSF)
  if #stabberPresets == 0 then
    Printf("[StabberPro]: Presets: none referenced by Programmer (values may be raw)")
    Printf("[StabberPro]: ===== End =====")
    return
  else
    for _, stabberP in ipairs(stabberPresets) do
      local stabberPoolStr = (stabberP.pool and stabberP.index) and (tostring(stabberP.pool) .. "." .. tostring(stabberP.index)) or "?.?"
      Printf("[StabberPro]: Preset Type=\"%s\" Number=%s Name=\"%s\"", tostring(stabberP.typeName or ""), stabberPoolStr, tostring(stabberP.name or ""))
    end
  end

  -- MAtricks Info
  local stabberMI = stabberGetMAtricksInfo()
  Printf("[StabberPro]: MAtricks Active: %s", tostring(stabberMI.active))
  if stabberMI.addr then
    Printf("[StabberPro]: MAtricks Source: %s (%s)", tostring(stabberMI.source or "Unknown"), stabberMI.addr)
  end

  -- Fetch World (if any) - simplified, set to nil as not implemented
  local stabberWorld = nil  -- Replace with actual world detection if needed

  -- Get XGroup from MAtricks
  local stabberHelperIndex = nil
  local stabberXGroup = 0
  if stabberMI.active then
    local stabberPoolItem = (stabberMI.source == "Pool")
    stabberHelperIndex, _ = stabberRecipeMAtricksProg(stabberPoolItem)
    local stabberMAtricksObj
    if stabberHelperIndex then
      stabberMAtricksObj = DataPool().MAtricks[stabberHelperIndex]
    end
    if stabberMAtricksObj then
      stabberXGroup = stabberMAtricksObj.XGroup or 0
    end
  end

  -- Determine number of slices
  local stabberSlices = (stabberXGroup > 1) and stabberXGroup or stabberSelCount

  -- Create temporary sequence
  Cmd("Store Sequence \"StabberRecipeTemp\" /o")

  for stabberK = 1, stabberSlices do
    Cmd("Store Sequence \"StabberRecipeTemp\" Cue " .. stabberK)
    for stabberP = 1, #stabberPresets do
      local stabberY = stabberP
      Cmd("Store Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY)
      Cmd("Assign Group " .. stabberGroupIndex .. " at Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY)
      Cmd("Assign Preset " .. stabberPresets[stabberP].pool .. "." .. stabberPresets[stabberP].index .. " at Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY)
      if stabberWorld then
        Cmd("Assign World \"" .. stabberWorld .. "\" at Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY)
      end
      Cmd("Set Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY .. " Property \"X\" " .. stabberK)
      if stabberXGroup > 0 then
        Cmd("Set Sequence \"StabberRecipeTemp\" Cue " .. stabberK .. " Part 0." .. stabberY .. " Property \"XGroup\" " .. stabberXGroup)
      end
    end
  end

  -- Cleanup helper MAtricks if created
  if stabberHelperIndex then
    Cmd("Delete Matricks " .. stabberHelperIndex .. " /nc")
  end

  Printf("[StabberPro]: Temporary sequence 'StabberRecipeTemp' created with %d cues.", stabberSlices)
  Printf("[StabberPro]: ===== End =====")
end