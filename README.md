# context-pilot.nvim with Generate Diffs

A powerful Neovim plugin that extends the original [context-pilot.nvim](https://github.com/krshrimali/context-pilot.nvim) with additional "Generate Diffs" functionality for analyzing git commit history and code evolution.

## Features

### Original Context Pilot Features
- 🔍 Find relevant files for current file or selected code ranges
- 📝 Get commit descriptions for code sections
- 📦 Index workspace for faster queries
- 🎯 Selective subdirectory indexing
- 🔭 Telescope integration for interactive file selection

### New Generate Diffs Features
- 📊 **Generate Git Diffs**: Create markdown buffers with relevant commit diffs
- 🎯 **Range Support**: Works with visual selections or entire files
- 📋 **Formatted Output**: Clean markdown format optimized for AI analysis
- 🚀 **Fast Processing**: Asynchronous execution with progress indicators
- 💡 **Smart Filtering**: Only includes commits with actual changes to the file

## Prerequisites

1. **contextpilot binary** (minimum version 0.9.0):
   ```bash
   # Via Homebrew
   brew install krshrimali/context-pilot/context-pilot
   
   # Via AUR (Arch Linux)
   yay -S contextpilot
   
   # From source
   git clone https://github.com/krshrimali/context-pilot-rs
   cd context-pilot-rs
   cargo build --release
   cp ./target/release/contextpilot ~/.local/bin/
   ```

2. **Neovim** (≥ 0.7.0)
3. **Telescope.nvim** and **plenary.nvim**
4. **Git repository** (for diff functionality)

## Installation

### Using lazy.nvim
```lua
{
  "your-username/context-pilot-enhanced.nvim", -- Replace with actual repo
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-fzy-native.nvim",
    "nvim-lua/plenary.nvim"
  },
  config = function()
    require("contextpilot")
  end
}
```

### Using packer.nvim
```lua
use {
  "your-username/context-pilot-enhanced.nvim", -- Replace with actual repo
  requires = {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-fzy-native.nvim",
    "nvim-lua/plenary.nvim"
  },
  config = function()
    require("contextpilot")
  end
}
```

## Usage

### Generate Diffs Commands

#### 1. Generate Diffs for Current File
```vim
:ContextPilotGenerateDiffs
```
- Analyzes the entire current file
- Finds all relevant commits that touched the file
- Creates a markdown buffer with formatted diffs
- Opens in a vertical split

#### 2. Generate Diffs for Selected Range
```vim
:'<,'>ContextPilotGenerateDiffsRange
```
- Works with visual selections
- Analyzes only the selected lines
- Shows commits that specifically modified the selected code

### Original Context Pilot Commands

#### File Analysis
```vim
:ContextPilotRelevantFilesWholeFile       " Find related files for current file
:ContextPilotRelevantFilesRange           " Find related files for selection
:ContextPilotRelevantCommitsRange         " Get commit descriptions for selection
```

#### Indexing
```vim
:ContextPilotStartIndexing                " Index entire workspace
:ContextPilotIndexSubDirectory            " Index selected subdirectories
```

## Example Workflow

1. **Open a file** in your Git repository
2. **Select problematic code** (optional)
3. **Run generate diffs**:
   ```vim
   :ContextPilotGenerateDiffs
   ```
4. **Analyze the output** in the new markdown buffer
5. **Use with AI tools** to understand code evolution

## Output Format

The generate diffs command creates a markdown buffer with this structure:

```markdown
# Git Diffs for filename.ext (lines 10-25)

This file contains all relevant git diffs for analysis. You can use this with AI tools to ask questions about these changes.

Commit: b2f766e
Title: Explicit comments for clarity
Author: Kushashwa Ravi Shrimali
Date: Sat Jul 26 21:08:39 2025

diff --git a/lua/contextpilot.lua b/lua/contextpilot.lua
index 134ad72..692b44c 100644
--- a/lua/contextpilot.lua
+++ b/lua/contextpilot.lua
@@ -1,52 +1,78 @@
+-- Main module table that will be returned at the end of the file
 local A = {}

---

Commit: ec66890
Title: Rename to contextpilot (binary)
Author: Kushashwa Ravi Shrimali
Date: Tue May 13 18:44:51 2025

[... more diffs ...]
```

## Key Mappings (Suggested)

Add these to your Neovim configuration:

```lua
-- Generate diffs for current file
vim.keymap.set('n', '<leader>gd', ':ContextPilotGenerateDiffs<CR>', { desc = 'Generate diffs for current file' })

-- Generate diffs for visual selection
vim.keymap.set('v', '<leader>gd', ':ContextPilotGenerateDiffsRange<CR>', { desc = 'Generate diffs for selection' })

-- Other context pilot commands
vim.keymap.set('n', '<leader>cf', ':ContextPilotRelevantFilesWholeFile<CR>', { desc = 'Find relevant files' })
vim.keymap.set('v', '<leader>cr', ':ContextPilotRelevantFilesRange<CR>', { desc = 'Find files for selection' })
vim.keymap.set('v', '<leader>cc', ':ContextPilotRelevantCommitsRange<CR>', { desc = 'Get commit descriptions' })
```

## Use Cases

### 1. Bug Investigation
```vim
-- Select the buggy code
-- Run :ContextPilotGenerateDiffs
-- Analyze when and why the code changed
```

### 2. Code Review Preparation
```vim
-- Open the file you're reviewing
-- Run :ContextPilotGenerateDiffs
-- Understand the historical context
```

### 3. Legacy Code Understanding
```vim
-- Select complex function
-- Generate diffs to see evolution
-- Use with AI: "Explain how this function changed over time"
```

### 4. Refactoring Planning
```vim
-- Analyze code section
-- See historical changes
-- Plan refactoring based on change patterns
```

## Configuration

The plugin works out of the box, but you can customize notifications:

```lua
-- In your init.lua or plugin config
vim.opt.termguicolors = true -- For better diff highlighting
```

## Troubleshooting

### "contextpilot binary not found"
- Ensure `contextpilot` is installed and in your PATH
- Check version: `contextpilot --version` (needs ≥ 0.9.0)

### "No commits found"
- Make sure the file is tracked by Git
- Ensure the repository has commit history
- Try a different line range

### "Please save the file before analyzing"
- Save the current file (`:w`) before running diff commands
- The plugin requires saved files to ensure accurate analysis

### "No diffs were generated"
- The commits might not have changes to the specific file
- Try expanding the line range or analyzing the whole file

## Technical Details

### Architecture
- **Main module**: `lua/contextpilot.lua` - Core functionality and commands
- **Diffs module**: `lua/contextpilot/diffs.lua` - Generate diffs implementation
- **Dependencies**: Telescope for UI, plenary for utilities

### How It Works
1. **Version Check**: Validates contextpilot binary compatibility
2. **Context Analysis**: Runs `contextpilot <workspace> -t desc -s <start> -e <end> <file>`
3. **Commit Parsing**: Parses JSON output with commit metadata
4. **Diff Generation**: For each commit, runs `git show <hash> -- "<file>"`
5. **Buffer Creation**: Creates markdown document with formatted output
6. **Display**: Opens in vertical split with syntax highlighting

### Contextpilot Output Format
The plugin expects contextpilot to return JSON in this format:
```json
[
  ["Title", "Description", "Author", "Date", "URL"],
  ["Another commit", "", "Author Name", "Sat Jul 26 21:08:39 2025", "https://github.com/repo/commit/hash"]
]
```

### Performance
- **Asynchronous**: All operations run in background
- **Progress Indicators**: Visual feedback during processing
- **Smart Filtering**: Only processes commits with actual file changes
- **Caching**: Leverages contextpilot's indexing for faster queries

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Original [context-pilot.nvim](https://github.com/krshrimali/context-pilot.nvim) by Kushashwa Ravi Shrimali
- [context-pilot-rs](https://github.com/krshrimali/context-pilot-rs) Rust backend
- Inspired by similar functionality in various code analysis tools

## Changelog

### v1.0.0 (Initial Release)
- ✅ Added `ContextPilotGenerateDiffs` command
- ✅ Added `ContextPilotGenerateDiffsRange` command  
- ✅ Markdown buffer creation with syntax highlighting
- ✅ Visual selection support
- ✅ Progress indicators and error handling
- ✅ Integration with existing context-pilot functionality
- ✅ Proper handling of contextpilot JSON output format
