if vim.g.loaded_mdpick then
    return
end
vim.g.loaded_mdpick = true

vim.api.nvim_create_user_command('MdPick', function(command)
    local root = command.args ~= '' and command.args or nil
    require('mdpick').open(root)
end, {
    nargs = '?',
    complete = 'dir',
    desc = 'Find and preview Markdown files below a directory',
})

