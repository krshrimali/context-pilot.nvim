A = {}

A.command = "context-pilot"
A.current_title = ""

local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")

local telescope = require("telescope")
local actions = require("telescope.actions")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")

-- Load the fzy native extension
require("telescope").load_extension("fzy_native")

if not pcall(require, "telescope") then
  print("Telescope plugin not found")
  return
end

local function telescope_picker(title)
  local opts = {}
  telescope_pickers
    .new(opts, {
      -- sorting_strategy = "ascending",
      layout_strategy = "horizontal",
      layout_config = {
        preview_width = 0.6,
        preview_cutoff = 120,
      },
      -- file_ignore_patterns = { "%.git/.*", "node_modules/.*" }, -- Add any patterns you want to ignore
      cwd = vim.loop.cwd(),
      hidden = true,
      file_ignore_patterns = {},
      sorter = sorters.get_fzy_sorter(),
      -- previewer = previewers.bat.new(),
      prompt_title = "ContextGPT Output " .. title,
      finder = finders.new_table({
        results = A.autorun_data,
      }),
    })
    :find()
end

local notify_inform = function(msg, opts)
  local opt = opts or vim.log.levels.INFO
  vim.api.nvim_notify(msg, opt, {})
end

local append_data = function(_, _data)
  if #_data ~= 0 then
    for _, l in ipairs(_data) do
      -- notify_inform("Message: " .. l)
      for file_path in string.gmatch(l, "([^,]+)") do
        file_path = file_path:gsub('"', "")
        table.insert(A.autorun_data, file_path)
      end
    end
    local opts = {}
    -- notify_inform("Creating table from ..." .. A.autorun_data)
    if #A.autorun_data ~= 0 then
      telescope_picker(A.current_title)
      -- telescope_pickers
      --   .new(opts, {
      --     prompt_title = "ContextGPT",
      --     finder = finders.new_table({
      --       results = A.autorun_data,
      --     }),
      --   })
      --   :find()
    end
  end
end

function A.get_topn_contexts()
  A.autorun_data = {}
  A.current_title = "Top Files for whole file"
  notify_inform("Getting top files for " .. A.current_title)

  local current_buffer = vim.api.nvim_get_current_buf()

  -- Get the buffer name (file path)
  local buffer_name = vim.api.nvim_buf_get_name(current_buffer)

  -- Get the full path of the buffer
  local full_path = vim.fn.expand(buffer_name)
  local command = "context-pilot " .. full_path .. " -s " .. 1 .. " -e " .. 0 .. " -t file"
  -- local output_buffer = vim.api.nvim_create_buf(false, true)

  -- notify_inform("Command: " .. command)
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
  -- pickFiles(files)
end

function A.get_topn_authors()
  A.autorun_data = {}
  A.current_title = "Top Authors for whole file"
  notify_inform("Getting top authors for " .. A.current_title)
  -- vim.api.nvim_command("vnew")

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = "context-pilot " .. file_path .. " -s " .. 1 .. " -e " .. 0 .. " -t author"
  -- local output_buffer = vim.api.nvim_create_buf(false, true)
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
  -- pickFiles(files)
end

function A.get_topn_authors_range(start, end_line)
  A.autorun_data = {}
  A.current_title = "Top Authors for range (" .. start .. ", " .. end_line .. ")"
  notify_inform("Getting top authors for " .. A.current_title)
  -- notify_inform("Getting info for: " .. row .. " and end: " .. row)
  -- vim.api.nvim_command("vnew")

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = "context-pilot "
    .. file_path
    .. " -s "
    .. start
    .. " -e "
    .. end_line
    .. " -t author"
  -- local output_buffer = vim.api.nvim_create_buf(false, true)
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
  -- pickFiles(files)
end

function A.get_topn_authors_current_line()
  A.autorun_data = {}
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  A.current_title = "Top Authors for current line " .. row
  notify_inform("Getting top authors for " .. A.current_title)
  -- notify_inform("Getting info for: " .. row .. " and end: " .. row)
  -- vim.api.nvim_command("vnew")

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = "context-pilot " .. file_path .. " -s " .. row .. " -e " .. row .. " -t author"
  -- local output_buffer = vim.api.nvim_create_buf(false, true)
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
  -- pickFiles(files)
end

function A.get_topn_contexts_range(start, end_line)
  A.autorun_data = {}
  A.current_title = "Top Files for range (" .. start .. ", " .. end_line .. ")"
  notify_inform("Getting top files for " .. A.current_title)
  -- notify_inform("Getting info for: " .. row .. " and end: " .. row)
  -- vim.api.nvim_command("vnew")

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = "context-pilot "
    .. file_path
    .. " -s "
    .. start
    .. " -e "
    .. end_line
    .. " -t file"
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
end

function A.get_topn_contexts_current_line()
  A.autorun_data = {}
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  A.current_title = "Top Files for current line " .. row
  notify_inform("Getting top files for " .. A.current_title)
  -- vim.api.nvim_command("vnew")

  local file_path = vim.api.nvim_buf_get_name(0)
  local command = "context-pilot " .. file_path .. " -s " .. row .. " -e " .. row .. " -t file"
  vim.fn.jobstart(command, {
    stderr_buffered = true,
    stdout_buffered = true,
    on_stdout = append_data,
    -- on_stderr = append_data,
  })
end

return A
