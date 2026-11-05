return {
  'rebelot/heirline.nvim',
  event = 'UiEnter',
  config = function()
    local conditions = require("heirline.conditions")

    -- colors
    local colors = {
      bg         = '#3c3836',
      fg         = '#c8bfb3',
      mode_text  = '#232326',
      normal     = '#b8bb26',
      insert     = '#e2422f',
      visual     = '#fabd2f',
      errors     = '#f14834',
      warnings   = '#e3ac31',
      info       = '#83a598',
      filename   = '#c8bfb3', -- or #8faea2
      branch     = '#d3869b',
      inactive   = '#73675d',
      removed    = '#e2422f',
      added      = '#a6a822',
      changed    = '#e1aa2a',
    }

    require("heirline").load_colors(colors)

    -- modes
    local ModeNames = {
        n = "NORMAL",
        i = "INSERT",
        v = "VISUAL",
        V = "V-LINE",
        [string.char(22)] = "V-BLOCK",
        c = "COMMAND",
        R = "REPLACE",
    }

    local Mode = {
      init = function(self)
        self.mode = vim.fn.mode(1)
      end,
      provider = function(self)
          local mode = ModeNames[self.mode] or self.mode:upper()
          return " " .. mode .. " "
      end,
      hl = function(self)
        local mode = self.mode
        local bg_color = "normal"

        if mode == "i" then
          bg_color = "insert"
        elseif mode == "v" or mode == "V" or mode == string.char(22) then
          bg_color = "visual"
        elseif mode == "R" or mode == "r" then
          bg_color = "insert"
        elseif mode == "c" then
          bg_color = "normal"
        end

        return { fg = bg_color, bg = "bg", bold = true }
      end,
      update = {
        "ModeChanged",
        "FileType",
        pattern = "*:*",
        callback = vim.schedule_wrap(function()
          vim.cmd("redrawstatus")
        end),
      },
    }
    -- character count indicator
    local FileSize = {
      condition = function() return vim.bo.filetype ~= "alpha" end,
      provider = function()
        local bytes = vim.fn.wordcount().bytes
        if bytes < 1000 then
          return "" .. bytes .. " "
        elseif bytes < 1000000 then
          return string.format("%.1fk ", bytes / 1000)
        else
          return string.format("%.1fM ", bytes / 1000000)
        end
      end,
      hl = { fg = "fg", bold = true },
      update = { "FileType" },
    }

    -- file name 
    local FileName = {
      init = function(self)
        self.filename = vim.api.nvim_buf_get_name(0)

        if self.filename == "" or vim.bo.filetype == "alpha" then
            self.filename = "[No Name]"
            self.icon = nil
            self.icon_color = ""
            return
        end    
        self.filename = vim.fn.fnamemodify(self.filename, ":.")
        local basename = vim.fn.fnamemodify(self.filename, ":t")
        local extension = vim.fn.fnamemodify(basename, ":e")

        self.icon, self.icon_color = require("nvim-web-devicons").get_icon_color(
          basename, extension, { default = true }
        )
      end,
    
      {
        provider = function(self)
          if vim.bo.filetype == "alpha" then return "" end
          return self.icon and self.icon ~= "" and (self.icon .. " ") or ""
        end,
        hl = function(self)
          return { fg = self.icon_color }
        end
      },
    
      {
        provider = function(self)
            if self.filename == "[No Name]" or vim.bo.filetype == "alpha" then
                return "[No Name]"
            end

          local filepath = self.filename
          local api = require("nvim-tree.api")
    
          if api.tree.is_visible() then
            local nodes = api.tree.get_nodes()
            local root = nodes and nodes.absolute_path
    
            if root then
              local absolute = vim.fn.fnamemodify(
                vim.api.nvim_buf_get_name(0), ":p"
              )
              root = vim.fn.fnamemodify(root, ":p")
    
              local prefix = root:gsub("/$", "") .. "/"
    
              if absolute:sub(1, #prefix) == prefix then
                filepath = absolute:sub(#prefix + 1)
              end
            end
          end
    
          local parts = vim.split(filepath, "/", { plain = true })
    
          if #parts > 5 then
            filepath = "…/" .. table.concat(
              vim.list_slice(parts, #parts - 4, #parts), "/"
            )
          end
    
          return filepath
        end,
        hl = { fg = "filename", bold = true },
      },
    
      update = { "FileType", "BufEnter" },
    }
    
    local InactiveFileName = {
      init = function(self)
        self.filename = vim.api.nvim_buf_get_name(0)

        if self.filename == "" or vim.bo.filetype == "alpha" then
            self.filename = "[No Name]"
            self.icon = nil
            return
        end    

        self.filename = vim.fn.fnamemodify(self.filename, ":.")
        local basename = vim.fn.fnamemodify(self.filename, ":t")
        local extension = vim.fn.fnamemodify(basename, ":e")
    
        self.icon = require("nvim-web-devicons").get_icon(
          basename, extension, { default = true }
        )
      end,
    
      provider = function(self)
          if self.filename == "[No Name]" or vim.bo.filetype == "alpha" then
              return " [No Name]"
          end
    
        local filepath = self.filename
        local api = require("nvim-tree.api")
    
        if api.tree.is_visible() then
          local nodes = api.tree.get_nodes()
          local root = nodes and nodes.absolute_path
    
          if root then
            local absolute = vim.fn.fnamemodify(
              vim.api.nvim_buf_get_name(0), ":p"
            )
            root = vim.fn.fnamemodify(root, ":p")
    
            local prefix = root:gsub("/$", "") .. "/"
    
            if absolute:sub(1, #prefix) == prefix then
              filepath = absolute:sub(#prefix + 1)
            end
          end
        end
    
        local parts = vim.split(filepath, "/", { plain = true })
    
        if #parts > 5 then
          filepath = "…/" .. table.concat(
            vim.list_slice(parts, #parts - 4, #parts), "/"
          )
        end
    
        local icon = self.icon and self.icon ~= "" and (self.icon .. " ") or ""
        return " " .. icon .. filepath
      end,
    
      hl = { fg = "inactive", bold = true },
      update = { "FileType", "BufEnter" },
    }

    -- line:column component
    local Ruler = {
        condition = function() return vim.bo.filetype ~= "alpha" end,
        provider = "%l:%c ",
        hl = function()
            if conditions.is_active() then
                return { fg = "fg", bold = true } -- #83a598
            end
            return { fg = "inactive", bold = true }
        end,
        update = { "FileType" },
    }

    -- push everything to the right
    local Align = { provider = "%=" }

    -- diagnostic component
    local Diagnostics = {
        condition = conditions.lsp_attached,
        update = { "DiagnosticChanged", "BufEnter", "FileType" },
        init = function(self)
            self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
            self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
            self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
        end,
        { 
            condition = function(self) return self.errors > 0 end,
            provider = function(self) return " 󰅚 " .. self.errors end, 
            hl = { fg = "errors", bold = true } 
        },
        { 
            condition = function(self) return self.warnings > 0 end,
            provider = function(self) return " 󰀪 " .. self.warnings end, 
            hl = { fg = "warnings", bold = true } 
        },
        { 
            condition = function(self) return self.info > 0 end,
            provider = function(self) return " 󰋽 " .. self.info end, 
            hl = { fg = "info", bold = true } 
        },
    }

    -- branch indicator
    local function update_git_status(bufnr)
      local file = vim.api.nvim_buf_get_name(bufnr)
      if file == "" or vim.bo[bufnr].buftype ~= "" then
        vim.b[bufnr].statusline_git_tracked = false
        return
      end

      local dir = vim.fn.fnamemodify(file, ":h")
      local name = vim.fn.fnamemodify(file, ":t")

      local root = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
      if vim.v.shell_error ~= 0 or not root[1] then
        vim.b[bufnr].statusline_git_tracked = false
        return
      end

      vim.fn.systemlist({ "git", "-C", dir, "ls-files", "--error-unmatch", "--", name })
      if vim.v.shell_error ~= 0 then
        vim.b[bufnr].statusline_git_tracked = false
        return
      end

      local branch = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" })
      local status = vim.fn.systemlist({ "git", "-C", dir, "status", "--porcelain", "--", name })

      vim.b[bufnr].statusline_git_tracked = true
      vim.b[bufnr].statusline_git_head = branch[1] or ""
      vim.b[bufnr].statusline_git_dirty = #status > 0

      local has_conflict = false
      for _, line in ipairs(status) do
        if line:match("^UU") or line:match("^AA") or line:match("^DD") or line:match("^UD") or line:match("^DU") then
          has_conflict = true
          break
        end
      end
      vim.b[bufnr].statusline_git_conflict = has_conflict
    end

    vim.api.nvim_create_autocmd(
      { "BufEnter", "BufWritePost", "FocusGained", "FileType" },
      {
        callback = function(args)
          update_git_status(args.buf)
          vim.cmd("redrawstatus")
        end,
      }
    )

    update_git_status(0)

    local GitBranch = {
        hl = function()
            if vim.b.statusline_git_conflict then
                return { fg = "insert" }
            end
            return { fg = "branch", bold = true }
        end,
        condition = function()
            return vim.b.statusline_git_tracked == true
        end,
        provider = function()
            local is_dirty = vim.b.statusline_git_dirty
            local has_conflict = vim.b.statusline_git_conflict
            
            local icon = ""
            if has_conflict then
                icon = "󰀪"
            elseif is_dirty then
                icon = ""
            end

            local branch_name = vim.b.statusline_git_head or ""
            
            return " " .. icon .. " " .. branch_name .. " "
        end,
    }

    local GitDiff = {
      condition = function()
        return vim.b.gitsigns_status_dict ~= nil
      end,
      {
        provider = function()
          local status = vim.b.gitsigns_status_dict
          return (status.added and status.added > 0) and ("+" .. status.added .. "") or ""
        end,
        hl = { fg = "added", bold = true },
      },
      {
        provider = function()
          local status = vim.b.gitsigns_status_dict
          return (status.removed and status.removed > 0) and ("-" .. status.removed .. "") or ""
        end,
        hl = { fg = "removed", bold = true }, 
      },
      {
        provider = function()
          local status = vim.b.gitsigns_status_dict
          return (status.changed and status.changed > 0) and ("~" .. status.changed .. "") or ""
        end,
        hl = { fg = "changed", bold = true },
      },
    }
    
    -- file flag
    local FileFlags = {
      condition = function()
        return vim.bo.modified
      end,
      provider = "[+]",
      hl = function()
        if conditions.is_active() then
          return { fg = "fg" }
        end
        return { fg = "inactive" }
      end,
      update = { "FileType" },
    }

    -- selection count in visual modes
    local VisualSelection = {
      condition = function()
        local mode = vim.fn.mode()
        return mode:find("[vV\22]") ~= nil
      end,
      provider = function()
        local mode = vim.fn.mode()
        
        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getpos(".")
        
        local start_line = start_pos[2]
        local start_col = start_pos[3]
        local end_line = end_pos[2]
        local end_col = end_pos[3]
        
        local lines = math.abs(end_line - start_line) + 1
        
        if mode == "V" then
          return string.format("%dL ", lines)
        end
        
        if mode == string.char(22) then
          local cols = math.abs(end_col - start_col) + 1
          return string.format("%dx%dB ", lines, cols)
        end
        
        local bufnr = vim.api.nvim_get_current_buf()
        local lnum1, col1 = start_line, start_col
        local lnum2, col2 = end_line, end_col
        
        if lnum1 > lnum2 or (lnum1 == lnum2 and col1 > col2) then
          lnum1, lnum2 = lnum2, lnum1
          col1, col2 = col2, col1
        end
        
        local total_chars = 0
        local lines_content = vim.api.nvim_buf_get_lines(bufnr, lnum1 - 1, lnum2, false)
        
        if #lines_content == 1 then
          total_chars = math.abs(col2 - col1) + 1
        else
          for i, line in ipairs(lines_content) do
            if i == 1 then
              total_chars = total_chars + (#line - col1 + 1)
            elseif i == #lines_content then
              total_chars = total_chars + col2
            else
              total_chars = total_chars + #line + 1
            end
          end
        end
        
        return string.format("%dC %dL ", total_chars, lines)
      end,
      hl = { fg = "changed", bold = true },
      update = { "CursorMoved", "ModeChanged" },
    }

    -- file os
    local FileOS = {
      provider = function()
        local ff = vim.bo.fileformat:lower()
        local os_name, icon
        
        if ff == "unix" then
          os_name = "UNIX "
          icon = "   "
        elseif ff == "mac" then
          os_name = "MAC "
          icon = "   "
        else
          os_name = "WIN "
          icon = "   "
        end
        
        return icon .. os_name
      end,
      hl = function()
        if conditions.is_active() then
          return { fg = "branch", bold = true }
        end
        return { fg = "inactive", bold = true }
      end,
      update = { "FileType" },
    }

    -- file percentage
    local LinePercentage = {
        provider = "%P ",
        hl = function()
            if conditions.is_active() then
                return { fg = "fg", bold = true }
            end
            return { fg = "inactive", bold = true }
        end,
        update = { "WinScrolled", "CursorMoved", "CursorMovedI", "ModeChanged", "FileType" },
    }

    -- scrollbar
    local ScrollBar = {
      provider = function()
        local current_line = vim.fn.line(".")
        local total_lines = vim.fn.line("$")
        
        local symbols = { "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
        
        if total_lines == 0 then total_lines = 1 end
        
        local ratio = (current_line - 1) / math.max(total_lines - 1, 1)
        local index = math.floor(ratio * (#symbols - 1)) + 1
        
        return symbols[index]
      end,
      hl = { fg = "filename", bold = true },
      update = { "CursorMoved", "FileType" },
    }

    -- file type
    local FileTypeNames = {
      kitty = "Conf",
      css = "CSS",
      json = "JSON",
      typescript = "TypeScript",
      javascript = "JavaScript",
      cpp = "C++",
    }

    local FileType = {
      provider = function()
        local ft = vim.bo.filetype
        if ft == "" then return "" end
        
        if ft == "alpha" then
          local v = vim.version()
          return string.format(" NVIM v%d.%d.%d ", v.major, v.minor, v.patch)
        end
        
        return (FileTypeNames[ft] or (ft:sub(1, 1):upper() .. ft:sub(2))) .. " "
      end,
      hl = { fg = "fg" },
    }

    -- main bar 
    local StatusLine = {
      hl = function()
        if conditions.is_active() then
          return { fg = "fg", bg = "bg" }
        else
          return { fg = "inactive", bg = "bg" }
        end
      end,

      fallthrough = false,

      {
        condition = function()
          return vim.bo.filetype == "NvimTree"
        end,
        {
          provider = function()
            local name = vim.api.nvim_buf_get_name(0)
            return " " .. vim.fn.fnamemodify(name, ":t") .. " "
          end,
          hl = function()
            if conditions.is_active() then
              return { fg = "fg", bold = true }
            else
              return { fg = "inactive", bold = true }
            end
          end,
        },
        Align,
      },

      {
        condition = conditions.is_active,
        Mode,
        FileName,
        FileFlags,
        GitBranch,
        --GitDiff,
        Align,
        --FileSize,
        Diagnostics,
        FileOS,
        {
            condition = function()
                return vim.bo.filetype ~= "alpha"
            end,
            Ruler,
            VisualSelection,
            LinePercentage,
            --ScrollBar,
        },
        --FileType,
      },

      {
        InactiveFileName,
        FileFlags,
        Align,
        {
            condition = function()
                return vim.bo.filetype == "alpha"
            end,
            FileOS,
        },
        {
            condition = function()
                return vim.bo.filetype ~= "alpha"
            end,
            Ruler,
        },
      },
    }

    -- starts heirline 
    require("heirline").setup({
      statusline = StatusLine,
    })
  end,
}
