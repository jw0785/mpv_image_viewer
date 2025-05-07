local mp = require 'mp'
local scripts_dir = mp.find_config_file("scripts")
if scripts_dir then
    package.path = package.path .. ";" .. scripts_dir .. "/?.lua"
else
    mp.msg.error("Could not find the 'scripts' directory.")
end
local playlist_nav_tui = require 'playlist_nav_tui'

local is_fitwidth_active = false

local debounce_duration = 0.5 -- in seconds
local debounce_active = {} -- Table to track debounce state for each key
local function is_debounce_active(key)
    return debounce_active[key] == true
end
local function activate_debounce(key)
    debounce_active[key] = true
    mp.add_timeout(debounce_duration, function()
        debounce_active[key] = nil
    end)
end

local shared_keys = {}
for _, key in ipairs(playlist_nav_tui.all_local_keybinds) do
    shared_keys[key] = true
end
local function is_tui_active()
    return playlist_nav_tui.get_active_state()
end

local function is_in_center_strip(x, window_width)
	--[[ vertically split the window into 3 parts, only left and right parts allow primary click
	it's useful for touchscreen devices, the reason being,
	mpv use double click middle part to toggle fullscreen,
	without this handling, and the brute force method below, which briefly clear all the keybind in debouncing duration,
	double click will glitch and register twice, cause navigation to the next image after entering or quit fullscreen ]]
    local strip_width = math.floor(window_width / 3) -- integer
    local center_start = strip_width
    local center_end = strip_width * 2
    return x >= center_start and x <= center_end
end

local function fitwidth_topalign()
    local window_width, window_height = mp.get_osd_size()
    local video_width = mp.get_property_number("width")
    local video_height = mp.get_property_number("height")
    if window_width >= video_width and window_height >= video_height then
        mp.set_property("video-unscaled", "no")
        local window_ratio  = window_width / window_height
        local video_ratio = video_width / video_height
        if window_ratio > video_ratio then
			-- when i try to fit the video, it overflows, when i try to overflow, it... but it works, so it's good
            video_height = window_height
            video_width = video_height * video_ratio
        elseif window_ratio < video_ratio then
            video_width = window_width
            video_height = video_width / video_ratio
        else
            return
        end
    elseif video_width < window_width and video_height > window_height then
        mp.set_property("video-unscaled", "yes")
        local video_ratio = video_width / video_height
        video_width = window_width /1.5 -- some magical threshold
        video_height = video_width / video_ratio
    end
    local scale = window_width / video_width - 1
    local scaled_video_height = video_height * (1+scale)
    local pan_y = (scaled_video_height - window_height) / (2 * scaled_video_height) 
    mp.set_property("video-pan-y", pan_y)
    mp.set_property("video-zoom", scale)
    mp.osd_message(string.format(
    "Video: %dx%d, Window: %dx%d\nScale: %.3f\nScaled height: %.1f\nPan Y: %.3f",
    video_width, video_height, window_width, window_height,
    scale, scaled_video_height, pan_y), 4)

    is_fitwidth_active = true
end

-- reset transformations and disable fitwidth mode
local function reset_transformations()
    mp.set_property("video-zoom", 0)
    mp.set_property("video-pan-x", 0)
    mp.set_property("video-pan-y", 0)
    mp.set_property("video-rotate", 0)
    mp.set_property("video-unscaled", "no")
    mp.osd_message("Reset Transformation")
    
    -- Set the fitwidth flag to false
    is_fitwidth_active = false
end

-- Check if image needs special handling
local function needs_special_handling()
    local window_height = mp.get_osd_size()
    local video_height = mp.get_property_number("height")
    return video_height > window_height
end

local function navigate_with_debounce(direction)
    local key = direction
    -- Only apply in fitwidth mode
    if is_fitwidth_active then
        if is_debounce_active(key) then
            mp.msg.info("Navigation " .. direction .. " debounced: Ignored")
            return
        end
        activate_debounce(key)
    end
    -- Always perform the navigation
    if direction == "next" then
        mp.command("playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\"")
    else
        mp.command("playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\"")
    end
    if is_fitwidth_active and needs_special_handling() then
        mp.add_timeout(0.1, fitwidth_topalign)
    end
end
-- ignore center strip
local function handle_left_click()
    local x, _ = mp.get_mouse_pos()
    local window_width, _ = mp.get_osd_size()
    if is_in_center_strip(x, window_width) then
        if is_debounce_active("MBTN_LEFT") then
            mp.msg.info("Middle part click debounced: Ignored")
            return
        end
        mp.msg.info("Middle part click ignored: center strip")
        activate_debounce("MBTN_LEFT")
        return
    end
    navigate_with_debounce("next")
end

local bindings = {
    {"MBTN_LEFT", handle_left_click},
    {"MBTN_RIGHT", function() navigate_with_debounce("prev") end},
    {"d", function() navigate_with_debounce("next") end},
    {"a", function() navigate_with_debounce("prev") end},
    {"w", function() navigate_with_debounce("next") end},
    {"s", function() navigate_with_debounce("prev") end},
    {"LEFT", function() navigate_with_debounce("prev") end},
    {"RIGHT", function() navigate_with_debounce("next") end},
    {"UP", function() navigate_with_debounce("next") end},
    {"DOWN", function() navigate_with_debounce("prev") end},
    {"PGUP", function()
        local window_width, window_height = mp.get_osd_size()
        local video_height = mp.get_property_number("height")
        if video_height < window_height then
            mp.command("add playlist-pos 5 ; show-text \"${playlist-pos-1}/${playlist-count}\"")
        else
            mp.command("add video-pan-y 0.05")
        end
    end},
    {"PGDWN", function()
        local window_width, window_height = mp.get_osd_size()
        local video_height = mp.get_property_number("height")
        if video_height < window_height then
            mp.command("add playlist-pos -5 ; show-text \"${playlist-pos-1}/${playlist-count}\"")
        else
            mp.command("add video-pan-y -0.05")
        end
    end},
    {"HOME", "set playlist-pos-1 1 ; show-text \"${playlist-pos-1}/${playlist-count}\""},
    {"END", "set playlist-pos-1 ${playlist-count} ; show-text \"${playlist-pos-1}/${playlist-count}\""},
    {"CTRL+WHEEL_UP", "add video-zoom 0.05"},
    {"CTRL+WHEEL_DOWN", "add video-zoom -0.05"},
    {"WHEEL_UP", "add video-pan-y 0.05"},
    {"WHEEL_DOWN", "add video-pan-y -0.05"},
    {"ALT+WHEEL_UP", "add video-pan-y 0.001"},
    {"ALT+WHEEL_DOWN", "add video-pan-y -0.001"},
    {"Shift+WHEEL_UP", "add video-pan-x 0.05"},
    {"Shift+WHEEL_DOWN", "add video-pan-x -0.05"},
    {"Shift+RIGHT", "add video-pan-x 0.05"},
    {"Shift+LEFT", "add video-pan-x -0.05"},
    {"Shift+UP", "add video-pan-y -0.05"},
    {"Shift+DOWN", "add video-pan-y 0.05"},
    {"CTRL+0", reset_transformations},
    {"CTRL+r", "add video-rotate +90"},
    {"CTRL+SHIFT+r", "add video-rotate -90"},
    {"SHIFT+r", "add video-rotate -90"},
    {"g", "script-message toggle_playlist_index_navigator"},
    {"9", "ignore"},
    {"/", "ignore"},
    {"0", reset_transformations},
    {"F", fitwidth_topalign},
    {"t", fitwidth_topalign},
    {"MBTN_MID", reset_transformations},
    {"WHEEL_LEFT","add video-pan-x 0.05"},
    {"WHEEL_RIGHT","add video-pan-x -0.05"},
    {"SPACE","ignore"},
    {"p","ignore"},
}

local function apply_bindings()
    for _, bind in ipairs(bindings) do
        local key = bind[1]
        mp.remove_key_binding("custom_" .. key)
        
        if not (is_tui_active() and shared_keys[key]) then
            local action = bind[2]
            if type(action) == "string" then
                mp.add_forced_key_binding(key, "custom_" .. key, function()
                    mp.command(action)
                end, {repeatable = true})
            elseif type(action) == "function" then
                mp.add_forced_key_binding(key, "custom_" .. key, action, {repeatable = true})
            end
        end
    end
end

local function main()
    local is_image = mp.get_property_native("current-tracks/video/image")
    local is_album_art = mp.get_property_native("current-tracks/video/albumart")

    is_fitwidth_active = false
    
    if is_image and not is_album_art then
        apply_bindings()
        mp.msg.info("Applied image viewer bindings")
    else
        for _, bind in ipairs(bindings) do
            local key = bind[1]
            mp.remove_key_binding("custom_" .. key)
        end
        mp.msg.info("Removed image viewer bindings")
    end
end

mp.register_event("file-loaded", main)

local function on_tui_state_change()
    main()
end
mp.register_script_message("tui_activated", on_tui_state_change)
mp.register_script_message("tui_deactivated", on_tui_state_change)