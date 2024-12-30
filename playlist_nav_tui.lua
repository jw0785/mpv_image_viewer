local mp = require 'mp'

local playlist_nav = {
    input_buffer = "",
    is_active = false,
    all_local_keybinds = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "ESC", "ENTER", "BS"}
}

function playlist_nav.set_active_state(state)
    playlist_nav.is_active = state
end

function playlist_nav.get_active_state()
    return playlist_nav.is_active
end

function playlist_nav.jump_to_index()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    local index = tonumber(playlist_nav.input_buffer)
    if index and index >= 1 and index <= playlist_count then
        mp.commandv("playlist-play-index", index - 1)  -- Lua uses 0-based index, mpv playlist uses 1-based
        mp.osd_message("Jumped to index: " .. index, 5)
    else
        mp.osd_message("Invalid input: " .. playlist_nav.input_buffer, 5)
    end
    playlist_nav.input_buffer = ""  -- Clear buffer after use
end

function playlist_nav.deactivate_input_mode()
    if not playlist_nav.is_active then return end
    playlist_nav.is_active = false
    mp.osd_message("Navigator deactivated", 2)
    playlist_nav.unbind_keys()
end

function playlist_nav.handle_input(input)
    if input == "ESC" then
        mp.osd_message("Cancelled", 1)
        playlist_nav.input_buffer = ""
        playlist_nav.deactivate_input_mode()
		return
    elseif input == "ENTER" then
        playlist_nav.jump_to_index()
    elseif input == "BS" then
        if #playlist_nav.input_buffer > 0 then
            playlist_nav.input_buffer = playlist_nav.input_buffer:sub(1, -2)
            mp.osd_message("Index: " .. playlist_nav.input_buffer, 9999)
        end
    elseif tonumber(input) then
        playlist_nav.input_buffer = playlist_nav.input_buffer .. input
        mp.osd_message("Index: " .. playlist_nav.input_buffer, 9999)
    else
        mp.osd_message("Invalid input: " .. input, 5)
    end
end

function playlist_nav.activate_input_mode()
    if playlist_nav.is_active then return end
    playlist_nav.is_active = true
    playlist_nav.input_buffer = ""
    mp.osd_message("Enter playlist index:", 2)
    for _, key in ipairs(playlist_nav.all_local_keybinds) do
        mp.add_forced_key_binding(key, "input_" .. key, function() playlist_nav.handle_input(key) end)
    end
end

function playlist_nav.unbind_keys()
    for _, key in ipairs(playlist_nav.all_local_keybinds) do
        mp.remove_key_binding("input_" .. key)
    end
end

mp.register_script_message("toggle_playlist_index_navigator", function()
    if playlist_nav.get_active_state() then
        playlist_nav.deactivate_input_mode()
    else
        playlist_nav.activate_input_mode()
    end
end)

-- return module table
return playlist_nav
