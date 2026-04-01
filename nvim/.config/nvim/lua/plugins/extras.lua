-- =============================================================================
-- Language extras — cada import instala automáticamente LSP, formatter,
-- linter y treesitter grammar del lenguaje
-- https://www.lazyvim.org/extras
-- =============================================================================

return {
  -- JavaScript / TypeScript / React
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- Python
  { import = "lazyvim.plugins.extras.lang.python" },

  -- Go
  { import = "lazyvim.plugins.extras.lang.go" },

  -- Rust
  { import = "lazyvim.plugins.extras.lang.rust" },

  -- JSON (schemas, validation)
  { import = "lazyvim.plugins.extras.lang.json" },

  -- YAML
  { import = "lazyvim.plugins.extras.lang.yaml" },

  -- Docker (Dockerfile, docker-compose)
  { import = "lazyvim.plugins.extras.lang.docker" },

  -- Tailwind CSS
  { import = "lazyvim.plugins.extras.lang.tailwind" },

  -- Markdown
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- Formatting (prettier para JS/TS/CSS/HTML/JSON)
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- Linting (eslint para JS/TS)
  { import = "lazyvim.plugins.extras.linting.eslint" },
}
