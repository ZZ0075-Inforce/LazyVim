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

      -- Override full_cmd: Eclipse workspace roots reuse the workspace itself as -data
      -- (keeps existing project imports / JRE mappings); fallback roots use the default
      -- cache workspace so no .metadata gets created inside a git repo
      opts.full_cmd = function(_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        local root_dir = _opts.root_dir(fname)
        local project_name = _opts.project_name(root_dir)
        local cmd = vim.deepcopy(_opts.cmd or {})

        if project_name then
          local is_eclipse_ws = vim.uv.fs_stat(vim.fs.joinpath(root_dir, ".metadata")) ~= nil
          vim.list_extend(cmd, {
            "-configuration",
            _opts.jdtls_config_dir(project_name),
            "-data",
            is_eclipse_ws and root_dir or _opts.jdtls_workspace_dir(project_name),
          })
        end
        return cmd
      end

      -- Root detection: prefer the Eclipse workspace (.metadata) so cross-repo
      -- references resolve against workspace sources; fall back to the default
      -- root markers (pom.xml/.git/...) for plain Maven checkouts
      local default_root_dir = opts.root_dir
      opts.root_dir = function(path)
        return vim.fs.root(path, { ".metadata" }) or (default_root_dir and default_root_dir(path)) or nil
      end
    end,
  },
}
