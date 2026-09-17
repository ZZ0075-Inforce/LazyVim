return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- jdtls 需要 Java 21+，但 PATH 上的 java 是 1.8（legacy Maven 專案要用，見 mvn-j8），
      -- 不設 JAVA_HOME 也不改 PATH，只用 --java-executable 單獨指定給 jdtls。
      --
      -- 選 21 不選 24：JDK 22 起 zip64 檢查收緊，會拒絕 .m2 裡若干舊 jar
      -- （實測 aspectjweaver-1.8.2.jar → Invalid CEN header）。那個 jar 本身沒壞
      -- （unzip -t 通過），但 jdtls 一旦讀不到它，建 type hierarchy 就會拋
      -- ZipException，於是 lsp_implementations／lsp_type_definitions 靜靜回空結果。
      -- jdk-21 (21.0.2) 讀得動。
      local jdk = "C:/Program Files/Java/jdk-21/bin/java.exe"
      if vim.uv.fs_stat(jdk) then
        opts.cmd = opts.cmd or {}
        table.insert(opts.cmd, "--java-executable=" .. jdk)
      else
        vim.notify("jdtls: 找不到 " .. jdk .. "，將沿用 PATH 上的 java", vim.log.levels.WARN)
      end

      opts.settings = opts.settings or {}
      opts.settings.java = opts.settings.java or {}

      -- 跑 jdtls 的 JVM（上面的 --java-executable）和「拿來分析程式碼的 runtime」是兩回事。
      -- 前者被 jdtls 逼著用 21+；後者必須跟專案一致 = Java 8。
      -- 每個 repo 的 .classpath 都綁 JRE_CONTAINER/.../JavaSE-1.8，若這裡不註冊
      -- JavaSE-1.8，jdtls 會退回拿自己那顆 JDK 21 的類別庫解析——結果是
      -- List.of() / Optional.isEmpty() / var 這些 Java 9+ API 在編輯器裡不報錯，
      -- 等 mvn-j8 真的編譯才炸。設 default=true 是因為全 workspace 341 個 pom
      -- 沒有任何一個高於 1.8（330 個 1.8、9 個 1.7、2 個 1.6）。
      local jdk8 = "C:/Program Files/Java/jdk1.8.0_202"
      if vim.uv.fs_stat(jdk8 .. "/lib/tools.jar") then
        opts.settings.java.configuration = opts.settings.java.configuration or {}
        opts.settings.java.configuration.runtimes = {
          { name = "JavaSE-1.8", path = jdk8, default = true },
        }
      else
        vim.notify("jdtls: 找不到 JDK 8 於 " .. jdk8 .. "，將以 jdtls 自身的 JDK 解析（Java 9+ API 不會被擋）", vim.log.levels.WARN)
      end

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
