return {
    'romgrk/barbar.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    init = function()
        vim.g.barbar_auto_setup = false
    end,
    opts = {
        animation = false,
        clickable = true,
        tabpages = true,
        insert_at_end = true,
        auto_hide = 1,
        maximum_padding = 1,
        minimum_padding = 1,
        icons = {
            filetype = {
                enabled = true,
            },
        },
    },
    version = '^1.0.0',
}
