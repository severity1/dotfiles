return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
      { "<C-\\>", "<C-\\><C-n><cmd>ToggleTerm<cr>", mode = "t", desc = "Toggle Terminal" },
    },
    opts = {
      size = 20,
      direction = "horizontal",
      open_mapping = [[<C-\>]],
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
