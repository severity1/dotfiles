-- Configure Snacks explorer with auto-open
return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        enabled = true,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        pattern = "*",
        once = true,
        callback = function()
          vim.defer_fn(function()
            require("snacks").explorer()
          end, 50)
        end,
      })
    end,
  },
}
