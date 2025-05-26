local mp = require 'mp'

local input_buffer = ""
local is_active = false

-- Function to sanitize and validate input
local function jump_to_index()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    local index = tonumber(input_buffer)

    if index == nil or index < 1 or index > playlist_count then
        mp.osd_message("Invalid input: " .. input_buffer, 5)
    else
        mp.osd_message("Jumping to index: " .. index, 5)
        mp.commandv("playlist-play-index", index - 1) -- Lua uses 0-based index, mpv playlist uses 1-based
        -- Show success message for a short time (5 seconds)
        mp.osd_message("Jumped to index: " .. index, 5)
    end

    -- Keep input mode active; do not deactivate it after a successful jump.
    -- input_buffer is cleared after a jump
    input_buffer = ""
end

-- Function to deactivate input mode and unbind keys
local function deactivate_input_mode()
    if not is_active then return end
    is_active = false
    mp.osd_message("Navigator deactivated", 2)
    unbind_keys()
end

-- Function to handle input
local function handle_input(input)
    local playlist_count = mp.get_property_number("playlist-count", 0)  -- Fetch the playlist count dynamically

    if input == "ESC" then
        -- Exit on ESC
        mp.osd_message("Cancelled", 1)
        input_buffer = ""
        deactivate_input_mode()
        return
    elseif input == "ENTER" then
        -- Process input when ENTER is pressed
        jump_to_index()
        return
    elseif input == "BS" then
        -- Handle Backspace: remove the last character from input_buffer
        if #input_buffer > 0 then
            input_buffer = input_buffer:sub(1, -2)
            mp.osd_message("Index: " .. input_buffer .. "/" .. playlist_count, 9999)
        else
            mp.osd_message("Index is empty", 9999)
        end
    elseif tonumber(input) ~= nil then
        -- If it's a number, add it to the buffer
        input_buffer = input_buffer .. input
        mp.osd_message("Index: " .. input_buffer .. "/" .. playlist_count, 9999)
    else
        mp.osd_message("Invalid input: " .. input, 5)
    end
end

-- Function to activate the TUI
local function jump_to_playlist_index()
    if is_active then return end
    is_active = true
    input_buffer = ""
    mp.osd_message("Enter playlist index: ", 2)
    mp.add_forced_key_binding("ESC", "cancel_input", function() handle_input("ESC") end)
    mp.add_forced_key_binding("ENTER", "submit_input", function() handle_input("ENTER") end)
    mp.add_forced_key_binding("BS", "backspace", function() handle_input("BS") end) -- Bind Backspace

    -- Bind all numeric keys
    for i = 0, 9 do
        mp.add_forced_key_binding(tostring(i), "input_" .. tostring(i), function() handle_input(tostring(i)) end)
    end
end

-- Unbind the key bindings when deactivating input mode
local function unbind_keys()
    mp.remove_key_binding("cancel_input")
    mp.remove_key_binding("submit_input")
    mp.remove_key_binding("backspace")  -- Unbind Backspace key

    for i = 0, 9 do
        mp.remove_key_binding("input_" .. tostring(i))
    end
end

-- Expose the function to trigger via script-message
mp.register_script_message("jump_to_playlist_index", jump_to_playlist_index)
