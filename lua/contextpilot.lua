-- Main module table that will be returned at the end of the file
local A = {}

-- The command name for the external contextpilot binary
A.command = "contextpilot"
-- Stores the current operation title for display purposes
A.current_title = ""
-- Table to store parsed results from contextpilot command execution
A.autorun_data = {}
-- Table to store description/commit data from contextpilot desc queries
A.desc_picker = {}

-- Import required telescope modules for creating interactive pickers
local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

-- Check if telescope is available, exit early if not found
if not pcall(require, "telescope") then
    print("Telescope plugin not found")
    return
end
-- Load the fzy_native extension for better fuzzy searching
require("telescope").load_extension("fzy_native")

-- Import the diffs module
local diffs = require('contextpilot.diffs')

-- Helper function to display notifications to the user
local notify_inform = function(msg, level)
    -- Use vim's built-in notification system with default INFO level
    vim.api.nvim_notify(msg, level or vim.log.levels.INFO, {})
end

-- Minimum required version of contextpilot binary for compatibility
local MIN_CONTEXTPILOT_VERSION = "0.9.0"

-- Parse a semantic version string (e.g., "1.2.3") into individual numeric components
local function parse_version(version_str)
    -- Use pattern matching to extract major, minor, and patch numbers
    local major, minor, patch = version_str:match("(%d+)%.(%d+)%.(%d+)")
    -- Convert string matches to numbers for comparison
    return tonumber(major), tonumber(minor), tonumber(patch)
end

-- Compare two semantic versions to check if installed version meets requirements
local function is_version_compatible(installed, required)
    -- Parse both version strings into numeric components
    local imaj, imin, ipat = parse_version(installed)
    local rmaj, rmin, rpat = parse_version(required)
    -- Compare major version first (must be greater or equal)
    if imaj ~= rmaj then return imaj > rmaj end
    -- If major versions match, compare minor version
    if imin ~= rmin then return imin > rmin end
    -- If major and minor match, patch version must be greater or equal
    return ipat >= rpat
end

-- Verify that the contextpilot binary is installed and meets minimum version requirements
local function check_contextpilot_version()
    -- Ensure a readable message is displayed if contextpilot is not installed and the
    -- minimum version is not met. (See `MIN_CONTEXTPILOT_VERSION` above.)
    -- Execute contextpilot --version command and capture output
    local output = vim.fn.system(A.command .. " --version")
    -- Check if command failed or produced no output
    if vim.v.shell_error ~= 0 or not output or output == "" then
        notify_inform("❌ Unable to determine contextpilot version.", vim.log.levels.ERROR)
        return false
    end

    -- Extract version number from command output using pattern matching
    local version = output:match("contextpilot%s+(%d+%.%d+%.%d+)")
    if not version then
        notify_inform("⚠️ Unexpected version output: " .. output, vim.log.levels.ERROR)
        return false
    end

    -- Check if the installed version meets our minimum requirements
    if not is_version_compatible(version, MIN_CONTEXTPILOT_VERSION) then
        notify_inform(
            string.format(
                "⚠️ Your contextpilot version is %s. Please update to at least %s.",
                version,
                MIN_CONTEXTPILOT_VERSION
            ),
            vim.log.levels.WARN
        )
        return false
    end

    -- Version check passed
    return true
end

-- Import telescope action modules for handling user interactions
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- Spinner UI state variables
-- Array of Unicode Braille characters that create a spinning animation effect
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
-- Current frame index in the spinner animation (1-based)
local spinner_index = 1
-- Variables to track floating window components: window handle, buffer handle, timer
local progress_win, progress_buf, progress_timer
-- List to store file paths that have been processed during indexing
local extracted_files = {}

-- Create a floating window for displaying indexing progress
local function create_floating_window()
    -- Create a new buffer that is not listed and will be deleted when window closes
    progress_buf = vim.api.nvim_create_buf(false, true)
    -- Configure window options for the floating window
    local win_opts = {
        relative = "editor", -- Position relative to the editor
        width = 60, -- Window width in columns
        height = 6, -- Window height in rows
        col = vim.o.columns - 62, -- Position 62 columns from the right edge
        row = vim.o.lines - 6, -- Position 6 rows from the bottom
        style = "minimal", -- Remove UI elements like line numbers
        border = "rounded", -- Use rounded border style
    }
    -- Create and open the floating window with the specified buffer and options
    progress_win = vim.api.nvim_open_win(progress_buf, true, win_opts)
end

-- Update the content of the floating progress window
local function update_floating_window(text)
    -- Check if buffer exists and is still valid before updating
    if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
        -- Set the complete content of the buffer with progress information
        vim.api.nvim_buf_set_lines(progress_buf, 0, -1, false, {
            "📦 Indexing Workspace...", -- Header with package emoji
            "", -- Empty line for spacing
            text or "", -- Dynamic text (spinner + status) or empty string
            "", -- Empty line for spacing
            "Press <ESC> to close this message", -- User instruction
        })
    end
end

-- Timer variable for the minimal spinner animation
local spinner_timer

-- Start a minimal spinner animation in the command line area
local function start_spinner_minimal(msg)
    -- Reset the spinner frame to the first frame.
    spinner_index = 1
    -- Create a new libuv timer object for animation:
    spinner_timer = vim.loop.new_timer()
    -- Start the timer with specified intervals and callback
    spinner_timer:start(
        0, -- start immediately (no initial delay)
        120, -- repeat every 120ms for smooth animation
        -- Run this function on each tick:
        vim.schedule_wrap(function()
            -- Get the current spinner character from the frames array
            local spinner = spinner_frames[spinner_index]
            -- Advance to next frame, wrapping back to 1 after the last frame
            spinner_index = (spinner_index % #spinner_frames) + 1
            -- Display spinner character and message in Neovim's command line
            vim.api.nvim_echo({ { spinner .. " " .. msg, "None" } }, false, {})
        end)
    )
end

-- Stop the minimal spinner animation and display a final message
local function stop_spinner_minimal(final_msg)
    -- Check if timer exists before trying to stop it
    if spinner_timer then
        -- Stop the timer from firing additional callbacks
        spinner_timer:stop()
        -- Close and cleanup the timer resources
        spinner_timer:close()
        -- Clear the timer reference
        spinner_timer = nil
    end
    -- Display the final message in the command line, replacing the spinner
    vim.api.nvim_echo({ { final_msg, "None" } }, false, {})
end

-- Start the full-featured spinner with floating window for indexing operations
local function start_spinner()
    -- Reset spinner animation to first frame
    spinner_index = 1
    -- Clear the list of extracted files from previous operations
    extracted_files = {}
    -- Create and display the floating progress window
    create_floating_window()
    -- Create a new timer for the floating window spinner animation
    progress_timer = vim.loop.new_timer()
    -- Start the timer with faster update interval than minimal spinner
    progress_timer:start(
        0, -- start immediately
        100, -- update every 100ms for smoother animation
        vim.schedule_wrap(function()
            -- Only update if the progress buffer is still valid
            if progress_buf and vim.api.nvim_buf_is_valid(progress_buf) then
                -- Get current spinner frame
                local spinner = spinner_frames[spinner_index]
                -- Advance to next frame
                spinner_index = (spinner_index % #spinner_frames) + 1
                -- Update floating window with spinner and file count
                update_floating_window(spinner .. " Files indexed: " .. tostring(#extracted_files))
            end
        end)
    )
end

-- Stop the floating window spinner and show completion message
local function stop_spinner()
    -- Stop and cleanup the progress timer if it exists
    if progress_timer then
        progress_timer:stop()
        progress_timer:close()
        progress_timer = nil
    end
    -- Update the floating window with completion message and final file count
    update_floating_window("✅ Indexing complete! Total files: " .. tostring(#extracted_files))
    -- Schedule the floating window to close after 2 seconds
    vim.defer_fn(function()
        -- Check if window is still valid before attempting to close
        if progress_win and vim.api.nvim_win_is_valid(progress_win) then
            -- Close the floating window and force close even if modified
            vim.api.nvim_win_close(progress_win, true)
        end
    end, 2000) -- 2000ms = 2 seconds delay
end

-- Create a telescope picker to display and select from contextpilot query results
local function telescope_picker(title)
    -- Create a new telescope picker instance
    telescope_pickers
        .new({}, {
            -- Set the title displayed at the top of the picker
            prompt_title = "ContextPilot Output: " .. title,
            -- Use fuzzy sorter for filtering results as user types
            sorter = sorters.get_fzy_sorter(),
            -- Configure the finder to process our results data
            finder = finders.new_table({
                -- Use the autorun_data table populated by contextpilot command
                results = A.autorun_data,
                -- Function to transform each result into a telescope entry
                entry_maker = function(entry)
                    -- Parse the entry string to extract filepath and occurrence count
                    local filepath, count = entry:match("^(.-)%s+%((%d+)%s+occurrences%)$")
                    -- If parsing fails, use the entire entry as filepath with 0 occurrences
                    if not filepath then
                        filepath = entry
                        count = "0"
                    end
                    -- Return telescope entry structure
                    return {
                        value = entry, -- Original entry string
                        ordinal = filepath, -- String used for fuzzy matching
                        display = string.format("%-60s %s occurrences", filepath, count), -- Display format
                        path = filepath, -- File path for opening
                    }
                end,
            }),
            -- Configure key mappings for the picker
            attach_mappings = function(prompt_bufnr, _)
                -- Replace the default <Enter> action
                actions.select_default:replace(function()
                    -- Close the picker
                    actions.close(prompt_bufnr)
                    -- Get the currently selected entry
                    local selection = action_state.get_selected_entry()
                    -- Open the selected file if it has a valid path
                    if selection and selection.path then
                        -- Use fnameescape to handle filenames with special characters
                        vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
                    else
                        vim.api.nvim_notify("No path to open", vim.log.levels.WARN, {})
                    end
                end)
                -- Return true to indicate mappings were successfully attached
                return true
            end,
        })
        -- Start the picker and display it to the user
        :find()
end

-- Process stdout data from contextpilot command and extract relevant information
local function append_data(_, data)
    -- Exit early if no data received
    if not data then return end
    -- Process each line of output from the contextpilot command
    for _, line in ipairs(data) do
        -- Remove carriage return characters for consistent line endings
        line = line:gsub("\r", "")
        -- Look for lines indicating file extraction (for indexing progress)
        local extracted_path = line:match("^Extracted details for file:%s+(.-)$")
        if extracted_path then table.insert(extracted_files, extracted_path) end
        -- Look for lines with occurrence counts (for query results)
        local file_path, count = line:match("^(.-)%s+%-+%s+(%d+)%s+occurrences$")
        if file_path and count then
            -- Store the file path and occurrence count as a structured entry
            table.insert(A.autorun_data, { path = file_path, count = tonumber(count) })
        end
    end
end

-- Build the contextpilot command string based on operation mode and parameters
local function build_command(file_path, folder_path, start, end_, mode)
    -- For index mode, only specify the folder path and mode (no file-specific parameters)
    if mode == "index" then return string.format("%s %s -t %s", A.command, folder_path, mode) end
    -- For other modes (query, desc), include file path and line range parameters
    return string.format(
        "%s %s -t %s %s -s %d -e %d", -- contextpilot folder -t mode file -s start -e end
        A.command, -- The contextpilot binary name
        folder_path, -- Working directory path
        mode, -- Operation mode (query, desc, etc.)
        file_path, -- Target file path
        start, -- Starting line number
        end_ -- Ending line number (end_ to avoid Lua keyword conflict)
    )
end

-- Execute a contextpilot command with specified parameters and handle the results
local function execute_context_pilot(file_path, folder_path, start, end_, mode, title)
    -- Clear previous results and set the current operation title
    A.autorun_data = {}
    A.current_title = title

    -- Build the command string using provided parameters
    local command = build_command(file_path, folder_path, start, end_, mode)

    -- Choose appropriate spinner based on operation mode
    if mode == "query" then
        -- If the mode is "query", we use a minimal spinner for faster operations
        start_spinner_minimal("Processing query...")
    else
        -- For other modes (like indexing), use the full floating window spinner
        start_spinner()
    end

    -- Start the contextpilot command as an asynchronous job
    vim.fn.jobstart(command, {
        stdout_buffered = false, -- Process output line by line as it comes
        stderr_buffered = true, -- Buffer stderr for error handling
        pty = false, -- Don't allocate a pseudo-terminal
        on_stdout = append_data, -- Process each line of stdout
        on_exit = function(_, exit_code)
            -- Stop the appropriate spinner based on mode
            if mode == "query" then
                stop_spinner_minimal("✅ Query complete!")
            else
                stop_spinner()
            end

            -- Handle command execution results
            if exit_code ~= 0 then
                -- Command failed, show error message
                notify_inform("Error: Command exited with code " .. exit_code, vim.log.levels.ERROR)
            elseif #A.autorun_data > 0 and mode ~= "index" then
                -- Command succeeded and returned results (not for index mode)
                -- Sort by occurrence count in descending order (most relevant first)
                table.sort(A.autorun_data, function(a, b) return a.count > b.count end)

                -- Convert structured data back to display strings for telescope
                for i, entry in ipairs(A.autorun_data) do
                    A.autorun_data[i] = string.format("%s (%d occurrences)", entry.path, entry.count)
                end

                -- Show results in telescope picker
                telescope_picker(A.current_title)
            end
        end,
    })
end

-- Public API: Get the most relevant files for the entire current file
function A.get_topn_contexts()
    -- Ensure contextpilot binary is available and compatible
    if not check_contextpilot_version() then return end
    -- Get the current file path and working directory and do some validations:
    local file_path = vim.api.nvim_buf_get_name(0) -- Path of currently open buffer
    local folder_path = vim.loop.cwd() -- Current working directory
    -- Just some extra precautions.
    if file_path == "" then
        notify_inform("No file is currently open.", vim.log.levels.WARN)
        return
    end
    if not vim.fn.filereadable(file_path) then
        notify_inform("File does not exist: " .. file_path, vim.log.levels.ERROR)
        return
    end
    -- Execute contextpilot query for the entire file (line 1 to 0 means whole file)
    execute_context_pilot(file_path, folder_path, 1, 0, "query", "Top Files for whole file")
end

-- Public API: Get the most relevant files for a specific line range in the current file
function A.get_topn_contexts_range(start_line, end_line)
    -- Ensure contextpilot binary is available and compatible
    if not check_contextpilot_version() then return end
    -- Get current file and directory paths
    local file_path = vim.api.nvim_buf_get_name(0)
    local folder_path = vim.loop.cwd()
    -- Create descriptive title for the operation
    local title = string.format("Top Files for range (%d, %d)", start_line, end_line)
    -- Execute contextpilot query for the specified line range
    execute_context_pilot(file_path, folder_path, start_line, end_line, "query", title)
end

-- Public API: Get the most relevant files for the current cursor line
function A.get_topn_contexts_current_line()
    -- Ensure contextpilot binary is available and compatible
    if not check_contextpilot_version() then return end
    -- Get the current cursor line number (1-based)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    -- Get current file and directory paths
    local file_path = vim.api.nvim_buf_get_name(0)
    local folder_path = vim.loop.cwd()
    -- Create descriptive title for the operation
    local title = "Top Files for current line " .. row
    -- Execute contextpilot query for just the current line
    execute_context_pilot(file_path, folder_path, row, row, "query", title)
end

-- Public API: Query contextual information for a specific line range
function A.query_context_for_range(start_line, end_line)
    -- Ensure contextpilot binary is available and compatible
    if not check_contextpilot_version() then return end
    -- Get current file and directory paths
    local file_path = vim.api.nvim_buf_get_name(0)
    local folder_path = vim.loop.cwd()
    -- Create descriptive title for the operation
    local title = string.format("Queried Contexts (%d-%d)", start_line, end_line)
    -- Execute contextpilot query for the specified line range
    execute_context_pilot(file_path, folder_path, start_line, end_line, "query", title)
end

-- Public API: Start indexing the entire workspace
function A.start_indexing()
    -- Ensure contextpilot binary is available and compatible
    if not check_contextpilot_version() then return end
    -- Get current working directory to index
    local folder_path = vim.loop.cwd()
    -- Execute contextpilot indexing (empty file_path and 0,0 range for whole workspace)
    execute_context_pilot("", folder_path, 0, 0, "index", "Start Indexing your Workspace")
end

-- Additional telescope imports for description functionality
local telescope_pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
-- JSON parsing functionality for description data
local json = vim.json

-- Process JSON output from contextpilot desc command for commit descriptions
local function append_desc_data(_, data)
    -- Exit early if no data received
    if not data then return end
    -- Concatenate all data lines into a single string
    local raw = table.concat(data, "\n")
    -- Skip processing if the result is empty or contains only whitespace
    if not raw or raw:match("^%s*$") then return end

    -- Attempt to parse the JSON output from contextpilot
    local ok, parsed = pcall(vim.json.decode, raw)
    if ok and type(parsed) == "table" then
        -- Store the parsed description data for use in telescope picker
        A.desc_data = parsed
    else
        -- Notify user if JSON parsing failed
        vim.api.nvim_notify("Failed to parse contextpilot desc JSON output", vim.log.levels.ERROR, {})
    end
end

-- Parse a date string into a Unix timestamp for sorting purposes
local function parse_date_str(date_str)
    -- Assumes format like: "Fri May 17 15:44:01 2024"
    -- Pattern to extract: (weekday) (month) (day) (hour):(minute):(second) (year)
    local pattern = "(%a+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)%s+(%d+)"
    local _, _, _, month_str, day, hour, min, sec, year = date_str:find(pattern)

    -- Return 0 if parsing failed (will sort to beginning)
    if not year then return 0 end

    -- Map month abbreviations to numeric values
    local month_map = {
        Jan = 1, Feb = 2, Mar = 3, Apr = 4,
        May = 5, Jun = 6, Jul = 7, Aug = 8,
        Sep = 9, Oct = 10, Nov = 11, Dec = 12,
    }
    -- Get numeric month, defaulting to 1 if not found
    local month = month_map[month_str] or 1

    -- Convert to Unix timestamp using os.time
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
    }) or 0 -- Return 0 if os.time fails
end

local function telescope_desc_picker(title)
    if not A.desc_data or #A.desc_data == 0 then
        vim.api.nvim_notify("No commit descriptions found", vim.log.levels.WARN, {})
        return
    end

    -- Sort by date (most recent first)
    table.sort(A.desc_data, function(a, b)
        local date_a = parse_date_str(a[5] or "")
        local date_b = parse_date_str(b[5] or "")
        return date_a > date_b
    end)

    telescope_pickers
        .new({}, {
            prompt_title = "ContextPilot Commit Descriptions: " .. title,
            sorter = sorters.get_fzy_sorter(),
            finder = finders.new_table({
                results = A.desc_data,
                entry_maker = function(entry)
                    local title, description, author, date, hash = unpack(entry)
                    local commit_hash = hash:match(".*/(.+)$") or hash
                    local short_hash = commit_hash:sub(1, 8)
                    local display_line = string.format("[%s] %s (%s)", short_hash, title, author)
                    return {
                        value = entry,
                        ordinal = title .. " " .. author .. " " .. description,
                        display = display_line,
                        commit_hash = commit_hash,
                        title = title,
                        description = description,
                        author = author,
                        date = date,
                    }
                end,
            }),
            previewer = previewers.new_buffer_previewer({
                title = "Commit Details",
                define_preview = function(self, entry, status)
                    local lines = {
                        "Commit: " .. entry.commit_hash,
                        "Title: " .. entry.title,
                        "Author: " .. entry.author,
                        "Date: " .. entry.date,
                        "",
                        "Description:",
                        entry.description,
                    }
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                end,
            }),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection then
                        local lines = {
                            "# Commit Details",
                            "",
                            "**Commit:** " .. selection.commit_hash,
                            "**Title:** " .. selection.title,
                            "**Author:** " .. selection.author,
                            "**Date:** " .. selection.date,
                            "",
                            "## Description",
                            "",
                            selection.description,
                        }

                        local buf = vim.api.nvim_create_buf(false, true)
                        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                        vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
                        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
                        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

                        vim.cmd("split")
                        local win = vim.api.nvim_get_current_win()
                        vim.api.nvim_win_set_buf(win, buf)
                    end
                end)
                return true
            end,
        })
        :find()
end

function A.query_descriptions_for_range(start_line, end_line)
    if not check_contextpilot_version() then return end
    local file_path = vim.api.nvim_buf_get_name(0)
    local folder_path = vim.loop.cwd()
    local title = string.format("Commit Descriptions (%d-%d)", start_line, end_line)

    A.desc_data = {}
    local command = string.format(
        "%s %s -t desc %s -s %d -e %d",
        A.command,
        folder_path,
        file_path,
        start_line,
        end_line
    )

    start_spinner_minimal("Getting commit descriptions...")

    vim.fn.jobstart(command, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = append_desc_data,
        on_exit = function(_, exit_code)
            stop_spinner_minimal("✅ Descriptions loaded!")
            if exit_code ~= 0 then
                notify_inform("Error: Command exited with code " .. exit_code, vim.log.levels.ERROR)
            else
                telescope_desc_picker(title)
            end
        end,
    })
end

function A.start_indexing_subdirectory()
    if not check_contextpilot_version() then return end
    local folder_path = vim.loop.cwd()

    -- Get list of subdirectories
    local subdirs = {}
    local handle = vim.loop.fs_scandir(folder_path)
    if handle then
        while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then break end
            if type == "directory" and name ~= ".git" and not name:match("^%.") then
                table.insert(subdirs, name)
            end
        end
    end

    if #subdirs == 0 then
        notify_inform("No subdirectories found to index", vim.log.levels.WARN)
        return
    end

    -- Create telescope picker for subdirectory selection
    telescope_pickers
        .new({}, {
            prompt_title = "Select Subdirectories to Index (Tab to select, Enter to confirm)",
            finder = finders.new_table({
                results = subdirs,
            }),
            sorter = sorters.get_fzy_sorter(),
            attach_mappings = function(prompt_bufnr, map)
                local selections = {}

                -- Tab to toggle selection
                map("i", "<Tab>", function()
                    local current_picker = action_state.get_current_picker(prompt_bufnr)
                    local entry = action_state.get_selected_entry()
                    if entry then
                        local value = entry.value
                        if selections[value] then
                            selections[value] = nil -- Deselect
                        else
                            selections[value] = true -- Select
                        end
                        -- Update display to show selection
                        current_picker:refresh()
                    end
                end)

                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selected_dirs = {}
                    for dir, _ in pairs(selections) do
                        table.insert(selected_dirs, dir)
                    end

                    if #selected_dirs == 0 then
                        notify_inform("No subdirectories selected", vim.log.levels.WARN)
                        return
                    end

                    local dirs_str = table.concat(selected_dirs, ",")
                    local command = string.format("%s %s -t index %s", A.command, folder_path, dirs_str)

                    start_spinner()
                    vim.fn.jobstart(command, {
                        stdout_buffered = false,
                        stderr_buffered = true,
                        on_stdout = append_data,
                        on_exit = function(_, exit_code)
                            stop_spinner()
                            if exit_code ~= 0 then
                                notify_inform("Error: Indexing failed with code " .. exit_code, vim.log.levels.ERROR)
                            else
                                notify_inform("✅ Subdirectory indexing complete!", vim.log.levels.INFO)
                            end
                        end,
                    })
                end)

                return true
            end,
        })
        :find()
end

-- Register Neovim user commands to expose plugin functionality

-- Command to find relevant files for the entire current file
vim.api.nvim_create_user_command(
    "ContextPilotRelevantFilesWholeFile",
    function() A.get_topn_contexts() end,
    {}
)

-- Command to start indexing the entire workspace
vim.api.nvim_create_user_command("ContextPilotStartIndexing", function() A.start_indexing() end, {})

-- Command to find relevant files for a selected range (works with visual selection)
vim.api.nvim_create_user_command("ContextPilotRelevantFilesRange", function(opts)
    -- Extract line numbers from the range selection
    local start_line = tonumber(opts.line1)
    local end_line = tonumber(opts.line2)
    -- Query contextpilot for the specified range
    A.query_context_for_range(start_line, end_line)
end, { range = true }) -- Enable range support for visual selections

-- Command to find relevant commit descriptions for a selected range
vim.api.nvim_create_user_command("ContextPilotRelevantCommitsRange", function(opts)
    -- Extract line numbers from the range selection
    local start_line = tonumber(opts.line1)
    local end_line = tonumber(opts.line2)
    -- Query contextpilot for commit descriptions related to the range
    A.query_descriptions_for_range(start_line, end_line)
end, { range = true }) -- Enable range support for visual selections

-- Command to selectively index specific subdirectories
vim.api.nvim_create_user_command(
    "ContextPilotIndexSubDirectory",
    function() A.start_indexing_subdirectory() end,
    {}
)

-- NEW: Commands for generate diffs functionality
vim.api.nvim_create_user_command(
    "ContextPilotGenerateDiffs",
    function() diffs.generate_diffs_for_chat() end,
    { desc = "Generate git diffs for current file or selection" }
)

vim.api.nvim_create_user_command(
    "ContextPilotGenerateDiffsRange",
    function(opts)
        local start_line = tonumber(opts.line1)
        local end_line = tonumber(opts.line2)
        diffs.generate_diffs_for_range(start_line, end_line)
    end,
    { range = true, desc = "Generate git diffs for selected range" }
)

-- Return the module table to make functions available to other Lua code
return A
