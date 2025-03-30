local A = {}

A.command = "context-pilot"
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

-- Telescope Picker
local function telescope_picker(title)
  telescope_pickers
    .new({}, {
      layout_strategy = "horizontal",
      layout_config = { preview_width = 0.6, preview_cutoff = 120 },
      sorter = sorters.get_fzy_sorter(),
      prompt_title = "ContextGPT Output: " .. title,
      finder = finders.new_table({ results = A.autorun_data }),
    })
    :find()
end

-- Output collector
local append_data = function(_, _data)
  if #_data == 0 then return end
  for _, line in ipairs(_data) do
    for file_path in string.gmatch(line, "([^,]+)") do
      file_path = file_path:gsub('"', ""):gsub("\n", "")
      if file_path:len() > 0 then table.insert(A.autorun_data, file_path) end
    end
  end
  if #A.autorun_data > 0 then telescope_picker(A.current_title) end
end

-- Build CLI command
local function build_command(file_path, folder_path, start, end_, mode)
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
  vim.notify("Running: " .. command, vim.log.levels.INFO)

  vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = append_data,
  })
end

-- ==== PUBLIC CALLABLE FUNCTIONS ====

function A.get_topn_contexts()
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  execute_context_pilot(file_path, folder_path, 1, 0, "file", "Top Files for whole file")
end

function A.get_topn_authors()
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  execute_context_pilot(file_path, folder_path, 1, 0, "author", "Top Authors for whole file")
end

function A.get_topn_contexts_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Top Files for range (%d, %d)", start_line, end_line)
  execute_context_pilot(file_path, folder_path, start_line, end_line, "file", title)
end

function A.get_topn_authors_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Top Authors for range (%d, %d)", start_line, end_line)
  execute_context_pilot(file_path, folder_path, start_line, end_line, "author", title)
end

function A.get_topn_authors_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = "Top Authors for current line " .. row
  execute_context_pilot(file_path, folder_path, row, row, "author", title)
end

function A.get_topn_contexts_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = "Top Files for current line " .. row
  execute_context_pilot(file_path, folder_path, row, row, "file", title)
end

function A.query_context_for_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Queried Contexts (%d-%d)", start_line, end_line)
  execute_context_pilot(file_path, folder_path, start_line, end_line, "query", title)
end

return A
