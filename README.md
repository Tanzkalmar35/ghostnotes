# 👻 ghostnotes.nvim

A lightweight, frictionless annotation system for Neovim.

`ghostnotes.nvim` allows you to attach project-specific notes, todos, and warnings directly to lines of code using 
Neovim's virtual text. Instead of cluttering your source code with ugly comments, your notes hover beautifully in the 
margins and are saved to a single, Git-friendly Markdown file.

## ✨ Features

* **Zero-Friction Entry:** Hit a key, type your note, and you're done. No complex menus.
* **Smart Note Classes:** Prefix your notes with `error:`, `todo:`, or `info:` to instantly transform them into highly visible, colored tags.
* **Dynamic Theme Integration:** Tag colors automatically invert and perfectly match your current Neovim colorscheme's diagnostic colors.
* **Responsive Truncation:** Notes dynamically truncate with `...` if your window shrinks, ensuring they never break your layout or wrap across lines.
* **Live Syncing:** Edit the Markdown file in a split, save it, and watch the virtual text instantly update across all your open buffers.
* **FzfLua Integration:** Press a key to pull up a lightning-fast, project-wide search dashboard of all your notes.
* **Zen Mode:** Toggle notes off instantly when you need to focus on the raw code.
* **Bidirectional Teleportation:** Jump instantly from your code to the full Markdown context, and warp back to the code using Neovim's native `gF`.

[Demo](images/ghostnotes-demo.png)

---

## ⚡️ Requirements

* **Neovim >= 0.9.0** (Requires modern `extmarks` API)
* **[FzfLua](https://github.com/ibhagwan/fzf-lua)** (For project-wide searching)
* *Optional but recommended:* **[nvim-notify](https://github.com/rcarriga/nvim-notify)** (For beautiful, non-blocking UI notifications)

---

## 📦 Installation

Install using your favorite package manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "Tanzkalmar35/ghostnotes",
    dependencies = { "ibhagwan/fzf-lua" },
    config = function()
        require("ghostnotes").setup()
    end
}

### Native `vim.pack`

Add the repository via vim.pack:

```lua
vim.pack.add({{ src = "https://github.com/Tanzkalmar35/ghostnotes" }}),
```

Require and setup the plugin:

```lua
require('ghostnotes').setup()
```

## Usage & Keymaps

### Keymaps

By default, following keymaps control the plugin. I'll be working on making these easily configurable in the near future.

| Keymap | Action | Description |
|---|---|---|
| <leader>ka | Add note | Prompts you to input the note to attach to the current line and save under .notes/ghosts.md |
| <leader>kd | Delete note  | Deletes the note on the current line from the current view and the disk |
| <leader>kj | Jump to note | If the cursor is on a line with a note, this opens up a vertical split displaying the note in .notes/ghosts.md |
| <leader>ks | Search notes | Opens up a FzfLua picker to search for (and navigate to) notes in the project |
| <leader>kt | Toggle notes | Toggles the visibility of the notes on or off |

### Note classes

Prefixing a note with one of the following keywords will automatically highlight the note according to the class

- "error: ..."
- "info: ..."
- "todo: ..."
- If no prefix is provided, there will be no special highlighting, and the note will be displayed in a default way

## How it works

The plugin does not touch your source files - don't worry. When a note is added, a .notes/ghosts.md will be created 
in the project root. In this file, all notes will be stored. Furthermore, Below the actual notes, you can add more detailed 
descriptions or whatever, which will not be displayed in-file.

Due to the plain-text storage of the notes, this directory can - if wanted - be committed to github, and used by remote users
the same way as locally. Or just add .notes to the .gitignore, your choice.
