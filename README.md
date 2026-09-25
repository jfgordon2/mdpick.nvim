# mdpick.nvim

Find Markdown files recursively and read their rendered `mdcat` output without leaving Neovim.

By default, `mdpick.nvim` discovers documents with Neovim's filesystem API and presents them through `vim.ui.select`. A UI provider configured to override `vim.ui.select` can supply a richer interface. Selecting a document opens its rendered `mdcat` output in a floating terminal.

An optional `fzf` backend ensures a picker with a live `mdcat` preview.

## Requirements

- Neovim 0.11 or newer
- [`mdcat`](https://github.com/BIRSAx2/mdcat)
- Optional `fzf` backend: [`fd`](https://github.com/sharkdp/fd) and
  [`fzf`](https://github.com/junegunn/fzf)

## Installation

### vim.pack

Neovim 0.12 includes the native `vim.pack` plugin manager. Add this to your `init.lua`:

```lua
vim.pack.add({
    'https://github.com/jfgordon2/mdpick.nvim',
})

require('mdpick').setup()

vim.keymap.set('n', '<leader>md', '<cmd>MdPick<cr>', {
    desc = 'Pick Markdown document',
})
```

On the first run, confirm the installation when prompted. `vim.pack.add()` installs the repository if necessary and loads it in the current session. See [A Guide to vim.pack][vim-pack-guide] and `:help vim.pack` for package management and update workflows.

### lazy.nvim

```lua
{
    'jfgordon2/mdpick.nvim',
    opts = {},
    keys = {
        { '<leader>md', '<cmd>MdPick<cr>', desc = 'Pick Markdown document' },
    },
}
```

### packer.nvim

```lua
use {
    'jfgordon2/mdpick.nvim',
    config = function()
        require('mdpick').setup()
    end,
}
```

## Usage

Search below Neovim's current working directory:

```vim
:MdPick
```

Search below another directory:

```vim
:MdPick ~/notes
```

The default `native` backend uses `vim.ui.select`. Its appearance and key bindings come from Neovim or a provider you have configured to override that function. Neovim's built-in selector does not provide fuzzy matching or previews. Telescope requires an integration such as `telescope-ui-select.nvim`; Snacks, fzf-lua, and dressing.nvim likewise need their `vim.ui.select` integration enabled.

After selecting a document, quit the `mdcat` pager with `q` to close its floating window.

## Configuration

The defaults are:

```lua
require('mdpick').setup {
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
```

### Options

#### `picker`

Type: `'native'` or `'fzf'`. Default: `'native'`.

Selects the picker backend. `native` uses `vim.fs` and `vim.ui.select`. `fzf` runs `fd` and `fzf` in a floating terminal.

#### `width`

Type: number greater than `0` and at most `1`. Default: `0.9`.

Sets the fraction of Neovim's columns used by the floating `mdcat` window and the `fzf` picker.

#### `height`

Type: number greater than `0` and at most `1`. Default: `0.9`.

Sets the fraction of Neovim's available lines used by the floating `mdcat` window and the `fzf` picker.

#### `border`

Type: border string or table accepted by `nvim_open_win()`. Default: `'rounded'`.

Controls the floating-window border. Common strings are `'none'`, `'single'`, `'double'`, `'rounded'`, `'solid'`, and `'shadow'`.

#### `hidden`

Type: boolean. Default: `false`.

Includes hidden files and directories when `true`. With `fzf`, ignore files still apply because `fd --hidden` does not disable ignore processing.

#### `follow`

Type: boolean. Default: `false`.

Follows symbolic links when `true`. Native traversal deduplicates resolved directories to prevent symlink cycles.

#### `extensions`

Type: non-empty list of non-empty strings. Default: `{ 'md', 'markdown' }`.

Specifies filename extensions without leading dots. Matching is case-insensitive in the native backend. The `fzf` backend passes each value to `fd --extension`.

#### `preview_window`

Type: non-empty string accepted by `fzf --preview-window`. Default: `'right,80%,wrap'`.

Controls live-preview position, size, and wrapping for the `fzf` backend. The native backend ignores this option.

#### `fd`

Type: non-empty executable name or path. Default: `'fd'`.

Selects the `fd` executable used by the `fzf` backend. The native backend ignores this option.

#### `fzf`

Type: non-empty executable name or path. Default: `'fzf'`.

Selects the `fzf` executable used by the `fzf` backend. The native backend ignores this option.

#### `mdcat`

Type: non-empty executable name or path. Default: `'mdcat'`.

Selects the Markdown renderer. Both backends require this executable.

The native backend uses `vim.fs.dir` and does not interpret `.gitignore`, `.ignore`, or `.fdignore` files. It skips hidden paths unless `hidden = true`.

### fzf backend

Set `picker = 'fzf'` to use the configured floating picker with preview:

```lua
require('mdpick').setup {
    picker = 'fzf',
}
```

The `fzf` backend provides fuzzy filtering and a live rendered preview. Its `fd` search respects `.gitignore`, `.ignore`, and `.fdignore` by default. Filenames containing spaces, quotes, leading dashes, or newlines are supported.

## Development

```shell
make test
make lint
```

## License

MIT

[vim-pack-guide]: https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
