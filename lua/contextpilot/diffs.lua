-- Generate Diffs module for context-pilot.nvim
-- This module implements functionality to generate git diffs for relevant commits

local M = {}

-- Configuration
M.command = "contextpilot"
M.MIN_CONTEXTPILOT_VERSION = "0.9.0"

-- Helper function to display notifications
local function notify_inform(msg, level)
    vim.api.nvim_notify(msg, level or vim.log.levels.INFO, {})
end

-- Parse semantic version string into numeric components
local function parse_version(version_str)
    local major, minor, patch = version_str:match("(%d+)%.(%d+)%.(%d+)")
    return tonumber(major), tonumber(minor), tonumber(patch)
end

-- Check if installed version meets minimum requirements
local function is_version_compatible(installed, required)
    local imaj, imin, ipat = parse_version(installed)
    local rmaj, rmin, rpat = parse_version(required)
    if imaj ~= rmaj then return imaj > rmaj end
    if imin ~= rmin then return imin > rmin end
    return ipat >= rpat
end

-- Verify contextpilot binary version
local function check_contextpilot_version()
    local output = vim.fn.system(M.command .. " --version")
    if vim.v.shell_error ~= 0 or not output or output == "" then
        notify_inform("❌ Unable to determine contextpilot version.", vim.log.levels.ERROR)
        return false
    end

    local version = output:match("contextpilot%s+(%d+%.%d+%.%d+)")
    if not version then
        notify_inform("⚠️ Unexpected version output: " .. output, vim.log.levels.ERROR)
        return false
    end

    if not is_version_compatible(version, M.MIN_CONTEXTPILOT_VERSION) then
        notify_inform(
            string.format(
                "⚠️ Your contextpilot version is %s. Please update to at least %s.",
                version,
                M.MIN_CONTEXTPILOT_VERSION
            ),
            vim.log.levels.WARN
        )
        return false
    end

    return true
end

-- Get current file path and validate it
local function get_current_file_info()
    local file_path = vim.api.nvim_buf_get_name(0)
    local folder_path = vim.loop.cwd()
    
    if file_path == "" then
        notify_inform("No file is currently open.", vim.log.levels.WARN)
        return nil
    end
    
    if not vim.fn.filereadable(file_path) then
        notify_inform("File does not exist: " .. file_path, vim.log.levels.ERROR)
        return nil
    end
    
    -- Check if file is saved (not modified)
    if vim.api.nvim_buf_get_option(0, 'modified') then
        notify_inform("Please save the file before analyzing commits.", vim.log.levels.WARN)
        return nil
    end
    
    return {
        file_path = file_path,
        folder_path = folder_path,
        filename = vim.fn.fnamemodify(file_path, ':t')
    }
end

-- Get line range (either selection or whole file)
local function get_line_range()
    local mode = vim.fn.mode()
    local start_line, end_line, is_selection
    
    -- Check if we're in visual mode or have a selection
    if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is visual block mode
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        start_line = start_pos[2]
        end_line = end_pos[2]
        is_selection = true
    else
        -- Use whole file
        start_line = 1
        end_line = vim.api.nvim_buf_line_count(0)
        is_selection = false
    end
    
    return {
        start_line = start_line,
        end_line = end_line,
        is_selection = is_selection
    }
end

-- Execute contextpilot desc command to get commit information
local function get_commit_descriptions(file_info, line_range)
    local command = string.format(
        "%s %s -t desc -s %d -e %d %s",
        M.command,
        file_info.folder_path,
        line_range.start_line,
        line_range.end_line,
        file_info.file_path
    )
    
    return vim.fn.system(command)
end

-- Execute git show command to get diff for a specific commit
local function get_git_diff(commit_hash, file_path, folder_path)
    local git_command = string.format('git show %s -- "%s"', commit_hash, file_path)
    local output = vim.fn.system({
        'bash', '-c', 
        string.format('cd "%s" && %s', folder_path, git_command)
    })
    
    if vim.v.shell_error ~= 0 then
        notify_inform(string.format("Git error for commit %s: %s", commit_hash, output), vim.log.levels.WARN)
        return nil
    end
    
    return output
end

-- Extract commit hash from URL or return as-is
local function extract_commit_hash(hash_or_url)
    -- If it looks like a URL, extract the hash from the end
    local hash = hash_or_url:match(".*/(.+)$") or hash_or_url
    return hash
end

-- Format a single commit diff entry
-- Expected format: [title, description, author, date, hash_url]
local function format_commit_diff(commit_data, diff_output)
    local title, description, author, date, hash_url = unpack(commit_data)
    local commit_hash = extract_commit_hash(hash_url)
    
    return string.format(
        "Commit: %s\nTitle: %s\nAuthor: %s\nDate: %s\n\n%s\n\n---\n\n",
        commit_hash,
        title,
        author,
        date,
        diff_output
    )
end

-- Create markdown content with all diffs
local function create_diff_content(filename, commit_diffs, line_range)
    local range_info = line_range.is_selection 
        and string.format(" (lines %d-%d)", line_range.start_line, line_range.end_line)
        or ""
        
    local header = string.format(
        "# Git Diffs for %s%s\n\nThis file contains all relevant git diffs for analysis. You can use this with AI tools to ask questions about these changes.\n\n",
        filename,
        range_info
    )
    
    return header .. table.concat(commit_diffs, "")
end

-- Create a new buffer with the diff content
local function create_diff_buffer(content, filename)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
    
    -- Set buffer name
    local buf_name = string.format("Git Diffs - %s", filename)
    vim.api.nvim_buf_set_name(buf, buf_name)
    
    -- Split content into lines and set in buffer
    local lines = vim.split(content, '\n', { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    -- Make buffer read-only
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    return buf
end

-- Open buffer in a new window
local function open_diff_buffer(buf)
    -- Open in a vertical split
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    
    -- Set window options
    vim.api.nvim_win_set_option(win, 'wrap', false)
    vim.api.nvim_win_set_option(win, 'number', true)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
    
    return win
end

-- Main function to generate diffs
function M.generate_diffs_for_chat()
    -- Version check
    if not check_contextpilot_version() then
        return
    end
    
    -- Get current file information
    local file_info = get_current_file_info()
    if not file_info then
        return
    end
    
    -- Get line range
    local line_range = get_line_range()
    
    -- Show progress message
    local range_desc = line_range.is_selection 
        and string.format("selected range (lines %d-%d)", line_range.start_line, line_range.end_line)
        or "current file"
    notify_inform(string.format("🔍 Generating diffs for %s...", range_desc))
    
    -- Get commit descriptions from contextpilot
    local contextpilot_output = get_commit_descriptions(file_info, line_range)
    
    if vim.v.shell_error ~= 0 then
        notify_inform("❌ Error running contextpilot command", vim.log.levels.ERROR)
        return
    end
    
    -- Parse JSON output
    local ok, parsed_commits = pcall(vim.json.decode, contextpilot_output:gsub('^%s*(.-)%s*$', '%1'))
    if not ok or type(parsed_commits) ~= "table" or #parsed_commits == 0 then
        notify_inform("⚠️ No commits found for the selected range", vim.log.levels.WARN)
        return
    end
    
    notify_inform(string.format("📝 Found %d relevant commits, generating diffs...", #parsed_commits))
    
    -- Generate diffs for each commit
    local commit_diffs = {}
    
    for _, commit_data in ipairs(parsed_commits) do
        -- Format: [title, description, author, date, hash_url]
        local title, description, author, date, hash_url = unpack(commit_data)
        local commit_hash = extract_commit_hash(hash_url)
        
        -- Get git diff for this commit
        local diff_output = get_git_diff(commit_hash, file_info.file_path, file_info.folder_path)
        
        if diff_output and diff_output:match("%S") then -- Check if diff is not empty/whitespace
            local formatted_diff = format_commit_diff(commit_data, diff_output)
            table.insert(commit_diffs, formatted_diff)
        end
    end
    
    if #commit_diffs == 0 then
        notify_inform("⚠️ No diffs were generated for any commits", vim.log.levels.WARN)
        return
    end
    
    -- Create markdown content
    local diff_content = create_diff_content(file_info.filename, commit_diffs, line_range)
    
    -- Create and open buffer
    local buf = create_diff_buffer(diff_content, file_info.filename)
    local win = open_diff_buffer(buf)
    
    -- Success message
    notify_inform(string.format("✅ Generated %d diffs! You can now analyze these changes.", #commit_diffs))
end

-- Function to generate diffs for a specific range (used with visual selection)
function M.generate_diffs_for_range(start_line, end_line)
    -- Version check
    if not check_contextpilot_version() then
        return
    end
    
    -- Get current file information
    local file_info = get_current_file_info()
    if not file_info then
        return
    end
    
    -- Create line range object
    local line_range = {
        start_line = start_line,
        end_line = end_line,
        is_selection = true
    }
    
    -- Show progress message
    notify_inform(string.format("🔍 Generating diffs for lines %d-%d...", start_line, end_line))
    
    -- Get commit descriptions from contextpilot
    local contextpilot_output = get_commit_descriptions(file_info, line_range)
    
    if vim.v.shell_error ~= 0 then
        notify_inform("❌ Error running contextpilot command", vim.log.levels.ERROR)
        return
    end
    
    -- Parse JSON output
    local ok, parsed_commits = pcall(vim.json.decode, contextpilot_output:gsub('^%s*(.-)%s*$', '%1'))
    if not ok or type(parsed_commits) ~= "table" or #parsed_commits == 0 then
        notify_inform("⚠️ No commits found for the selected range", vim.log.levels.WARN)
        return
    end
    
    notify_inform(string.format("📝 Found %d relevant commits, generating diffs...", #parsed_commits))
    
    -- Generate diffs for each commit
    local commit_diffs = {}
    
    for _, commit_data in ipairs(parsed_commits) do
        -- Format: [title, description, author, date, hash_url]
        local title, description, author, date, hash_url = unpack(commit_data)
        local commit_hash = extract_commit_hash(hash_url)
        
        -- Get git diff for this commit
        local diff_output = get_git_diff(commit_hash, file_info.file_path, file_info.folder_path)
        
        if diff_output and diff_output:match("%S") then
            local formatted_diff = format_commit_diff(commit_data, diff_output)
            table.insert(commit_diffs, formatted_diff)
        end
    end
    
    if #commit_diffs == 0 then
        notify_inform("⚠️ No diffs were generated for any commits", vim.log.levels.WARN)
        return
    end
    
    -- Create markdown content
    local diff_content = create_diff_content(file_info.filename, commit_diffs, line_range)
    
    -- Create and open buffer
    local buf = create_diff_buffer(diff_content, file_info.filename)
    local win = open_diff_buffer(buf)
    
    -- Success message
    notify_inform(string.format("✅ Generated %d diffs! You can now analyze these changes.", #commit_diffs))
end

return M