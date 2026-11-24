return {
  'stevearc/oil.nvim',
  opts = {},
  -- Optional dependencies
  dependencies = { { 'nvim-mini/mini.icons', opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  config = function()
    require('oil').setup {
      win_options = {
        signcolumn = 'yes',
        list = true,
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name, _) return name == '.git' or name == '..' end,
      },
    }
    vim.keymap.set('n', '<leader>oo', '<Cmd>Oil<CR>', { desc = '[O]pen [O]il' })
  end,
}
