local plugin_table, my_handle = select(3,...)
local function create_ui_object(parent,class,properties)
    local element = parent:Append(class)
    for k, v in pairs(properties) do
        element[k] = v
    end
    return element, element[1], element[2]
end
return function ()
    local tabs = {"Dimmer", "Position", "Gobo", "Color", "Beam", "Focus", "Control", "Shaper", "All 1", "All 2", "All 3"}
    local tabs_count = #tabs
    local dialog,dialog_rows = create_ui_object(GetFocusDisplay().ScreenOverlay,'BaseInput',{
        H = 400,
        W = 700,
        Columns = 2,
        Rows = 2
    })
    dialog_rows[1].SizePolicy = 'Content'
    dialog_rows[2].SizePolicy = 'Content'
    local title_bar,title_bar_rows,title_bar_columns = create_ui_object(dialog,'TitleBar',{
        Columns = 2,
        Rows =1,
        Texture = 'corner2',
        Anchors = '0,0,1,0'
    })
    title_bar_columns[2].SizePolicy = 'Fixed'
    title_bar_columns[2].Size = '50'
    create_ui_object(title_bar,'TitleButton',{
        Texture = 'corner1',
        text = 'Preset Selection',
        Anchors = '0,0'
    })
    create_ui_object(title_bar,'CloseButton',{
        Anchors = '1,0',
        Texture = 'corner2',
        focus = 'Never'
    })
    local dlg_frame,dlg_frame_rows,dlg_frame_columns = create_ui_object(dialog,'DialogFrame',{
        name = 'dlg_frame',
        H = '100%',
        W = '100%',
        Columns = 2,
        Rows = 1,
        Anchors = '0,1,1,1'
    })
    dlg_frame_rows[1].SizePolicy = 'Fixed'
    dlg_frame_rows[1].Size = 400
    dlg_frame_columns[1].SizePolicy = 'Fixed'
    dlg_frame_columns[1].Size = 75
    dlg_frame_columns[2].SizePolicy = 'Fixed'
    dlg_frame_columns[2].Size = tonumber(dialog.w:match('(%d+)%(.-%)'))-dlg_frame_columns[1].Size
    local dialog_container = create_ui_object(dlg_frame,'DialogContainer',{
        name = 'tab_contents',
        anchors = '1,0'
    })
    local dp = DataPool()
    for i=1,tabs_count do
        local value = 'value'..i
        local scroll_area, scroll_rows, scroll_columns = create_ui_object(dialog_container,'UIScrollArea',{
            name = value,
            anchors = '0,0,1,1',
            visible = false
        })
        local grid,grid_rows,grid_columns = create_ui_object(scroll_area,'UILayoutGrid',{
            margin = string.rep('10',4,','),
            columns = 1
        })
        local pool_name = tabs[i]
        local pool = dp.PresetPools[pool_name]
        if pool then
            local presets = pool:Children()
            grid.rows = #presets
            for j,preset in ipairs(presets) do
                grid_rows[j].SizePolicy = 'Content'
                create_ui_object(grid,'UIButton',{
                    text = preset.name,
                    anchors = '0,' .. (j-1)
                })
            end
        end
    end
    local ui_tab = create_ui_object(dlg_frame,'UITab',{
        h = 400,
        w = 75,
        name = 'my_tabs',
        type = 'Vertical',
        texture = 'corner5',
        itemsize = 100,
        TabChanged = 'tab_changed',
        PluginComponent = my_handle
    })
    ui_tab:WaitInit()
    for i=1,tabs_count do
        ui_tab:AddListStringItem(tabs[i],'value'..i)
    end
    ui_tab[1]:WaitChildren(tabs_count)
    for _,button in ipairs(ui_tab[1]:UIChildren()) do
        button.focus = 'Never'
    end
    ui_tab.SelectedItem = 1
    function plugin_table.tab_changed(caller)
        local overlay = caller:GetOverlay()
        local frame = overlay.dlg_frame
        local tab_count = caller:GetListItemsCount()
        for i=1, tab_count do
            local name = caller:GetListItemValueStr(i)
            local obj = frame:FindRecursive(name,'UIScrollArea')
            if name == caller.SelectedItemValueStr then
                obj.visible = true
            else
                obj.visible = false
            end
        end
    end
    plugin_table.tab_changed(ui_tab)
end