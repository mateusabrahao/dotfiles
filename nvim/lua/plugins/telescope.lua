return {
  'nvim-telescope/telescope.nvim',

  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
    },
  },

  config = function()
    local telescope = require('telescope')
    local actions = require('telescope.actions')

    telescope.setup({
      defaults = {
        wrap_results = true,
        mappings = {
          i = {
            ['<Esc>'] = actions.close,
            ['<C-Down>'] = actions.cycle_history_next,
            ['<C-Up>'] = actions.cycle_history_prev,
          },
        },
        layout_strategy = 'vertical',
        layout_config = {
          vertical = {
            width = 0.9,
            preview_cutoff = 10,
          },
        },
      },

      pickers = {
        lsp_references = { wrap_results = true },
        lsp_definitions = { wrap_results = true },
        diagnostics = { wrap_results = true },
        find_files = { wrap_results = true },
        buffers = {
          sort_mru = true,
          ignore_current_buffer = true,
        },
      },
    })

    telescope.load_extension('fzf')
  end,

  keys = {
    {
      '<leader>fo',
      function()
        require('telescope.builtin').oldfiles({
          prompt_title = 'Recent files',
          sort_mru = true,
        })
      end,
      desc = 'Recent files',
    },
    { '<leader><space>', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
    { '<leader>b', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
    { '<leader>p', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
    { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find files' },
    { '<leader>fm', '<cmd>Telescope marks<cr>', desc = 'Marks' },
    { '<leader>fw', '<cmd>Telescope live_grep<cr>', desc = 'Search files' },
    { '<leader>ld', '<cmd>Telescope diagnostics<cr>', desc = 'Diagnostics' },

    {
      '<leader>fb',
      function()
        require('telescope.builtin').live_grep({
          prompt_title = 'Grep open files',
          grep_open_files = true,
        })
      end,
      desc = 'Search open files',
    },

    {
      '<leader>fc',
      function()
        require('telescope.builtin').current_buffer_fuzzy_find()
      end,
      desc = 'Search current file',
    },

    {
      '<leader>:',
      function()
        require('telescope.builtin').command_history({
          prompt_title = 'Command history',
        })
      end,
      desc = 'Command history',
    },

    {
      '<leader>ls',
      function()
        local aerial_avail = pcall(require, 'aerial')

        if aerial_avail then
          require('telescope').extensions.aerial.aerial()
        else
          require('telescope.builtin').lsp_document_symbols()
        end
      end,
      desc = 'Search symbols',
    },
  },
}
