local M = {}

---@class MdPickConfig
---@field picker 'native'|'fzf' Picker backend.
---@field width number Fraction of the editor width used by the floating window.
---@field height number Fraction of the editor height used by the floating window.
---@field border string|string[] Floating-window border accepted by nvim_open_win().
---@field hidden boolean Include hidden files and directories.
---@field follow boolean Follow symbolic links while finding Markdown files.
---@field extensions string[] Markdown filename extensions without leading dots.
---@field preview_window string fzf --preview-window value.
---@field fd string fd executable name or path.
---@field fzf string fzf executable name or path.
---@field mdcat string mdcat executable name or path.

---@type MdPickConfig
local defaults = {
    picker = 'native',
    width = 0.9,
    height = 0.9,
    border = 'rounded',
    hidden = false,
    follow = false,
    extensions = { 'md', 'markdown' },
    preview_window = 'right,80%,wrap',
    fd = 'fd',
    fzf = 'fzf',
    mdcat = 'mdcat',
}

---@type MdPickConfig
M.options = vim.deepcopy(defaults)

local function validate_fraction(name, value)
    if type(value) ~= 'number' or value <= 0 or value > 1 then
        error(('mdpick: %s must be a number greater than 0 and at most 1'):format(name))
    end
end

---@param options MdPickConfig
local function validate(options)
    if options.picker ~= 'native' and options.picker ~= 'fzf' then
        error "mdpick: picker must be 'native' or 'fzf'"
    end

    validate_fraction('width', options.width)
    validate_fraction('height', options.height)

    for _, name in ipairs { 'hidden', 'follow' } do
        if type(options[name]) ~= 'boolean' then
            error(('mdpick: %s must be a boolean'):format(name))
        end
    end

    if type(options.border) ~= 'string' and type(options.border) ~= 'table' then
        error 'mdpick: border must be a string or table accepted by nvim_open_win()'
    end

    if type(options.extensions) ~= 'table' or #options.extensions == 0 then
        error 'mdpick: extensions must be a non-empty list'
    end

    for _, extension in ipairs(options.extensions) do
        if type(extension) ~= 'string' or extension == '' then
            error 'mdpick: each extension must be a non-empty string'
        end
    end

    for _, name in ipairs { 'fd', 'fzf', 'mdcat', 'preview_window' } do
        if type(options[name]) ~= 'string' or options[name] == '' then
            error(('mdpick: %s must be a non-empty string'):format(name))
        end
    end
end

---@param user_options? table
---@return MdPickConfig
function M.setup(user_options)
    local options = vim.tbl_deep_extend('force', vim.deepcopy(defaults), user_options or {})
    validate(options)
    M.options = options
    return M.options
end

return M
