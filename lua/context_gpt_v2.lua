local A = {}

A.command = "context_pilot"
A.current_title = ""
A.autorun_data = {}

local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

if not pcall(require, "telescope") then
  print("Telescope plugin not found")
  return
end
require("telescope").load_extension("fzy_native")

local notify_inform = function(msg, level)
  vim.api.nvim_notify(msg, level or vim.log.levels.INFO, {})
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- Spinner UI state
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local progress_win, progress_buf, progress_timer
local extracted_files = {}

local function create_floating_window()
  progress_buf = vim.api.nvim_create_buf(false, true)
  local win_opts = {
    relative = "editor",
    width = 60,
    height = 6,
    col = vim.o.columns - 62,
    row = vim.o.lines - 6,
    style = "minimal",
    border = "rounded",
  }
  progress_win = vim.api.nvim_open_win(progress_buf, true, win_opts)
end

local function update_floating_window(text)
  if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
    vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {
      "📦 Indexing Workspace...",
      "",
      text or "",
      "",
      "Press <ESC> to close this message",
    })
  end
end

local function start_spinner()
  spinner_index = 1
  extracted_files = {}
  create_floating_window()
  progress_timer = vim.loop.new_timer()
  progress_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
        local spinner = spinner_frames[spinner_index]
        spinner_index = (spinner_index % #spinner_frames) + 1
        update_floating_window(spinner .. " Files indexed: " .. tostring(#extracted_files))
      end
    end)
  )
end

local function stop_spinner()
  if progress_timer then
    progress_timer:stop()
    progress_timer:close()
    progress_timer = nil
  end
  update_floating_window("✅ Indexing complete! Total files: " .. tostring(#extracted_files))
  vim.defer_fn(function()
    if progress_win and vim.api.nvim_win_is_valid(progress_win) then
      vim.api.nvim_win_close(progress_win, true)
    end
  end, 2000)
end

local function telescope_picker(title)
  telescope_pickers
    .new({}, {
      prompt_title = "ContextPilot Output: " .. title,
      sorter = sorters.get_fzy_sorter(),
      finder = finders.new_table({
        results = A.autorun_data,
        entry_maker = function(entry)
          local filepath, count = entry:match("^(.-)%s+%((%d+)%s+occurrences%)$")
          if not filepath then
            filepath = entry
            count = "0"
          end
          return {
            value = entry,
            ordinal = filepath,
            display = string.format("%-60s %s occurrences", filepath, count),
            path = filepath,
          }
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.path then
            vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
          else
            vim.api.nvim_notify("No path to open", vim.log.levels.WARN, {})
          end
        end)
        return true
      end,
    })
    :find()
end

local function append_data(_, data)
  if not data then return end
  for _, line in ipairs(data) do
    line = line:gsub("\r", "")
    local file_path, count = line:match("^(.-)%s+%-+%s+(%d+)%s+occurrences$")
    if file_path and count then
      table.insert(A.autorun_data, string.format("%s (%s occurrences)", file_path, count))
    end
  end
end

local function build_command(file_path, folder_path, start, end_, mode)
  if mode == "index" then return string.format("%s %s -t %s", A.command, folder_path, mode) end
  return string.format(
    "%s %s -t %s %s -s %d -e %d",
    A.command,
    folder_path,
    mode,
    file_path,
    start,
    end_
  )
end

local function execute_context_pilot(file_path, folder_path, start, end_, mode, title)
  A.autorun_data = {}
  A.current_title = title
  notify_inform("Fetching: " .. title)

  local command = build_command(file_path, folder_path, start, end_, mode)
  notify_inform("Command: " .. command)

  start_spinner()

  vim.fn.jobstart(command, {
    stdout_buffered = true, -- <-- BUFFERED MUST BE TRUE
    stderr_buffered = true,
    pty = false, -- recommended false to avoid terminal issues
    on_stdout = append_data, -- Accumulate only
    on_exit = function(_, exit_code)
      stop_spinner()
      if exit_code ~= 0 then
        notify_inform("Error: Command exited with code " .. exit_code, vim.log.levels.ERROR)
      else
        -- Call Telescope exactly once after completion
        if #A.autorun_data > 0 and A.current_title ~= "Start Indexing your Workspace" then
          telescope_picker(A.current_title)
        end
      end
    end,
  })
end

function A.get_topn_contexts()
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  execute_context_pilot(file_path, folder_path, 1, 0, "query", "Top Files for whole file")
end

function A.get_topn_contexts_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Top Files for range (%d, %d)", start_line, end_line)
  execute_context_pilot(file_path, folder_path, start_line, end_line, "query", title)
end

function A.get_topn_contexts_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = "Top Files for current line " .. row
  execute_context_pilot(file_path, folder_path, row, row, "query", title)
end

function A.query_context_for_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Queried Contexts (%d-%d)", start_line, end_line)
  execute_context_pilot(file_path, folder_path, start_line, end_line, "query", title)
end

function A.start_indexing()
  local folder_path = vim.loop.cwd()
  execute_context_pilot("", folder_path, 0, 0, "index", "Start Indexing your Workspace")
end

vim.api.nvim_create_user_command("ContextPilotContexts", function() A.get_topn_contexts() end, {})

vim.api.nvim_create_user_command(
  "ContextPilotContextsCurrentLine",
  function() A.get_topn_contexts_current_line() end,
  {}
)

vim.api.nvim_create_user_command("ContextPilotStartIndexing", function() A.start_indexing() end, {})

vim.api.nvim_create_user_command("ContextPilotQueryRange", function(opts)
  local start_line = tonumber(opts.line1)
  local end_line = tonumber(opts.line2)
  A.query_context_for_range(start_line, end_line)
end, { range = true })

return A
