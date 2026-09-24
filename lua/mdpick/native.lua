local terminal = require 'mdpick.terminal'

local M = {}

local function has_hidden_segment(path)
    for segment in path:gmatch '[^/\\]+' do
        if segment:sub(1, 1) == '.' then
            return true
        end
    end
    return false
end

---@param options MdPickConfig
---@param root string
---@return string[]
function M.find(options, root)
    local extensions = {}
    for _, extension in ipairs(options.extensions) do
        extensions[extension:lower()] = true
    end

    local function is_markdown(path)
        local extension = path:match '%.([^./\\]+)$'
        return extension and extensions[extension:lower()] and (options.hidden or not has_hidden_segment(path))
    end

    local files = {}
    local directories = { root }
    local visited = {}
    local index = 1

    while index <= #directories do
        local directory = directories[index]
        index = index + 1
        local identity = vim.uv.fs_realpath(directory) or vim.fs.normalize(directory)

        if not visited[identity] then
            visited[identity] = true
            for name, entry_type in vim.fs.dir(directory) do
                if options.hidden or not vim.startswith(name, '.') then
                    local path = vim.fs.joinpath(directory, name)
                    local resolved_type = entry_type

                    if entry_type == 'link' and options.follow then
                        local stat = vim.uv.fs_stat(path)
                        resolved_type = stat and stat.type or entry_type
                    end

                    if resolved_type == 'directory' then
                        table.insert(directories, path)
                    elseif resolved_type == 'file' and is_markdown(vim.fs.relpath(root, path) or path) then
                        table.insert(files, path)
                    end
                end
            end
        end
    end

    table.sort(files, function(left, right)
        return left:lower() < right:lower()
    end)
    return files
end

---@param path string
---@return table?
function M.preview(path)
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return nil
    end

    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].bufhidden = 'wipe'
    vim.bo[buffer].filetype = 'markdown'
    return { buf = buffer }
end

---@param options MdPickConfig
---@param root string
function M.open(options, root)
    local files = M.find(options, root)
    if #files == 0 then
        vim.notify('mdpick: no Markdown documents found below ' .. root, vim.log.levels.INFO)
        return
    end

    local select_options = {
        prompt = 'Markdown documents:',
        kind = 'file',
        format_item = function(path)
            return vim.fs.relpath(root, path) or path
        end,
    }

    if vim.fn.has 'nvim-0.12' == 1 then
        select_options.preview_item = M.preview
    end

    vim.ui.select(files, select_options, function(choice)
        if choice then
            terminal.open_document(options, choice)
        end
    end)
end

return M
