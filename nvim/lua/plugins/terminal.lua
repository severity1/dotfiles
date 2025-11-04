return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm direction=horizontal size=20<cr>", desc = "Toggle Terminal" },
      { "<C-\\>", "<C-\\><C-n><cmd>ToggleTerm<cr>", mode = "t", desc = "Toggle Terminal" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 20
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      shade_terminals = true,
      persist_size = true,
      persist_mode = true,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      close_on_exit = true,
      shell = vim.o.shell,
    },
  },
}
