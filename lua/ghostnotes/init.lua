local M = {}

-- Create namespace
local ns_id = vim.api.nvim_create_namespace("ghostnotes")

-- Define notes classes
local note_classes = {
    error   = { prefix = "error:", icon = "", hl = "GhostNoteError" },
    todo    = { prefix = "todo:", icon = "", hl = "GhostNoteTodo" },
    info    = { prefix = "info:", icon = "", hl = "GhostNoteInfo" },
    -- Fallback - default note
    default = { icon = "", hl = "GhostNoteDefault" }
}

local is_enabled = true

-- Helper to steal a color from the current theme
local function get_theme_color(group_name, property)
    local hl = vim.api.nvim_get_hl(0, { name = group_name, link = false })
    if hl and hl[property] then
        return string.format("#%06x", hl[property])
    end
    return "NONE" -- Fallback if the theme doesn't define it
end

-- Helper: Harvest all notes for FzfLua
local function get_all_notes()
    local note_file = vim.fn.getcwd() .. "/.notes/ghosts.md"
    local f = io.open(note_file, "r")
    if not f then return {} end

    local notes = {}
    local current_path, current_row = nil, nil

    for line in f:lines() do
        -- Look for the protocol header
        local match_path, match_row = string.match(line, "<!%-%- ghost: (.-):(%d+) %-%->")

        if match_path and match_row then
            current_path = match_path
            current_row = tonumber(match_row)
        elseif current_path and line ~= "" then
            -- Grab the actual text and package it
            table.insert(notes, {
                filename = current_path,
                lnum = current_row,
                text = line
            })
            current_path = nil -- Reset for the next note
        end
    end

    f:close()
    return notes
end

-- Calculates and builds the highlights
local function build_ghost_highlights()
    -- Steal the theme's standard diagnostic colors
    local theme_red = get_theme_color("DiagnosticError", "fg")
    local theme_yellow = get_theme_color("DiagnosticWarn", "fg")
    local theme_blue = get_theme_color("DiagnosticInfo", "fg")

    -- Steal the editor's main background color (for the dark text)
    local base_bg = get_theme_color("Normal", "bg")

    -- Safety fallback: If terminal is transparent, use pitch black for text
    if base_bg == "NONE" then base_bg = "#000000" end

    -- Invert colorscheme colors for better visibility
    vim.api.nvim_set_hl(0, "GhostNoteDefault", { link = "Comment" })

    vim.api.nvim_set_hl(0, "GhostNoteError", {
        fg = base_bg, bg = theme_red, bold = true
    })

    vim.api.nvim_set_hl(0, "GhostNoteTodo", {
        fg = base_bg, bg = theme_yellow, bold = true
    })

    vim.api.nvim_set_hl(0, "GhostNoteInfo", {
        fg = base_bg, bg = theme_blue, bold = true
    })
end

build_ghost_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = build_ghost_highlights,
})

local function render_virtual_text(bufnr, line, text)
    local target_class = note_classes.default
    local display_text = text

    -- Scan for Note Classes (error:, todo:, etc.)
    for _, class_data in pairs(note_classes) do
        if class_data.prefix and string.match(string.lower(text), "^" .. class_data.prefix) then
            target_class = class_data
            display_text = string.gsub(text, "^(?i)" .. class_data.prefix .. "%s*", "")
            break
        end
    end

    -- Dynamic Window Truncation
    local win_col = 80
    local win_width = vim.api.nvim_win_get_width(0)

    -- Calculate how much space is left on the screen (minus 10 for padding)
    local available_space = win_width - win_col - 10
    local icon_len = vim.fn.strdisplaywidth(target_class.icon)
    local max_text_len = available_space - icon_len

    -- If the window is too small, give it a baseline minimum so it doesn't crash
    if max_text_len < 5 then max_text_len = 5 end

    -- Truncate and append '...' if it exceeds the available space
    if string.len(display_text) > max_text_len then
        display_text = string.sub(display_text, 1, max_text_len - 3) .. "..."
    end

    -- Render the Virtual Text
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
        virt_text = { { target_class.icon .. display_text, target_class.hl } },
        virt_text_win_col = win_col,
    })
end

-- Add a note
function M.add_note()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Grab the cursor table and index it directly (Lua arrays are 1-indexed)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local line = row - 1

    local file_path = vim.fn.expand('%:p:.') -- Relative path

    -- Prompt the user
    local note_text = vim.fn.input("Ghostnote: ")
    if note_text == "" then
        return
    end

    -- Live update
    render_virtual_text(bufnr, line, note_text)

    -- Save to disk
    local notes_dir = vim.fn.getcwd() .. "/.notes"
    if vim.fn.isdirectory(notes_dir) == 0 then
        vim.fn.mkdir(notes_dir, "p") -- Create dir if it doesn't exist
    end

    local note_file = notes_dir .. "/ghosts.md"
    local f = io.open(note_file, "a")
    if f then
        f:write(string.format("<!-- ghost: %s:%s -->\n", file_path, row))
        f:write(string.format("%s\n\n", note_text))
        f:close()
        vim.notify("Ghost note saved (.notes/ghosts.md)", vim.log.levels.INFO)
    else
        vim.notify("Error saving ghost note!", vim.log.levels.ERROR)
    end
end

-- Load notes for the current buffer
function M.load_notes(target_bufnr, target_file_path)
    if not is_enabled then return end

    local bufnr = target_bufnr or vim.api.nvim_get_current_buf()
    local file_path = target_file_path or vim.fn.expand('%:p:.')

    local notes_dir = vim.fn.getcwd() .. "/.notes"
    local note_file = notes_dir .. "/ghosts.md"

    -- Attempt to open the markdown file
    local f = io.open(note_file, "r")
    if not f then return end -- No notes file exists yet, just exit quietly

    local target_line = nil

    for line in f:lines() do
        local match_path, match_row = string.match(line, "<!%-%- ghost: (.+):(%d+) %-%->")

        if match_path and match_row then
            if match_path == file_path then
                target_line = tonumber(match_row) - 1
            else
                target_line = nil
            end
        elseif target_line and line ~= "" then
            render_virtual_text(bufnr, target_line, line)
            target_line = nil
        end
    end

    f:close()
end

-- Delete a note on the current line
function M.delete_note()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local line = row - 1
    local file_path = vim.fn.expand('%:p:.')

    -- Remove old extmark on current line - if exists
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, { line, 0 }, { line, -1 }, {})
    for _, mark in ipairs(marks) do
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, mark[1])
    end

    -- Remove it from the Markdown file too
    local note_file = vim.fn.getcwd() .. "/.notes/ghosts.md"
    local f = io.open(note_file, "r")
    if not f then return end

    local lines_to_keep = {}
    local skip_mode = false

    -- Read the file and strip out the targeted block
    for l in f:lines() do
        local match_path, match_row = string.match(l, "<!%-%- ghost: (.+):(%d+) %-%->")

        if match_path and match_row then
            if match_path == file_path and tonumber(match_row) == row then
                skip_mode = true  -- This is our target! Start skipping (deleting)
            else
                skip_mode = false -- A different note, keep it
                table.insert(lines_to_keep, l)
            end
        elseif not skip_mode then
            -- Normal note text we want to keep
            table.insert(lines_to_keep, l)
        end
    end
    f:close()

    -- Overwrite the file with the surviving lines
    local fw = io.open(note_file, "w")
    if fw then
        for _, l in ipairs(lines_to_keep) do
            fw:write(l .. "\n")
        end
        fw:close()
        vim.notify("Ghost note deleted", vim.log.levels.INFO)
    end
end

-- Jump from source code to the Markdown note
function M.jump_to_note()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local file_path = vim.fn.expand('%:p:.')
    local target_header = string.format("", file_path, row)

    local note_file = vim.fn.getcwd() .. "/.notes/ghosts.md"

    -- Open the markdown file in a vertical split
    vim.cmd('vsplit ' .. note_file)

    -- Search for the target line
    local target_line_num = 0
    local f = io.open(note_file, "r")
    if f then
        local current_line = 1
        for l in f:lines() do
            if l == target_header then
                target_line_num = current_line
                break
            end
            current_line = current_line + 1
        end
        f:close()
    end

    -- If we found it, move the cursor there and center the screen
    if target_line_num > 0 then
        vim.api.nvim_win_set_cursor(0, { target_line_num, 0 })
        vim.cmd('normal! zz') -- Center the screen on the cursor
    else
        vim.notify("No ghost note found for this line.", vim.log.levels.INFO)
    end
end

-- Live sync all buffers when the markdown file changes
function M.sync_all_buffers()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local full_path = vim.api.nvim_buf_get_name(bufnr)

            if full_path ~= "" and not string.match(full_path, "%.notes/ghosts%.md$") then
                vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

                local rel_path = vim.fn.fnamemodify(full_path, ":.")

                M.load_notes(bufnr, rel_path)
            end
        end
    end
end

-- FzfLua Integration
function M.search_notes()
    -- Safely require fzf-lua
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
        vim.notify("FzfLua is not installed!", vim.log.levels.ERROR)
        return
    end

    local notes = get_all_notes()
    if #notes == 0 then
        vim.notify("No ghost notes found in this project.", vim.log.levels.INFO)
        return
    end

    -- Format the notes into standard grep output so FzfLua understands them natively
    local fzf_entries = {}
    for _, note in ipairs(notes) do
        -- Format: filepath:row:column: text
        -- Hardcode column to 1 since we just want to jump to the line
        local entry = string.format("%s:%d:1: %s", note.filename, note.lnum, note.text)
        table.insert(fzf_entries, entry)
    end

    -- Launch FzfLua!
    fzf.fzf_exec(fzf_entries, {
        prompt = "👻 Ghosts> ",
        -- Treat strings like grep results
        previewer = "builtin",
        actions = {
            ["default"] = require("fzf-lua.actions").file_edit,
            ["ctrl-v"]  = require("fzf-lua.actions").file_vsplit,
            ["ctrl-x"]  = require("fzf-lua.actions").file_split,
            ["ctrl-t"]  = require("fzf-lua.actions").file_tabedit,
        }
    })
end

-- Toggle Zen Mode
function M.toggle_notes()
    is_enabled = not is_enabled

    if is_enabled then
        -- Bring them back using our existing sync function
        M.sync_all_buffers()
        vim.notify("Ghost Notes: ON", vim.log.levels.INFO)
    else
        -- Banish them from all open buffers
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(bufnr) then
                vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
            end
        end
        vim.notify("Ghost Notes: OFF (Zen Mode)", vim.log.levels.INFO)
    end
end

function M.setup()
    vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
            -- Add Note
            vim.keymap.set('n', '<leader>ka', M.add_note, { desc = "Add Ghost Note" })
            -- Delete Note
            vim.keymap.set('n', '<leader>kd', M.delete_note, { desc = "Delete Ghost Note" })
            -- Jump to Markdown
            vim.keymap.set('n', '<leader>kj', M.jump_to_note, { desc = "Jump to Ghost Note" })
            -- FzfLua picker
            vim.keymap.set('n', '<leader>ks', M.search_notes, { desc = "Search Ghost Notes" })
            -- Toggle notes
            vim.keymap.set('n', '<leader>kt', M.toggle_notes, { desc = "Toggle Ghost Notes" })
        end
    })

    local group = vim.api.nvim_create_augroup("GhostNotesGroup", { clear = true })
    vim.api.nvim_create_autocmd("BufReadPost", {
        group = group,
        callback = function()
            require('ghostnotes').load_notes()
        end,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*/.notes/ghosts.md",
        group = group,
        callback = function()
            require('ghostnotes').sync_all_buffers()
            vim.notify("Ghosts synced!", vim.log.levels.INFO)
        end,
    })
end

return M
