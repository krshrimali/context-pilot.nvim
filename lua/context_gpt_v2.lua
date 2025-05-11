local A = {}

A.command = "context_pilot"
A.current_title = ""
A.autorun_data = {}

local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

-- Load the fzy native extension
if not pcall(require, "telescope") then
  print("Telescope plugin not found")
  return
end
require("telescope").load_extension("fzy_native")

-- Notify wrapper
local notify_inform = function(msg, level)
  vim.api.nvim_notify(msg, level or vim.log.levels.INFO, {})
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local function telescope_picker(title)
  telescope_pickers
    .new({}, {
      prompt_title = "ContextPilot Output: " .. title,
      sorter = sorters.get_fzy_sorter(),
      finder = finders.new_table({
        results = A.autorun_data,
        entry_maker = function(entry)
          -- Defensive parsing
          local filepath, count = entry:match("^(.-)%s+%((%d+)%s+occurrences%)$")
          if not filepath then
            filepath = entry -- fallback to whole line
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

-- Output collector
local append_data = function(_, _data)
  if #_data == 0 then return end

  for _, line in ipairs(_data) do
    line = line:gsub("\r", "")
    -- Skip if empty
    if line:match("^%s*$") then goto continue end

    -- Expecting format: path - count occurrences
    local file_path, count = line:match("^(.-)%s+%-+%s+(%d+)%s+occurrences$")

    if file_path and count then
      table.insert(A.autorun_data, string.format("%s (%s occurrences)", file_path, count))
    else
      -- Fallback if it's not in that format (e.g., first line of output, maybe just the filename)
      table.insert(A.autorun_data, line)
    end
    ::continue::
  end
  -- print a message

  if #A.autorun_data > 0 then telescope_picker(A.current_title) end
end

-- Build CLI command
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

-- General purpose executor
local function execute_context_pilot(file_path, folder_path, start, end_, mode, title)
  A.autorun_data = {}
  A.current_title = title
  notify_inform("Fetching: " .. title)

  local command = build_command(file_path, folder_path, start, end_, mode)
  notify_inform("Command: " .. command)

  vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    pty = true,
    on_stdout = append_data,
  })
end

-- ==== PUBLIC CALLABLE FUNCTIONS ====

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

return A
