# ContextPilot Plugin for NeoVim

ContextPilot helps you quickly find contextually relevant files based on your current file, line, or selection in Neovim. It leverages fuzzy searching and indexing to improve your workflow.

---

## 📦 Installation

### Using **Packer**:

```lua
use {
  "krshrimali/context-pilot.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-fzy-native.nvim"
  }
}
```

### Using **lazy.nvim**:

```lua
{
  "krshrimali/context-pilot.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-fzy-native.nvim"
  }
}
```

---

## ⚙️ Pre-requisites

Install the ContextPilot server:

```bash
brew install krshrimali/context-pilot/context-pilot
```

---

## 🚀 Getting Started

1. Start indexing your workspace from Neovim:

   ```vim
   :ContextPilotStartIndexing
   ```

2. Use any of the following commands to retrieve relevant files:

   - `:ContextPilotContexts` — Fetch contextually relevant files for the **current file**.
   - `:ContextPilotContextsCurrentLine` — Fetch relevant files for the **current line**.
   - `:ContextPilotQueryRange` — Fetch relevant files for a **selected range** of lines.

---

## 📚 Tips

- Make sure [Telescope](https://github.com/nvim-telescope/telescope.nvim) is properly configured, as this plugin depends on it.
- Re-index your project whenever significant codebase changes occur.
