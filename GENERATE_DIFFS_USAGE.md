# Generate Diffs Command Usage Guide

## Overview

The **context-pilot-vscode** extension already includes a powerful "Generate Diffs" command called `generateDiffsForCursorChat` that creates a buffer with relevant commits and their diffs. This feature is designed to work seamlessly with Cursor Chat for code analysis.

## What It Does

The "Generate Diffs for Cursor Chat" command:

1. **Analyzes your code**: Gets relevant commits for the current file or selected code range using the contextpilot Rust backend
2. **Fetches commit history**: Retrieves commit details including hash, title, author, and date
3. **Generates git diffs**: For each relevant commit, extracts the actual code changes (`git show <commit-hash> -- "<file>"`)
4. **Creates a markdown buffer**: Opens a new document with all the diffs formatted for easy analysis
5. **Optimizes for Cursor Chat**: The output is specifically formatted to work well with AI analysis tools

## How to Use

### Prerequisites

1. **Install the contextpilot binary**:
   ```bash
   # Via Homebrew (macOS/Linux)
   brew install krshrimali/context-pilot/context-pilot
   
   # Via AUR (Arch Linux)
   yay -S contextpilot
   
   # From source (requires Rust/Cargo)
   git clone https://github.com/krshrimali/context-pilot-rs
   cd context-pilot-rs
   cargo build --release
   cp ./target/release/contextpilot ~/.local/bin/
   ```

2. **Install the VSCode extension** from the marketplace: "Context Pilot"

### Using the Command

1. **Open a file** in your workspace that's tracked by Git
2. **Select code** (optional) - if you want to analyze specific lines, select them first
3. **Run the command**:
   - Open Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
   - Type "Context Pilot: Generate Diffs for Cursor Chat"
   - Or use the right-click context menu when text is selected

### Command Behavior

- **With selection**: Analyzes commits that touched the selected lines
- **Without selection**: Analyzes commits for the entire current file
- **Progress indicator**: Shows progress while fetching commits and generating diffs
- **Error handling**: Displays helpful error messages if contextpilot binary is missing or incompatible

## Output Format

The command creates a new markdown document with the following structure:

```markdown
# Git Diffs for filename.ext

This file contains all relevant git diffs for analysis. You can use Cursor Chat to ask questions about these changes.

Commit: abc123def
Title: Fix bug in user authentication
Author: developer@example.com
Date: 2024-01-15

diff --git a/src/auth.js b/src/auth.js
index 1234567..abcdefg 100644
--- a/src/auth.js
+++ b/src/auth.js
@@ -10,7 +10,7 @@ function authenticate(user) {
-  if (user.password === hash) {
+  if (user.password === hashPassword(user.password)) {
     return true;
   }

---

Commit: def456ghi
Title: Add error handling
Author: another@example.com
Date: 2024-01-10

[... more diffs ...]
```

## Integration with Cursor Chat

The generated diffs buffer is optimized for use with Cursor Chat:

1. **Ask questions** about the changes:
   - "What was the purpose of commit abc123def?"
   - "How did the authentication logic change over time?"
   - "What bugs were fixed in this file?"

2. **Analyze patterns**:
   - "What are the most common types of changes in this file?"
   - "Who are the main contributors to this code?"

3. **Understand context**:
   - "Why was this refactoring done?"
   - "What security issues were addressed?"

## Available Commands in Context Pilot

The extension provides several related commands:

- `Context Pilot: Generate Diffs for Cursor Chat` - The main diff generation command
- `Context Pilot: Get Relevant Commits` - Shows commit list without diffs
- `Context Pilot: Get Context Files (Current File)` - Find related files
- `Context Pilot: Get Context Files (Selected Range)` - Find files related to selection
- `Context Pilot: Index Workspace` - Index for faster queries
- `Context Pilot: Show All Commands` - Display all available commands

## Configuration

The extension supports configuration options:

- **OpenAI API Key**: For enhanced commit analysis (optional)
- **Auto Index on Git Commit**: Automatically re-index when commits are made

## Troubleshooting

### "ContextPilot binary not found"
- Ensure contextpilot binary is installed and in your PATH
- Check the Output panel for detailed installation instructions

### "No commits found"
- Make sure the file is tracked by Git
- Try selecting a different code range
- Ensure the repository has commit history

### "Controls Unresponsive" or similar errors
- Update to the latest version of the contextpilot binary (minimum v0.9.0)
- Check that your Git repository is properly initialized

## Technical Details

### How It Works Internally

1. **Version Check**: Validates contextpilot binary version (≥0.9.0)
2. **Context Analysis**: Runs `contextpilot <workspace> -t desc <file> -s <start> -e <end>`
3. **Commit Parsing**: Parses JSON output with commit metadata
4. **Diff Generation**: For each commit, runs `git show <hash> -- "<file>"`
5. **Buffer Creation**: Creates markdown document with formatted output
6. **Display**: Opens in new editor panel alongside current file

### Performance Considerations

- **Indexing**: Run "Index Workspace" for faster queries on large repositories
- **Selective Indexing**: Use "Index Subdirectories" for monorepos
- **File Size**: Large files (>10k-20k LoCs) may take longer to analyze

## Example Use Cases

### 1. Bug Investigation
```
1. Select the problematic code
2. Run "Generate Diffs for Cursor Chat"
3. Ask Cursor: "What changes might have introduced this bug?"
```

### 2. Code Review Preparation
```
1. Open the file you're reviewing
2. Generate diffs for the entire file
3. Ask Cursor: "Summarize the evolution of this code"
```

### 3. Understanding Legacy Code
```
1. Select complex function
2. Generate diffs
3. Ask Cursor: "Explain how this function has changed and why"
```

This command is already fully implemented and ready to use - no additional development needed!