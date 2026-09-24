local config = require 'mdpick.config'
local native = require 'mdpick.native'
local terminal = require 'mdpick.terminal'

local M = {}

local minimum_neovim_version = '0.11'

---@param user_options? table
function M.setup(user_options)
    config.setup(user_options)
end

local function check_dependencies()
    local missing = {}
    local executables = { config.options.mdcat }

    if config.options.picker == 'fzf' then
        vim.list_extend(executables, { config.options.fd, config.options.fzf })
    end

    for _, executable in ipairs(executables) do
        if vim.fn.executable(executable) ~= 1 then
            table.insert(missing, executable)
        end
    end

    if #missing > 0 then
        vim.notify('mdpick: missing required executable(s): ' .. table.concat(missing, ', '), vim.log.levels.ERROR)
        return false
    end

    return true
end

---@param root? string
function M.open(root)
    if vim.fn.has('nvim-' .. minimum_neovim_version) ~= 1 then
        vim.notify('mdpick: Neovim ' .. minimum_neovim_version .. ' or newer is required', vim.log.levels.ERROR)
        return
    end

    if not check_dependencies() then
        return
    end

    root = vim.fn.fnamemodify(vim.fn.expand(root or vim.fn.getcwd()), ':p')
    if vim.fn.isdirectory(root) ~= 1 then
        vim.notify('mdpick: not a directory: ' .. root, vim.log.levels.ERROR)
        return
    end

    if config.options.picker == 'fzf' then
        terminal.open_picker(config.options, root)
        return
    end

    native.open(config.options, root)
end

return M
