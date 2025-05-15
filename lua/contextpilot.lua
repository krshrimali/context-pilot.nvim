local A = {}

A.command = "contextpilot"
A.current_title = ""
A.autorun_data = {}
A.desc_picker = {}

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

local spinner_timer

local function start_spinner_minimal(msg)
  spinner_index = 1
  spinner_timer = vim.loop.new_timer()
  spinner_timer:start(
    0,
    120,
    vim.schedule_wrap(function()
      local spinner = spinner_frames[spinner_index]
      spinner_index = (spinner_index % #spinner_frames) + 1
      vim.api.nvim_echo({ { spinner .. " " .. msg, "None" } }, false, {})
    end)
  )
end

local function stop_spinner_minimal(final_msg)
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  vim.api.nvim_echo({ { final_msg, "None" } }, false, {})
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
    local extracted_path = line:match("^Extracted details for file:%s+(.-)$")
    if extracted_path then table.insert(extracted_files, extracted_path) end
    local file_path, count = line:match("^(.-)%s+%-+%s+(%d+)%s+occurrences$")
    if file_path and count then
      table.insert(A.autorun_data, { path = file_path, count = tonumber(count) })
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

  local command = build_command(file_path, folder_path, start, end_, mode)

  if mode == "query" then
    start_spinner_minimal("Processing query...")
  else
    start_spinner()
  end

  vim.fn.jobstart(command, {
    stdout_buffered = false,
    stderr_buffered = true,
    pty = false,
    on_stdout = append_data,
    on_exit = function(_, exit_code)
      if mode == "query" then
        stop_spinner_minimal("✅ Query complete!")
      else
        stop_spinner()
      end

      if exit_code ~= 0 then
        notify_inform("Error: Command exited with code " .. exit_code, vim.log.levels.ERROR)
      elseif #A.autorun_data > 0 and mode ~= "index" then
        -- Sort by count ascending (most occurrences at bottom)
        table.sort(A.autorun_data, function(a, b)
          return a.count > b.count
        end)

        -- Convert back to display strings
        for i, entry in ipairs(A.autorun_data) do
          A.autorun_data[i] = string.format("%s (%d occurrences)", entry.path, entry.count)
        end

        telescope_picker(A.current_title)
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

local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local json = vim.json

-- Use vim.json or vim.fn.json_decode for parsing (Neovim ≥0.7)
local function append_desc_data(_, data)
  if not data then return end
  local raw = table.concat(data, "\n")
  if not raw or raw:match("^%s*$") then return end

  local ok, parsed = pcall(vim.json.decode, raw)
  if ok and type(parsed) == "table" then
    A.desc_data = parsed
  else
    vim.api.nvim_notify("Failed to parse contextpilot desc JSON output", vim.log.levels.ERROR, {})
  end
end


local function telescope_desc_picker(title)
  telescope_pickers.new({}, {
    prompt_title = "ContextPilot Descriptions: " .. title,
    finder = finders.new_table({
      results = A.desc_data,
      entry_maker = function(entry)
        return {
          value = entry,     -- {commit_title, commit_desc}
          ordinal = entry[1],
          display = entry[1],
          desc = entry[2],
        }
      end,
    }),
    sorter = sorters.get_fzy_sorter(),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local desc = entry.desc or ""
        local lines = {}
        for line in tostring(desc):gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- you can extend what happens on <CR>
      end)
      return true
    end,
  })
  :find()
end

function A.query_descriptions_for_range(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  local folder_path = vim.loop.cwd()
  local title = string.format("Descriptions (%d-%d)", start_line, end_line)
  A.desc_data = {}

  -- Note: format according to your contextpilot usage
  local command = string.format(
    "%s %s -t desc %s -s %d -e %d",
    A.command,
    folder_path,
    file_path,
    start_line,
    end_line
  )

  start_spinner_minimal("Processing descriptions...")
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = append_desc_data,
    on_exit = function(_, exit_code)
      stop_spinner_minimal("✅ Descriptions retrieved.")
      if exit_code ~= 0 then
        notify_inform("Error: Command exited with code " .. exit_code, vim.log.levels.ERROR)
      elseif #A.desc_data > 0 then
        telescope_desc_picker(title)
      else
        notify_inform("No descriptions found.", vim.log.levels.WARN)
      end
    end,
  })
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


vim.api.nvim_create_user_command(
  "ContextPilotDescRange",
  function(opts)
    local start_line = tonumber(opts.line1)
    local end_line = tonumber(opts.line2)
    A.query_descriptions_for_range(start_line, end_line)
  end,
  { range = true }
)

return A
