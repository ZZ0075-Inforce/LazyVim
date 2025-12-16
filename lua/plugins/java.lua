return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      opts.settings = opts.settings or {}
      opts.settings.java = opts.settings.java or {}

      -- Enable downloading sources for Eclipse and Maven
      opts.settings.java.eclipse = opts.settings.java.eclipse or {}
      opts.settings.java.eclipse.downloadSources = true

      opts.settings.java.maven = opts.settings.java.maven or {}
      opts.settings.java.maven.downloadSources = true

      -- Enable decompiled sources if source is missing
      opts.settings.java.references = opts.settings.java.references or {}
      opts.settings.java.references.includeDecompiledSources = true

      opts.settings.java.inlayHints = {
        parameterNames = {
          enabled = "none",
        },
      }

      -- Override full_cmd to use existing Eclipse workspace
      opts.full_cmd = function(_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        local root_dir = _opts.root_dir(fname)
        local project_name = _opts.project_name(root_dir)
        local cmd = vim.deepcopy(_opts.cmd or {})

        if project_name then
          -- Since root_dir guarantees .metadata exists, we use it directly
          vim.list_extend(cmd, {
            "-configuration",
            _opts.jdtls_config_dir(project_name),
            "-data",
            root_dir, -- Use project root (containing .metadata) as workspace
          })
        end
        return cmd
      end

      -- Modify root_dir detection to ONLY support Eclipse workspace projects
      opts.root_dir = function(path)
        return vim.fs.root(path, { ".metadata" })
      end
    end,
  },
}
