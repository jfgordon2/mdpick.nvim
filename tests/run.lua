local failures = 0

local function test(name, callback)
    local ok, message = pcall(callback)
    if ok then
        print('PASS ' .. name)
        return
    end

    failures = failures + 1
    print('FAIL ' .. name .. ': ' .. message)
end

local function assert_equal(expected, actual)
    if not vim.deep_equal(expected, actual) then
        error(('expected %s, got %s'):format(vim.inspect(expected), vim.inspect(actual)))
    end
end

local function hex(value)
    return (value:gsub('.', function(character)
        return ('%02x'):format(character:byte())
    end))
end

test('setup merges options with defaults', function()
    local config = require 'mdpick.config'
    local options = config.setup { hidden = true, extensions = { 'mdx' } }

    assert_equal(true, options.hidden)
    assert_equal({ 'mdx' }, options.extensions)
    assert_equal('native', options.picker)
    assert_equal('fzf', options.fzf)
end)

test('setup rejects invalid dimensions', function()
    local config = require 'mdpick.config'
    local ok, message = pcall(config.setup, { width = 2 })

    assert_equal(false, ok)
    assert(message:match('width must be'))
end)

test('setup rejects invalid boolean options', function()
    local config = require 'mdpick.config'
    local ok, message = pcall(config.setup, { hidden = 'false' })

    assert_equal(false, ok)
    assert(message:match('hidden must be a boolean'))
end)

test('setup rejects an invalid picker', function()
    local config = require 'mdpick.config'
    local ok, message = pcall(config.setup, { picker = 'telescope' })

    assert_equal(false, ok)
    assert(message:match('picker must be'))
end)

test('native finder discovers Markdown and skips hidden paths', function()
    local config = require 'mdpick.config'
    local native = require 'mdpick.native'
    local directory = vim.fn.tempname()

    vim.fn.mkdir(directory .. '/notes', 'p')
    vim.fn.mkdir(directory .. '/.hidden', 'p')
    vim.fn.writefile({ '# root' }, directory .. '/README.md')
    vim.fn.writefile({ '# nested' }, directory .. '/notes/guide.MARKDOWN')
    vim.fn.writefile({ 'ignore' }, directory .. '/notes/plain.txt')
    vim.fn.writefile({ '# hidden' }, directory .. '/.hidden/private.md')

    local visible = native.find(config.setup(), directory)
    assert_equal({ directory .. '/notes/guide.MARKDOWN', directory .. '/README.md' }, visible)

    local all = native.find(config.setup { hidden = true }, directory)
    assert_equal({ directory .. '/.hidden/private.md', directory .. '/notes/guide.MARKDOWN', directory .. '/README.md' }, all)
end)

test('native finder follows file links without traversing directory cycles', function()
    local config = require 'mdpick.config'
    local native = require 'mdpick.native'
    local directory = vim.fn.tempname()
    local documents = directory .. '/documents'

    vim.fn.mkdir(documents, 'p')
    vim.fn.writefile({ '# target' }, documents .. '/target.md')
    assert(vim.uv.fs_symlink(documents .. '/target.md', directory .. '/linked.md'))
    assert(vim.uv.fs_symlink(directory, documents .. '/loop', { dir = true }))

    local files = native.find(config.setup { follow = true }, directory)
    assert_equal({ documents .. '/target.md', directory .. '/linked.md' }, files)
end)

test('native picker delegates selection to vim.ui.select', function()
    local config = require 'mdpick.config'
    local native = require 'mdpick.native'
    local terminal = require 'mdpick.terminal'
    local directory = vim.fn.tempname()
    local document = directory .. '/README.md'
    local selected
    local original_select = vim.ui.select
    local original_open_document = terminal.open_document

    vim.fn.mkdir(directory, 'p')
    vim.fn.writefile({ '# test' }, document)
    vim.ui.select = function(items, options, on_choice)
        assert_equal({ document }, items)
        assert_equal('README.md', options.format_item(document))
        on_choice(items[1])
    end
    terminal.open_document = function(_, path)
        selected = path
    end

    local ok, message = pcall(native.open, config.setup(), directory)
    vim.ui.select = original_select
    terminal.open_document = original_open_document

    assert(ok, message)
    assert_equal(document, selected)
end)

test('command contains finder, preview, and pager actions', function()
    local config = require 'mdpick.config'
    local terminal = require 'mdpick.terminal'
    local command = terminal.command(config.setup { hidden = true, follow = true })

    assert(command:find("'fd' '--type' 'f' '--print0' '--hidden' '--follow'", 1, true))
    assert(command:find("'--read0'", 1, true))
    assert(command:find('--columns="$FZF_PREVIEW_COLUMNS"', 1, true))
    assert(command:find('--paginate -- {}', 1, true))
end)

test('finder preserves unusual filenames as null-delimited candidates', function()
    local config = require 'mdpick.config'
    local terminal = require 'mdpick.terminal'
    local directory = vim.fn.tempname()
    local fake_fzf = directory .. '/fake-fzf'
    local capture = directory .. '/capture.hex'
    local filenames = { 'with spaces.md', "single'quote.md", '--help.md', 'line\nbreak.md' }

    vim.fn.mkdir(directory, 'p')
    for _, filename in ipairs(filenames) do
        vim.fn.writefile({ '# test' }, directory .. '/' .. filename)
    end
    vim.fn.writefile({ '#!/bin/sh', [[od -An -tx1 | tr -d ' \n' > "$MDPICK_CAPTURE"]] }, fake_fzf)
    vim.fn.setfperm(fake_fzf, 'rwx------')

    local old_capture = vim.env.MDPICK_CAPTURE
    vim.env.MDPICK_CAPTURE = capture
    local options = config.setup { fzf = fake_fzf }
    local command = ('cd %s && %s'):format(vim.fn.shellescape(directory), terminal.command(options))
    local output = vim.fn.system(command)
    vim.env.MDPICK_CAPTURE = old_capture

    assert_equal(0, vim.v.shell_error)
    assert_equal('', output)
    local captured = table.concat(vim.fn.readfile(capture), '')
    for _, filename in ipairs(filenames) do
        assert(captured:find(hex(filename .. '\0'), 1, true), 'missing filename: ' .. vim.inspect(filename))
    end
end)

test('plugin command is registered', function()
    vim.cmd.runtime 'plugin/mdpick.lua'
    assert_equal(2, vim.fn.exists ':MdPick')
end)

test('terminal launcher starts a terminal job without termopen', function()
    local config = require 'mdpick.config'
    local terminal = require 'mdpick.terminal'
    local options = config.setup { fd = 'printf', fzf = 'true', mdcat = 'true' }
    local job = terminal.open_picker(options, vim.fn.getcwd())
    local status = vim.fn.jobwait({ job }, 1000)[1]

    assert(job > 0)
    assert(status ~= -1, 'terminal job did not exit before the timeout')
    assert_equal('terminal', vim.bo.buftype)
end)

test('selected document opens in an mdcat terminal', function()
    local config = require 'mdpick.config'
    local terminal = require 'mdpick.terminal'
    local document = vim.fn.tempname() .. '.md'
    local options = config.setup { mdcat = 'true' }

    vim.fn.writefile({ '# test' }, document)
    local job = terminal.open_document(options, document)
    local status = vim.fn.jobwait({ job }, 1000)[1]

    assert(job > 0)
    assert_equal(0, status)
    assert_equal('terminal', vim.bo.buftype)
end)

if failures > 0 then
    vim.cmd('cquit ' .. failures)
end

print('All tests passed')
vim.cmd 'quit'
