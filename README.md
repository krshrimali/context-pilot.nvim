# ContextPilot Plugin for NeoVim

ContextPilot helps you quickly find contextually relevant files based on your current file, line, or selection in Neovim. It leverages fuzzy searching and indexing to improve your workflow.

---

## 📦 Installation

### Using **lazy.nvim**:

```lua
{
  "krshrimali/context-pilot.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-fzy-native.nvim"
  },
  config = function()
    require("contextpilot")
  end
}
```

---

## ⚙️ Pre-requisites

Install the ContextPilot server:

```bash
brew install krshrimali/context-pilot/context-pilot
```

OR if using AUR, refer: https://aur.archlinux.org/packages/contextpilot.

In case you are not using either of the package managers above, follow the commands below: (`cargo` installation is must)

```bash
git clone https://github.com/krshrimali/context-pilot-rs && cd context-pilot-rs
cargo build --release
cp ./target/release/contextpilot ~/.local/bin/
```

Feel free to replace the binary path to `/usr/local/bin` based on your system.

---

## 🚀 Getting Started

1. (Optional, for faster query results) Start indexing your workspace from Neovim:

   ```vim
   :ContextPilotStartIndexing
   ```
2. (Optional, for faster query results) OR Index some selected repositories:

  ```lua
  :ContextPilotIndexSubDirectory
  ```

  Choose the subdirectories you want to index (hitting `Tab`) and let the indexing finish.

2. Use any of the following commands to retrieve relevant files:

  - `:ContextPilotRelevantCommitsRange` - Fetch relevant commits for **selected range** of lines.
   - `:ContextPilotRelevantFilesWholeFile` — Fetch contextually relevant files for the **current file**.
   - `:ContextPilotRelevantFilesRange` — Fetch relevant files for a **selected range** of lines.

---

## 📚 Tips

- Re-index your project whenever significant codebase changes occur.
