local M = {}

local function shell_join(parts)
    return table.concat(vim.tbl_map(vim.fn.shellescape, parts), ' ')
end

---@param options MdPickConfig
---@return string
function M.command(options)
    local find = { options.fd, '--type', 'f', '--print0' }

    if options.hidden then
        table.insert(find, '--hidden')
    end
    if options.follow then
        table.insert(find, '--follow')
    end
    for _, extension in ipairs(options.extensions) do
        vim.list_extend(find, { '--extension', extension })
    end
    table.insert(find, '.')

    local mdcat = vim.fn.shellescape(options.mdcat)
    local preview = ('%s --ansi --columns="$FZF_PREVIEW_COLUMNS" -- {}'):format(mdcat)
    local open = ('enter:execute(%s --paginate -- {})'):format(mdcat)
    local picker = {
        options.fzf,
        '--layout=reverse',
        '--read0',
        '--border',
        '--prompt=Markdown> ',
        '--preview',
        preview,
        '--preview-window',
        options.preview_window,
        '--bind',
        open,
    }

    return shell_join(find) .. ' | ' .. shell_join(picker)
end

---@param options MdPickConfig
---@param root string
---@param command string|string[]
---@param title string
---@return integer job
local function open(options, root, command, title)
    local editor_height = math.max(1, vim.o.lines - vim.o.cmdheight)
    local width = math.max(1, math.min(vim.o.columns - 2, math.floor(vim.o.columns * options.width)))
    local height = math.max(1, math.min(editor_height - 2, math.floor(editor_height * options.height)))
    local row = math.max(0, math.floor((editor_height - height) / 2))
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))
    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_open_win(buffer, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = options.border,
        title = ' ' .. title .. ' ',
        title_pos = 'center',
    })

    vim.bo[buffer].bufhidden = 'wipe'
    vim.wo[window].winhl = 'Normal:NormalFloat,FloatBorder:FloatBorder'

    vim.api.nvim_create_autocmd('TermClose', {
        buffer = buffer,
        once = true,
        callback = function()
            vim.schedule(function()
                if vim.api.nvim_win_is_valid(window) then
                    vim.api.nvim_win_close(window, true)
                end
            end)
        end,
    })

    local job = vim.fn.jobstart(command, { cwd = root, term = true })
    if job <= 0 then
        vim.api.nvim_win_close(window, true)
        error('mdpick: failed to start the picker terminal')
    end

    vim.cmd.startinsert()
    return job
end

---@param options MdPickConfig
---@param root string
---@return integer job
function M.open_picker(options, root)
    return open(options, root, M.command(options), 'mdpick')
end

---@param options MdPickConfig
---@param path string
---@return integer job
function M.open_document(options, path)
    return open(options, vim.fs.dirname(path), { options.mdcat, '--paginate', '--', path }, vim.fs.basename(path))
end

return M
