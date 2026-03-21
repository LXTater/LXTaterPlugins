-- grandMA3 Plugin: TaterRelabel
-- Description: Bulk relabeling & copy-rename tool.
--              Mode 1 — Relabel Only: Add prefix/suffix to existing labels.
--              Mode 2 — Copy & Rename: Copy a source range to a new destination
--                       and relabel the copies with a prefix or suffix.
--              Optionally strips MA auto-number suffixes (#2, #3, etc.).
-- Author: LXTater
-- Plugin Version: 0.0.0.0
-- MA3 Version: 2.3.x
-- https://www.lxtater.com
-- https://github.com/LXTater/LXTaterPlugins/
-- ACTIVELY DEVELOPING — USE WITH CAUTION, update will be uploaded as their developed.

--[[ How to Use:
    Import the plugin into your plugin data pool.
    Run it, and follow the on-screen prompts:

    RELABEL ONLY:
      1. Pick a datapool type (Sequence, Group, Macro, etc.)
      2. Enter the start and end of the range
      3. Choose Prefix or Suffix
      4. Type the text to add
      5. If any items have MA auto-numbers (#2, #3…), choose to strip them
      6. Confirm the preview and apply

    COPY & RENAME:
      1. Pick a datapool type
      2. Enter the ORIGIN (source) start and end range
      3. Enter the DESTINATION start slot
      4. Choose Prefix or Suffix
      5. Type the text to add
      6. If any origin items have MA auto-numbers, choose to strip them
      7. Confirm the preview — plugin copies then relabels
]]


return function()

  -- =========================================================================
  -- LXTater Helpers
  -- =========================================================================

  local pluginTag = "TaterRelabel"

  local function msg(s)   Printf("[%s] %s", pluginTag, s) end
  local function err(s)   ErrPrintf("[%s] %s", pluginTag, s) end
  local function trim(s)  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

  local function safeCmdIndirect(s)
    local ok, why = pcall(CmdIndirect, s)
    if not ok then err("Cmd failed: " .. tostring(s) .. " -> " .. tostring(why)) end
    return ok
  end

  -- =========================================================================
  -- Datapool Type Definitions
  -- Each entry: { displayName, datapoolKey, cmdKeyword }
  --   displayName  = shown in MessageBox
  --   datapoolKey  = property name on DataPool()  (e.g. DataPool().Sequences)
  --   cmdKeyword   = used for Label command  (Label <cmdKeyword> <num> "<name>")
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
  -- Helpers
  -- =========================================================================

  --- Get the datapool pool handle for a given datapoolKey
  local function getPool(datapoolKey)
    local ok, dp = pcall(DataPool)
    if not ok or not dp then return nil end
    return dp[datapoolKey]
  end

  --- Check if a name contains MA auto-number suffix (e.g. " #2", " #3")
  local function hasAutoNumber(name)
    return name and name:match(" #%d+$") ~= nil
  end

  --- Strip the MA auto-number suffix from a name
  local function stripAutoNumber(name)
    if not name then return "" end
    return name:gsub(" #%d+$", "")
  end

  --- Collect items in a range from a datapool pool, returns table of {no, name}
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

  --- Check if any items in the list have auto-numbering
  local function anyAutoNumbered(items)
    for _, item in ipairs(items) do
      if hasAutoNumber(item.name) then return true end
    end
    return false
  end

  --- Build a preview string showing old → new labels
  local function buildPreview(items, value, isPrefix, doStripAuto)
    local lines = {}
    for _, item in ipairs(items) do
      local baseName = item.name
      if doStripAuto then baseName = stripAutoNumber(baseName) end

      local newName
      if isPrefix then
        newName = value .. baseName
      else
        newName = baseName .. value
      end

      local tag = ""
      if doStripAuto and hasAutoNumber(item.name) then tag = "  ← stripped #" end
      table.insert(lines, string.format("  %d: \"%s\" → \"%s\"%s", item.no, item.name, newName, tag))
    end
    return table.concat(lines, "\n")
  end

  --- Apply the relabeling via Cmd
  local function applyRelabel(items, value, isPrefix, doStripAuto, cmdKeyword)
    local count = 0
    for _, item in ipairs(items) do
      local baseName = item.name
      if doStripAuto then baseName = stripAutoNumber(baseName) end

      local newName
      if isPrefix then
        newName = value .. baseName
      else
        newName = baseName .. value
      end

      local cmdStr = string.format('Label %s %d "%s"', cmdKeyword, item.no, newName)
      msg(string.format("Labeling %s %d → \"%s\"", cmdKeyword, item.no, newName))
      if safeCmdIndirect(cmdStr) then
        count = count + 1
      end
    end
    return count
  end

  --- Compute the new name for a given original name
  local function computeNewName(origName, value, isPrefix, doStripAuto)
    local baseName = origName
    if doStripAuto then baseName = stripAutoNumber(baseName) end
    if isPrefix then
      return value .. baseName
    else
      return baseName .. value
    end
  end

  --- Build a preview for copy & rename showing source → destination + new label
  local function buildCopyPreview(items, destStart, value, isPrefix, doStripAuto, cmdKeyword)
    local lines = {}
    for idx, item in ipairs(items) do
      local destSlot = destStart + (idx - 1)
      local newName = computeNewName(item.name, value, isPrefix, doStripAuto)
      local tag = ""
      if doStripAuto and hasAutoNumber(item.name) then tag = "  ← stripped #" end
      table.insert(lines, string.format(
        "  %s %d → %s %d : \"%s\" → \"%s\"%s",
        cmdKeyword, item.no, cmdKeyword, destSlot, item.name, newName, tag
      ))
    end
    return table.concat(lines, "\n")
  end

  --- Copy source items to destination slots, then relabel the copies
  local function applyCopyAndRelabel(items, destStart, value, isPrefix, doStripAuto, cmdKeyword)
    local copyCount = 0
    local labelCount = 0

    for idx, item in ipairs(items) do
      local destSlot = destStart + (idx - 1)

      -- Copy source → destination
      local copyCmd = string.format('Copy %s %d At %s %d', cmdKeyword, item.no, cmdKeyword, destSlot)
      msg(string.format("Copying %s %d → %d", cmdKeyword, item.no, destSlot))
      if safeCmdIndirect(copyCmd) then
        copyCount = copyCount + 1

        -- Relabel the destination copy
        local newName = computeNewName(item.name, value, isPrefix, doStripAuto)
        local labelCmd = string.format('Label %s %d "%s"', cmdKeyword, destSlot, newName)
        msg(string.format("Labeling %s %d → \"%s\"", cmdKeyword, destSlot, newName))
        if safeCmdIndirect(labelCmd) then
          labelCount = labelCount + 1
        end
      end
    end

    return copyCount, labelCount
  end

  -- =========================================================================
  -- UI Flow
  -- =========================================================================

  --- Step 0: Choose mode — Relabel Only or Copy & Rename
  local function pickMode()
    local box = MessageBox({
      title = "TaterRelabel — Choose Mode",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = "What would you like to do?\n\n"
             .. "Relabel Only — Add prefix/suffix to existing labels in-place.\n\n"
             .. "Copy & Rename — Copy a source range to a new destination\n"
             .. "and relabel the copies with a prefix or suffix.",
      commands = {
        { value = 1, name = "Relabel Only" },
        { value = 2, name = "Copy & Rename" },
        { value = 0, name = "Cancel" },
      }
    })

    if not box or box.result == 0 then return nil end
    return box.result  -- 1 = relabel only, 2 = copy & rename
  end

  --- Step 1: Pick datapool type
  local function pickDatapoolType()
    local cmds = {}
    for i, dp in ipairs(datapoolTypes) do
      table.insert(cmds, { value = i, name = dp[1] })
    end
    table.insert(cmds, { value = 0, name = "Cancel" })

    local box = MessageBox({
      title = "TaterRelabel — Pick Datapool Type",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = "Select the type of datapool objects you want to relabel.",
      commands = cmds
    })

    if not box or box.result == 0 then return nil end
    return datapoolTypes[box.result]
  end

  --- Step 2: Enter range (start, end)
  local function pickRange(displayName, headerOverride)
    local header = headerOverride or (displayName .. " range you want to relabel.")
    local result = MessageBox({
      title = "TaterRelabel — " .. displayName .. " Range",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = "Enter the start and end numbers for the\n"
             .. header,
      commands = {
        { value = 1, name = "Continue" },
        { value = 0, name = "Cancel" },
      },
      inputs = {
        { name = "Start", value = "1", whiteFilter = "1234567890", vkPlugin = "NumericInput", maxTextLength = 6 },
        { name = "End",   value = "10", whiteFilter = "1234567890", vkPlugin = "NumericInput", maxTextLength = 6 },
      },
    })

    if not result or result.result ~= 1 then return nil, nil end

    local startNum = tonumber(result.inputs.Start)
    local endNum   = tonumber(result.inputs["End"])

    if not startNum or not endNum then
      err("Invalid range numbers.")
      return nil, nil
    end

    if startNum > endNum then
      err("Start must be less than or equal to End.")
      return nil, nil
    end

    return startNum, endNum
  end

  --- Step 3: Choose Prefix or Suffix
  local function pickPrefixOrSuffix()
    local box = MessageBox({
      title = "TaterRelabel — Prefix or Suffix?",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = "Would you like to add text BEFORE (Prefix)\nor AFTER (Suffix) the existing labels?",
      commands = {
        { value = 1, name = "Prefix" },
        { value = 2, name = "Suffix" },
        { value = 0, name = "Cancel" },
      }
    })

    if not box or box.result == 0 then return nil end
    return box.result == 1 -- true = prefix, false = suffix
  end

  --- Step 4: Enter the text value to add
  local function pickValue(isPrefix)
    local mode = isPrefix and "Prefix" or "Suffix"
    local val = TextInput("Enter the " .. mode .. " text to add:", "")
    if not val or trim(val) == "" then
      err("No text entered. Aborting.")
      return nil
    end
    return val
  end

  --- Step 5: Ask about auto-number stripping (only if any are found)
  local function askStripAutoNumber(items)
    -- Collect examples of auto-numbered items for display
    local examples = {}
    for _, item in ipairs(items) do
      if hasAutoNumber(item.name) and #examples < 5 then
        table.insert(examples, string.format("  %d: \"%s\"", item.no, item.name))
      end
    end

    local exampleStr = table.concat(examples, "\n")
    if #examples < #items then
      exampleStr = exampleStr .. "\n  ... and more"
    end

    local box = MessageBox({
      title = "TaterRelabel — Auto-Number Detected",
      icon = "warning_triangle_big",
      titleTextColor = "Global.AlertText",
      message = "Some items have MA auto-number suffixes (#2, #3, etc.).\n\n"
             .. "Examples:\n" .. exampleStr .. "\n\n"
             .. "Would you like to REMOVE the auto-number\n"
             .. "suffixes before adding your prefix/suffix?",
      commands = {
        { value = 1, name = "Yes, Strip #" },
        { value = 2, name = "No, Keep #" },
        { value = 0, name = "Cancel" },
      }
    })

    if not box or box.result == 0 then return nil end
    return box.result == 1
  end

  --- Step 6: Confirm preview (relabel only)
  local function confirmPreview(items, value, isPrefix, doStripAuto, displayName)
    local mode = isPrefix and "Prefix" or "Suffix"
    local stripNote = doStripAuto and "Auto-numbers WILL be stripped.\n\n" or ""
    local previewStr = buildPreview(items, value, isPrefix, doStripAuto)

    local box = MessageBox({
      title = "TaterRelabel — Confirm Changes",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = string.format(
        "Datapool: %s\nMode: %s\nText: \"%s\"\nItems: %d\n%s"
        .. "Preview:\n%s",
        displayName, mode, value, #items, stripNote, previewStr
      ),
      commands = {
        { value = 1, name = "Apply" },
        { value = 0, name = "Cancel" },
      }
    })

    if not box or box.result ~= 1 then return false end
    return true
  end

  --- Step 6 (copy mode): Confirm copy & rename preview
  local function confirmCopyPreview(items, destStart, value, isPrefix, doStripAuto, displayName, cmdKeyword)
    local mode = isPrefix and "Prefix" or "Suffix"
    local stripNote = doStripAuto and "Auto-numbers WILL be stripped.\n\n" or ""
    local destEnd = destStart + #items - 1
    local previewStr = buildCopyPreview(items, destStart, value, isPrefix, doStripAuto, cmdKeyword)

    local box = MessageBox({
      title = "TaterRelabel — Confirm Copy & Rename",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = string.format(
        "Datapool: %s\nMode: %s\nText: \"%s\"\n"
        .. "Source: %d items\nDestination: %d–%d\n%s"
        .. "Preview:\n%s",
        displayName, mode, value,
        #items, destStart, destEnd, stripNote, previewStr
      ),
      commands = {
        { value = 1, name = "Apply" },
        { value = 0, name = "Cancel" },
      }
    })

    if not box or box.result ~= 1 then return false end
    return true
  end

  --- Pick destination start slot for copy mode
  local function pickDestination(displayName, itemCount)
    local result = MessageBox({
      title = "TaterRelabel — Destination",
      icon = "object_smart",
      titleTextColor = "Global.Focus",
      message = string.format(
        "You are copying %d %s item(s).\n\n"
        .. "Enter the STARTING slot number for the destination.\n"
        .. "Items will be placed at slots %s through %s+%d.",
        itemCount, displayName, "<start>", "<start>", itemCount - 1
      ),
      commands = {
        { value = 1, name = "Continue" },
        { value = 0, name = "Cancel" },
      },
      inputs = {
        { name = "DestStart", value = "101", whiteFilter = "1234567890", vkPlugin = "NumericInput", maxTextLength = 6 },
      },
    })

    if not result or result.result ~= 1 then return nil end

    local destStart = tonumber(result.inputs.DestStart)
    if not destStart then
      err("Invalid destination number.")
      return nil
    end

    return destStart
  end

  -- =========================================================================
  -- Main
  -- =========================================================================

  local function mainMenu()
    -- Step 0: Choose mode
    local mode = pickMode()
    if not mode then
      msg("Cancelled.")
      return
    end

    local isCopyMode = (mode == 2)

    -- Step 1: Datapool type
    local dpType = pickDatapoolType()
    if not dpType then
      msg("Cancelled.")
      return
    end

    local displayName  = dpType[1]
    local datapoolKey  = dpType[2]
    local cmdKeyword   = dpType[3]

    -- Step 2: Source / Origin range
    local rangeLabel = isCopyMode
      and (displayName .. " ORIGIN (source) range to copy from.")
      or  nil  -- nil = default label
    local startNum, endNum = pickRange(displayName, rangeLabel)
    if not startNum then
      msg("Cancelled.")
      return
    end

    -- Collect items in source range
    local pool = getPool(datapoolKey)
    if not pool then
      err("Could not access DataPool()." .. datapoolKey .. ". Make sure it exists.")
      return
    end

    local items = collectItems(pool, startNum, endNum)
    if #items == 0 then
      MessageBox({
        title = "TaterRelabel — No Items Found",
        icon = "warning_triangle_big",
        message = string.format("No %s objects with labels found in range %d–%d.", displayName, startNum, endNum),
        commands = { { value = 1, name = "OK" } }
      })
      msg("No items found in range.")
      return
    end

    msg(string.format("Found %d %s item(s) in range %d–%d.", #items, displayName, startNum, endNum))

    -- Step 2b (copy mode only): Destination start slot
    local destStart = nil
    if isCopyMode then
      destStart = pickDestination(displayName, #items)
      if not destStart then
        msg("Cancelled.")
        return
      end

      -- Warn if destination overlaps with source
      local destEnd = destStart + #items - 1
      if destStart <= endNum and destEnd >= startNum then
        local overlap = MessageBox({
          title = "TaterRelabel — Overlap Warning!",
          icon = "warning_triangle_big",
          titleTextColor = "Global.AlertText",
          message = string.format(
            "Destination range %d–%d overlaps with source range %d–%d!\n\n"
            .. "This may cause unexpected results.\nContinue anyway?",
            destStart, destEnd, startNum, endNum
          ),
          commands = {
            { value = 1, name = "Continue" },
            { value = 0, name = "Cancel" },
          }
        })
        if not overlap or overlap.result ~= 1 then
          msg("Cancelled.")
          return
        end
      end
    end

    -- Step 3: Prefix or Suffix
    local isPrefix = pickPrefixOrSuffix()
    if isPrefix == nil then
      msg("Cancelled.")
      return
    end

    -- Step 4: Value
    local value = pickValue(isPrefix)
    if not value then
      msg("Cancelled.")
      return
    end

    -- Step 5: Auto-number detection
    local doStripAuto = false
    if anyAutoNumbered(items) then
      local answer = askStripAutoNumber(items)
      if answer == nil then
        msg("Cancelled.")
        return
      end
      doStripAuto = answer
    end

    -- Step 6: Preview and confirm
    if isCopyMode then
      -- Copy & Rename flow
      local confirmed = confirmCopyPreview(items, destStart, value, isPrefix, doStripAuto, displayName, cmdKeyword)
      if not confirmed then
        msg("Cancelled.")
        return
      end

      local copyCount, labelCount = applyCopyAndRelabel(items, destStart, value, isPrefix, doStripAuto, cmdKeyword)
      local destEnd = destStart + #items - 1

      MessageBox({
        title = "TaterRelabel — Copy & Rename Complete!",
        icon = "object_smart",
        titleTextColor = "Global.Focus",
        message = string.format(
          "Copied %d of %d item(s) to slots %d–%d.\nRelabeled %d of %d copies.",
          copyCount, #items, destStart, destEnd, labelCount, #items
        ),
        commands = { { value = 1, name = "OK" } }
      })

      msg(string.format("Done. Copied %d, labeled %d of %d items.", copyCount, labelCount, #items))

    else
      -- Relabel Only flow
      local confirmed = confirmPreview(items, value, isPrefix, doStripAuto, displayName)
      if not confirmed then
        msg("Cancelled.")
        return
      end

      local count = applyRelabel(items, value, isPrefix, doStripAuto, cmdKeyword)

      MessageBox({
        title = "TaterRelabel — Complete!",
        icon = "object_smart",
        titleTextColor = "Global.Focus",
        message = string.format("Successfully relabeled %d of %d %s item(s).", count, #items, displayName),
        commands = { { value = 1, name = "OK" } }
      })

      msg(string.format("Done. Relabeled %d of %d items.", count, #items))
    end

    -- Ask if user wants to run again
    local again = MessageBox({
      title = "TaterRelabel",
      message = "Would you like to run TaterRelabel again?",
      commands = {
        { value = 1, name = "Yes" },
        { value = 2, name = "No" },
      }
    })

    if again and again.result == 1 then
      mainMenu()
    end
  end

  mainMenu()
end
