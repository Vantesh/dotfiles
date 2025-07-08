local M = {}

local function fail(s, ...)
	ya.err({ title = "Eza Preview", content = string.format(s, ...), timeout = 5 })
end

local function get_or_init_state(state)
	if state.initialized then
		return
	end
	state.opts = { level = 3, follow_symlinks = false, dereference = false, all = true }
	state.tree = true
	state.initialized = true
end

local apply_config = ya.sync(function(state, user_config)
	get_or_init_state(state)
	user_config = user_config or {}
	for key, value in pairs(user_config) do
		if key == "default_tree" then
			state.tree = value
		elseif state.opts[key] ~= nil then
			state.opts[key] = value
		end
	end
end)

function M:setup(user_config)
	apply_config(user_config)
end

local is_tree_view_mode = ya.sync(function(state, _)
	get_or_init_state(state)
	return state.tree
end)

local get_opts = ya.sync(function(state)
	get_or_init_state(state)
	return state.opts
end)

local toggle_view_mode = ya.sync(function(state, _)
	get_or_init_state(state)
	state.tree = not state.tree
	ya.manager_emit("refresh", {})
end)

local inc_level = ya.sync(function(state)
	get_or_init_state(state)
	state.opts.level = state.opts.level + 1
	ya.manager_emit("refresh", {})
end)

local dec_level = ya.sync(function(state)
	get_or_init_state(state)
	if state.opts.level > 1 then
		state.opts.level = state.opts.level - 1
		ya.manager_emit("refresh", {})
	end
end)

local toggle_follow_symlinks = ya.sync(function(state)
	get_or_init_state(state)
	state.opts.follow_symlinks = not state.opts.follow_symlinks
	ya.manager_emit("refresh", {})
end)

local toggle_hidden = ya.sync(function(state)
	get_or_init_state(state)
	state.opts.all = not state.opts.all
	ya.manager_emit("refresh", {})
end)

function M:entry(job)
	local args = string.gsub(job.args[1] or "", "^%s*(.-)%s*$", "%1")
	if args == "inc-level" then
		inc_level()
	elseif args == "dec-level" then
		dec_level()
	elseif args == "toggle-follow-symlinks" then
		toggle_follow_symlinks()
	elseif args == "toggle-hidden" then
		toggle_hidden()
	else
		toggle_view_mode()
	end
	ya.manager_emit("seek", { 0 })
end

function M:peek(job)
	local opts = get_opts()
	local is_tree = is_tree_view_mode()
	local args = {
		"--color=always",
		"--icons=always",
		"--group-directories-first",
		"--no-quotes",
		tostring(job.file.url),
	}
	if is_tree then
		table.insert(args, "--tree")
		table.insert(args, string.format("--level=%d", opts.level))
	end
	if opts then
		if opts.follow_symlinks then
			table.insert(args, "--follow-symlinks")
		end
		if opts.all then
			table.insert(args, "--all")
		end
		if opts.dereference then
			table.insert(args, "--dereference")
		end
	end
	local child = Command("eza"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	local limit = job.area.h
	local lines = ""
	local num_lines = 1
	local num_skip = 0
	local empty_output = false
	repeat
		local line, event = child:read_line()
		if event == 1 then
			fail(tostring(event))
		elseif event ~= 0 then
			break
		end
		if num_skip >= job.skip then
			lines = lines .. line
			num_lines = num_lines + 1
		else
			num_skip = num_skip + 1
		end
	until num_lines >= limit
	if num_lines == 1 and not is_tree_view_mode() then
		empty_output = true
	elseif num_lines == 2 and is_tree_view_mode() then
		empty_output = true
	end
	child:start_kill()
	if job.skip > 0 and num_lines < limit then
		ya.manager_emit("peek", {
			tostring(math.max(0, job.skip - (limit - num_lines))),
			only_if = tostring(job.file.url),
			upper_bound = "",
		})
	elseif empty_output then
		ya.preview_widgets(job, {
			ui.Text({ ui.Line("No items") }):area(job.area):align(ui.Text.CENTER),
		})
	else
		ya.preview_widgets(job, {
			ui.Text.parse(lines):area(job.area),
		})
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		ya.manager_emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = tostring(job.file.url),
			force = true,
		})
	end
end

return M
