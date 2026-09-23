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

      -- 不設 -Xmx 時 JVM 預設上限是實體記憶體的 1/4（本機 31.6G → 約 7.9G）。
      -- 索引檔一旦損壞，jdtls 會把索引裡的字串當成長度欄位讀，試圖配置 ~2GB 陣列，
      -- 於是一路吃到那個天花板才倒（實測單一實例 8557MB，機器只剩 5.8G 可用）。
      -- 4G 對穩定態綽綽有餘（實測索引完成後 215MB~1.07G），又能把失控時的爆炸半徑減半。
      opts.cmd = opts.cmd or {}
      table.insert(opts.cmd, "--jvm-arg=-Xmx4G")

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

      -- 刻意不用 nvim-jdtls 的 hotcodereplace = "auto"：自動替換交給 HotswapAgent
      -- （run-tomcat-dcevm.bat 的 autoHotswap），手動備援是 <leader>dh。兩邊都開會重複替換。
      -- opts.dap 必須保持非 nil，LazyVim 才會呼叫 setup_dap（extras/lang/java.lua）。
      opts.dap = opts.dap or {}
      opts.dap.hotcodereplace = nil

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

      -- Workspace 互斥：兩個 nvim 實例若同時把同一個 Eclipse workspace 當 -data，
      -- 會一起寫 .metadata/.plugins/org.eclipse.jdt.core/*.index 而互相踩踏，造成索引
      -- 錯位損壞——讀取時把索引裡的字串當成長度欄位（實測讀到 "unit"/"ingS" 這類片段
      -- 被解讀成 1.6~2.0GB），照著配置陣列就 OOM；jdtls 接著刪掉重建，又被另一個實例
      -- 踩壞，無限循環（LawNP 曾累積 20 次 index broken / 13 次 OOM）。
      --
      -- 沒有現成機制能擋：jdtls 根本不碰 Eclipse 的 .metadata/.lock（那個檔的 mtime
      -- 停在幾個月前，索引目錄卻是當天），而 nvim-jdtls 的 server 重用只在單一 nvim
      -- 實例內有效。所以只能自己在 start_or_attach 前面加一道 PID lock。
      --
      -- 已知限制：這只擋 nvim 之間。Eclipse IDE 開同一個 workspace 一樣會踩
      -- （eclipse.jdt.ls#3370 至今未解），但它用的是 Java FileLock，Lua 這邊沒有
      -- 可靠又非破壞性的偵測手段，只能自己留意。
      local function data_dir_of(cmd)
        for i, v in ipairs(cmd or {}) do
          if v == "-data" then
            return cmd[i + 1]
          end
        end
      end

      local function lock_file(data_dir)
        return vim.fs.joinpath(data_dir, ".nvim-jdtls-owner.lock")
      end

      local function read_lock_pid(data_dir)
        local f = io.open(lock_file(data_dir), "r")
        if not f then
          return nil
        end
        local pid = tonumber(f:read("*l"))
        f:close()
        return pid
      end

      -- 有「其他還活著的」nvim 持有這個 workspace 就回傳它的 PID。
      -- 鎖檔存在但 PID 已消失（nvim 被強制關閉）視為過期，直接接手。
      local function lock_holder(data_dir)
        local pid = read_lock_pid(data_dir)
        if not pid or pid == vim.uv.os_getpid() then
          return nil
        end
        -- signal 0 只做存在性檢查，不會真的送訊號。
        -- luv 失敗時回 nil（而非 error），所以兩種情況都要判。
        local called, res = pcall(vim.uv.kill, pid, 0)
        if not called or res == nil then
          return nil
        end
        return pid
      end

      local held = {}
      local notified = {}

      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "釋放本實例持有的 jdtls workspace 鎖",
        callback = function()
          local me = vim.uv.os_getpid()
          for dir in pairs(held) do
            if read_lock_pid(dir) == me then
              os.remove(lock_file(dir))
            end
          end
        end,
      })

      local ok, jdtls = pcall(require, "jdtls")
      if not ok then
        vim.notify("jdtls: 無法載入 jdtls 模組，workspace 互斥保護未啟用", vim.log.levels.WARN)
      elseif not jdtls.__nvim_ws_guard then
        local start_or_attach = jdtls.start_or_attach
        jdtls.start_or_attach = function(config, ...)
          local data_dir = data_dir_of(config and config.cmd)
          -- 正規化後才拿來當 held/notified 的 key：-data 可能來自 vim.fs.root（root_dir）
          -- 或 stdpath("cache")，Windows 上兩者的斜線風格未必一致，不統一會讓去重與
          -- VimLeavePre 的清理對不上同一個 workspace。
          data_dir = data_dir and vim.fs.normalize(data_dir) or nil
          -- 兩種模式都要擋：Eclipse workspace 固然會撞，fallback 的 cache workspace
          -- （cache/jdtls/<project_name>/workspace）只隔離「不同專案」，同一專案開兩個
          -- nvim 仍然解析到同一路徑，一樣會並行寫索引。
          if data_dir then
            vim.fn.mkdir(data_dir, "p") -- 放鎖檔用；jdtls 本來也會建這個目錄
            local holder = lock_holder(data_dir)
            if holder then
              -- LazyVim 會直接呼叫一次再掛 FileType autocmd，之後每開一個 java 檔都會
              -- 再進來一次，所以同一個 workspace 只通知一次，否則洗版。
              if not notified[data_dir] then
                notified[data_dir] = true
                -- cache workspace 的 basename 固定是 "workspace"，認不出專案，改用 root_dir
                local label = config.root_dir and vim.fs.basename(config.root_dir) or data_dir
                vim.notify(
                  ("jdtls: %s 已被另一個 nvim (PID %d) 持有，本視窗不啟動 Java LSP。\n同時開兩個會並行寫索引，會寫壞索引並導致 OOM。"):format(
                    label,
                    holder
                  ),
                  vim.log.levels.WARN
                )
              end
              return
            end
            local f = io.open(lock_file(data_dir), "w")
            if f then
              f:write(tostring(vim.uv.os_getpid()), "\n")
              f:close()
              held[data_dir] = true
            end
          end
          return start_or_attach(config, ...)
        end
        jdtls.__nvim_ws_guard = true
      end
    end,
  },
  {
    -- attach 到外部 Tomcat 的 JPDA（devdeploy/LawPL/run-tomcat.bat，port 5005）。
    --
    -- LazyVim java extra 內建的 attach 設定沒有帶 projectName，java-debug 的
    -- JdtSourceLookUpProvider 於是無法把「原始檔路徑」對回 class 的完整名稱，
    -- setBreakpoints 一律回 verified=false 而且永遠不再送 breakpoint 事件——
    -- 表現就是中斷點卡在紅色驚嘆號（BreakpointRejected）、操作 UI 不會停。
    -- 實測不是 class 沒載入：jcmd GC.class_histogram 看得到 PLPSIPOService 已載入。
    --
    -- projectName 要填「中斷點所在原始檔的 Eclipse 專案名」，故兩個專案各給一組，
    -- attach 時依你要下中斷點的位置選。
    "mfussenegger/nvim-dap",
    optional = true,
    -- 手動觸發熱抽換。nvim-jdtls 的 :JdtUpdateHotcode 只在 jdtls attach 後才存在，
    -- 且失敗時是 assert 噴 stack trace，所以這裡直接送 DAP request 並自己處理錯誤。
    -- 需要 debug session 連著（<leader>dc attach），但不需要停在中斷點。
    keys = {
      {
        "<leader>dh",
        function()
          local session = require("dap").session()
          if not session then
            vim.notify("沒有 debug session，先用 <leader>dc attach 到 Tomcat 5005", vim.log.levels.WARN)
            return
          end
          vim.notify("Applying code changes...")
          session:request("redefineClasses", nil, function(err)
            if err then
              vim.notify("Hot code replace 失敗：" .. vim.inspect(err), vim.log.levels.ERROR)
            else
              vim.notify("Hot code replace 完成")
            end
          end)
        end,
        desc = "Hot Code Replace (Java)",
      },
    },
    opts = function()
      local dap = require("dap")
      local function attach(project)
        return {
          type = "java",
          request = "attach",
          name = "Attach Tomcat 5005 (" .. project .. ")",
          hostName = "127.0.0.1",
          port = 5005,
          projectName = project,
        }
      end
      dap.configurations.java = {
        attach("Law-Model"),
        attach("LawPL"),
      }
    end,
  },
}
