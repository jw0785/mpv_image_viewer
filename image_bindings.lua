local mp = require 'mp'
local scripts_dir = mp.find_config_file("scripts")
if scripts_dir then
    package.path = package.path .. ";" .. scripts_dir .. "/?.lua"
else
    mp.msg.error("Could not find the 'scripts' directory.")
end
local playlist_nav_tui = require 'playlist_nav_tui'

-- handle repeatitive triggering
local debounce_active = false
local debounce_duration = 0.5 -- in seconds
local original_binding = nil 

local function is_tui_active()
    return playlist_nav_tui.get_active_state()
end

local shared_keys = {}
for _, key in ipairs(playlist_nav_tui.all_local_keybinds) do
    shared_keys[key] = true
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

local bindings

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

local function activate_debounce()
	--[[ it's the brutal way to prevent primary click from double registering, 
	note by overwriting left click this way, all previous keybinds are removed  ]]
    debounce_active = true
    mp.add_forced_key_binding("MBTN_LEFT", "ignore_middle_part_click", function()
        mp.msg.info("Middle part click ignored during debounce")
    end)

    mp.add_timeout(debounce_duration, function()
        debounce_active = false
        -- Restore the original binding
        mp.remove_key_binding("ignore_middle_part_click")
		apply_bindings()
    end)
end


bindings = {
	{"MBTN_LEFT", function()
		local x, _ = mp.get_mouse_pos()
		local window_width, _ = mp.get_osd_size()
		
		if is_in_center_strip(x, window_width) then
			if debounce_active then
				mp.msg.info("Middle part click debounced: Ignored")
				return -- Ignore the click
			end
			mp.msg.info("Middle part click ignored: center strip")
			activate_debounce()
			return
		end
		mp.command("playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\"")
	end},
	{"MBTN_RIGHT", "playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"d", "playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"a", "playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"w", "playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"s", "playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"LEFT", "playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"RIGHT", "playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"UP", "playlist-next ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"DOWN", "playlist-prev ; show-text \"${playlist-pos-1}/${playlist-count}\""},
	{"PGUP", function()
		local window_width, window_height = mp.get_osd_size()
		local video_width = mp.get_property_number("width")
		local video_height = mp.get_property_number("height")
		if video_height < window_height then
			mp.command("add playlist-pos 5 ; show-text \"${playlist-pos-1}/${playlist-count}\"")
		else
			mp.command("add video-pan-y 0.05")
		end
	end},
	{"PGDWN", function()
		local window_width, window_height = mp.get_osd_size()
		local video_width = mp.get_property_number("width")
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
	{"CTRL+0", "set video-zoom 0 ; set video-pan-x 0 ; set video-pan-y 0 ; set video-rotate 0 ; show-text \"Reset Transformation\" ; set video-unscaled no"},
	{"CTRL+r", "add video-rotate +90"},
	{"CTRL+SHIFT+r", "add video-rotate -90"},
	{"SHIFT+r", "add video-rotate -90"},
	{"g", "script-message toggle_playlist_index_navigator"},
	{"9", "ignore"},
	{"/", "ignore"},
	{"0", "set video-zoom 0 ; set video-pan-x 0 ; set video-pan-y 0 ; set video-rotate 0 ; show-text \"Reset Transformation\" ; set video-unscaled no"},
	{"F", function()
		local window_width, window_height = mp.get_osd_size()
		local video_width = mp.get_property_number("width")
		local video_height = mp.get_property_number("height")
		if window_width >= video_width and window_height >= video_height then
			mp.set_property("video-unscaled", "no")
			local window_ratio	= window_width / window_height
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
			video_width = window_width /1.5 -- magical threshold, i don't know why it can't scale any larger
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
	end},
	{"t", function()
		local window_width, window_height = mp.get_osd_size()
		local video_width = mp.get_property_number("width")
		local video_height = mp.get_property_number("height")
		if window_width >= video_width and window_height >= video_height then
			mp.set_property("video-unscaled", "no")
			local window_ratio	= window_width / window_height
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
			video_width = window_width /1.5 -- magical threshold, i don't know why it can't scale any larger
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
	end},
	{"MBTN_MID", "set video-zoom 0 ; set video-pan-x 0 ; set video-pan-y 0 ; set video-rotate 0 ; show-text \"Reset Transformation\" ; set video-unscaled no"},
	{"WHEEL_LEFT","add video-pan-x 0.05"},
	{"WHEEL_RIGHT","add video-pan-x -0.05"},
	{"SPACE","ignore"},
	{"p","ignore"},
}


local function main()
    local is_image = mp.get_property_native("current-tracks/video/image")
    local is_album_art = mp.get_property_native("current-tracks/video/albumart")

	if is_image and not is_album_art then
		apply_bindings()
	else
		for _, bind in ipairs(bindings) do
			mp.remove_key_nding("custom_" .. bind[1])
		end
	end
end

mp.register_event("file-loaded", main)

local function on_tui_state_change()
    main()
end
mp.register_script_message("tui_activated", on_tui_state_change)
mp.register_script_message("tui_deactivated", on_tui_state_change)
