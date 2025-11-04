return {
  -- LazyVim extras (must be imported first)
  -- TypeScript/JavaScript
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- Python
  { import = "lazyvim.plugins.extras.lang.python" },

  -- Go
  { import = "lazyvim.plugins.extras.lang.go" },

  -- Rust
  { import = "lazyvim.plugins.extras.lang.rust" },

  -- Terraform and related IaC tools
  { import = "lazyvim.plugins.extras.lang.terraform" },

  -- Markdown
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- Shell/Bash (via dotfiles extra)
  { import = "lazyvim.plugins.extras.util.dot" },

  -- Custom plugin configurations below

  -- Catppuccin colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },

  -- Claude Code integration
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    opts = {
      terminal_cmd = "~/.claude/local/claude",
      terminal = {
        split_side = "right",
        split_width_percentage = 0.30,
        provider = "auto",
        auto_close = true,
      },
    },
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude Code" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude Model" },
      { "<leader>aS", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send Selection to Claude" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add Buffer to Claude Context" },
      { "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add file from tree", ft = { "snacks_explorer" } },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },

  -- Snacks explorer with auto-open
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

  -- Terminal
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

  -- Additional LSP configurations
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Ensure basedpyright for Python (modern replacement for pyright)
        basedpyright = {},

        -- Additional tools for infrastructure as code
        tflint = {},
      },
    },
  },

  -- Mason tool installer
  {
    "mason-org/mason.nvim",
    opts = {
      max_concurrent_installers = 1,
      ensure_installed = {
        -- TypeScript/JavaScript
        "typescript-language-server",
        "eslint-lsp",
        "prettier",

        -- Python
        "basedpyright",
        "ruff",
        "black",

        -- Go
        "gopls",
        "gofumpt",
        "goimports",

        -- Rust
        "rust-analyzer",

        -- Terraform
        "terraform-ls",
        "tflint",

        -- Markdown
        "marksman",

        -- Shell/Bash
        "bash-language-server",
        "shellcheck",
        "shfmt",
      },
    },
  },
}
