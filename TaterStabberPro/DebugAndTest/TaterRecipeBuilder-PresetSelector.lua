--[[
  Plugin: Edit Values (Dimmer Preset Buttons)
  Purpose: Tabs UI where the "Dimmer" tab
           dynamically shows buttons for PresetPool 1 (Dimmer).
]]--

local plugin_table, my_handle = select(3, ...)

local function create_ui_object(parent, class, properties)
  local element = parent:Append(class)
  if properties then
    for k, v in pairs(properties) do element[k] = v end
  end
  return element, element[1], element[2]
end

-- utility: collect occupied pool slots
local function eachOccupied(pool)
  local items = {}
  local n = pool and pool:Count() or 0
  for i = 1, n do
    local h = pool[i]
    if h and h:ToAddr() ~= nil then
      table.insert(items, h)
    end
  end
  return items
end

return function()
  local display = GetFocusDisplay()
  local overlay = display.ScreenOverlay
  overlay:ClearUIChildren()

  ---------------------------------------------------------------------------
  -- ROOT
  ---------------------------------------------------------------------------
  local dialog, dialog_rows = create_ui_object(overlay, "BaseInput", {
    Name          = "EditValuesDummy",
    H             = "80%",
    W             = "70%",
    MinSize       = "480,340",
    MaxSize       = "2000,1200",
    Columns       = 1,
    Rows          = 2,
    AutoClose     = "No",
    CloseOnEscape = "Yes",
  })
  dialog_rows[1].SizePolicy = "Content"
  dialog_rows[2].SizePolicy = "Stretch"

  -- Title bar
  local title_bar, _, tb_cols = create_ui_object(dialog, "TitleBar", {
    Columns = 2, Rows = 1, Anchors = "0,0"
  })
  tb_cols[2].SizePolicy = "Fixed"
  tb_cols[2].Size       = 50

  create_ui_object(title_bar, "TitleButton", { Text = "Edit Values (Dimmer Presets)", Anchors = "0,0" })
  create_ui_object(title_bar, "CloseButton", { Anchors = "1,0", focus = "Never" })

  ---------------------------------------------------------------------------
  -- FRAME: Left tabs + right container
  ---------------------------------------------------------------------------
  local frame, _, frame_cols = create_ui_object(dialog, "DialogFrame", {
    Name    = "dlg_frame",
    H       = "100%",
    W       = "100%",
    Columns = 2, Rows = 1,
    Anchors = "0,1"
  })
  frame_cols[1].SizePolicy = "Fixed"
  frame_cols[1].Size       = 180
  frame_cols[2].SizePolicy = "Stretch"

  local content = create_ui_object(frame, "DialogContainer", {
    Name    = "tab_contents",
    Anchors = "1,0"
  })

  ---------------------------------------------------------------------------
  -- LEFT TABS
  ---------------------------------------------------------------------------
  local families = { "1 Dimmer", "2 Position", "3 Gobo" }

  local ui_tab = create_ui_object(frame, "UITab", {
    H               = "100%",
    W               = 180,
    Name            = "family_tabs",
    Type            = "Vertical",
    ItemSize        = 55,
    TabChanged      = "tab_changed",
    PluginComponent = my_handle,
    Anchors         = "0,0"
  })
  ui_tab = ui_tab

  ui_tab:WaitInit()
  for i = 1, #families do
    local value_name = ("family_page_%02d"):format(i)
    ui_tab:AddListStringItem(families[i], value_name)
  end
  ui_tab[1]:WaitChildren(#families)

  ---------------------------------------------------------------------------
  -- BUILD PAGE FUNCTION
  ---------------------------------------------------------------------------
  local function build_family_page(idx, label)
    local page, page_rows = create_ui_object(content, "UILayoutGrid", {
      Name    = ("family_page_%02d"):format(idx),
      Columns = 1, Rows = 2,
      Margin  = "10,10,10,10",
      Anchors = "0,0"
    })
    page_rows[1].SizePolicy = "Fixed"
    page_rows[1].Size       = 42
    page_rows[2].SizePolicy = "Stretch"

    -- search bar
    local search_wrap, sr = create_ui_object(page, "UILayoutGrid", {
      Columns = 1, Rows = 1, Anchors = "0,0"
    })
    sr[1].SizePolicy = "Fixed"
    sr[1].Size       = 40
    create_ui_object(search_wrap, "LineEdit", { Placeholder = "Search…", Anchors = "0,0" })

    -- list
    local list = create_ui_object(page, "UILayoutGrid", {
      Columns = 1, Rows = 12, Anchors = "0,1"
    })

    -- inside build_family_page (Dimmer tab section)
if idx == 1 then
  -- DIMMER TAB (real PresetPool[1]) with multi-column grid
  local dimmer_presets = eachOccupied(DataPool().PresetPools[1])
  local perRow = 4   -- number of buttons per row
  local total = #dimmer_presets
  local rows = math.ceil(total / perRow)

  local list = create_ui_object(page, "UILayoutGrid", {
    Name    = "list_wrap_dimmer",
    Columns = perRow,
    Rows    = rows,
    Anchors = "0,1",
    Margin  = "4,4,4,4"
  })

  for i, p in ipairs(dimmer_presets) do
    local r = math.floor((i-1) / perRow)
    local c = (i-1) % perRow
    local btn = list:Append("Button")
    btn.Text = ("Preset %d - %s"):format(
      p.No or i,
      (p.Name ~= "" and p.Name) and p.Name or "Unnamed"
    )
    btn.Anchors = ("%d,%d"):format(c, r)
    btn.H = 36
    btn.PluginComponent = my_handle
    btn.Clicked = "on_button_pressed"
    btn.presetNo = p.No or i
  end

    return page
  end

  for i, label in ipairs(families) do build_family_page(i, label) end

  -- show only first tab initially
  local first_value = ui_tab:GetListItemValueStr(1)
  for i = 1, #families do
    local key = ui_tab:GetListItemValueStr(i)
    local obj = frame:FindRecursive(key, "UILayoutGrid")
    obj.visible = (key == first_value)
  end

  ---------------------------------------------------------------------------
  -- HANDLERS
  ---------------------------------------------------------------------------
  function plugin_table.tab_changed(caller)
    local overlay = caller:GetOverlay()
    local f = overlay.dlg_frame
    local count = caller:GetListItemsCount()
    for i = 1, count do
      local key = caller:GetListItemValueStr(i)
      local page = f:FindRecursive(key, "UILayoutGrid")
      page.visible = (key == caller.SelectedItemValueStr)
    end
  end

  function plugin_table.on_button_pressed(caller)
    Echo("[Plugin] Button pressed: " .. tostring(caller.Text))
    if caller.presetNo then
      Cmd(("Preset 1.%d"):format(caller.presetNo))
    end
  end
end