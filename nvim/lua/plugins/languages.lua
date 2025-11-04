return {
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
    "williamboman/mason.nvim",
    opts = {
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

        -- General
        "shellcheck",
        "shfmt",
      },
    },
  },
}
