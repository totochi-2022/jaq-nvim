local M = {}

-- プロセス管理 (by totochi-2022)
M.current_process = nil  -- 最新の実行プロセス
M.all_processes = {}     -- 全プロセス履歴

local config = {
  cmds = {
    internal = {},
    external = {}
  },

  behavior = {
    default     = "float",
    startinsert = false,
    wincmd      = false,
    autosave    = false
  },

  ui = {
    float = {
      border    = "none",
      winhl     = "Normal",
      borderhl  = "FloatBorder",
      height    = 0.8,
      width     = 0.8,
      x         = 0.5,
      y         = 0.5,
      winblend  = 0
    },

    terminal = {
      position = "bot",
      line_no  = false,
      size     = 10
    },

    quickfix = {
      position = "bot",
      size     = 10
    }
  }
}

function M.setup(user_opts)
  config = vim.tbl_deep_extend("force", config, user_opts)
end

local function dimensions(opts)
  local cl = vim.o.columns
  local ln = vim.o.lines

  local width = math.ceil(cl * opts.ui.float.width)
  local height = math.ceil(ln * opts.ui.float.height - 4)

  local col = math.ceil((cl - width) * opts.ui.float.x)
  local row = math.ceil((ln - height) * opts.ui.float.y - 1)

  return {
    width = width,
    height = height,
    col = col,
    row = row
  }
end

local function resize()
  local dim = dimensions(config)
  vim.api.nvim_win_set_config(M.win, {
    style    = "minimal",
    relative = "editor",
    border   = config.ui.float.border,
    height   = dim.height,
    width    = dim.width,
    col      = dim.col,
    row      = dim.row
  })
end

local function float(cmd)
  local dim = dimensions(config)

  function M.VimResized()
    resize()
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    style    = "minimal",
    relative = "editor",
    border   = config.ui.float.border,
    height   = dim.height,
    width    = dim.width,
    col      = dim.col,
    row      = dim.row
  })

  vim.api.nvim_win_set_option(M.win, "winhl", ("Normal:%s"):format(config.ui.float.winhl))
  vim.api.nvim_win_set_option(M.win, "winhl", ("FloatBorder:%s"):format(config.ui.float.borderhl))
  vim.api.nvim_win_set_option(M.win, "winblend", config.ui.float.winblend)

  vim.api.nvim_buf_set_option(M.buf, "filetype", "Jaq")
  vim.api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:lua vim.api.nvim_win_close(' .. M.win .. ', true)<CR>', { silent = true })

  -- プロセス開始とプロセス管理 (by totochi-2022)
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(job_id, exit_code, event)
      -- 終了時にプロセス記録をクリア
      if M.current_process and M.current_process.job_id == job_id then
        M.current_process = nil
      end
      if M.all_processes[M.buf] then
        M.all_processes[M.buf] = nil
      end
    end
  })
  
  -- プロセス情報を記録
  if job_id > 0 then
    local process_info = {
      job_id = job_id,
      buffer = M.buf,
      window = M.win,
      mode = "float",
      source_file = vim.fn.expand('%:p'),
      command = cmd,
      timestamp = os.time()
    }
    M.current_process = process_info
    M.all_processes[M.buf] = process_info
  end

  vim.cmd("autocmd! VimResized * lua require('jaq-nvim').VimResized()")

  if config.behavior.startinsert then
    vim.cmd("startinsert")
  end

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

local function term(cmd)
  vim.cmd(config.ui.terminal.position .. " " .. config.ui.terminal.size .. "new | term " .. cmd)

  M.buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(M.buf, "filetype", "Jaq")
  vim.api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:bdelete!<CR>', { silent = true })
  
  -- プロセス管理 (by totochi-2022)
  -- terminalモードではjob_idを後から取得
  vim.defer_fn(function()
    local job_id = vim.api.nvim_buf_get_var(M.buf, 'terminal_job_id')
    if job_id then
      local process_info = {
        job_id = job_id,
        buffer = M.buf,
        window = vim.api.nvim_get_current_win(),
        mode = "terminal",
        source_file = vim.fn.expand('%:p'),
        command = cmd,
        timestamp = os.time()
      }
      M.current_process = process_info
      M.all_processes[M.buf] = process_info
    end
  end, 100)  -- 100ms後にjob_idを取得

  if config.behavior.startinsert then
    vim.cmd("startinsert")
  end

  if not config.ui.terminal.line_no then
    vim.cmd("setlocal nonumber | setlocal norelativenumber")
  end

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

local function quickfix(cmd)
  vim.cmd(
    'cex system("' .. cmd .. '") | ' ..
    config.ui.quickfix.position ..
    ' copen ' ..
    config.ui.quickfix.size)

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

-- HUUUUUUUUUUUUUUUUUUUUUUUGE kudos and thanks to
-- https://github.com/hown3d for this function <3
local function substitute(cmd)
  cmd = cmd:gsub("%%", vim.fn.expand('%'));
  cmd = cmd:gsub("$fileBase", vim.fn.expand('%:r'));
  cmd = cmd:gsub("$filePath", vim.fn.expand('%:p'));
  cmd = cmd:gsub("$file", vim.fn.expand('%'));
  cmd = cmd:gsub("$dir", vim.fn.expand('%:p:h'));
  cmd = cmd:gsub("$moduleName",
    vim.fn.substitute(vim.fn.substitute(vim.fn.fnamemodify(vim.fn.expand("%:r"), ":~:."), "/", ".", "g"), "\\", ".",
      "g"));
  cmd = cmd:gsub("#", vim.fn.expand('#'))
  cmd = cmd:gsub("$altFile", vim.fn.expand('#'))

  return cmd
end

local function internal(cmd)
  cmd = cmd or config.cmds.internal[vim.bo.filetype]

  if not cmd then
    vim.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    vim.cmd("silent write")
  end

  cmd = substitute(cmd)
  vim.cmd(cmd)
end

local function run(type, cmd)
  cmd = cmd or config.cmds.external[vim.bo.filetype]

  if not cmd then
    vim.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    vim.cmd("silent write")
  end

  cmd = substitute(cmd)
  if type == "float" then
    float(cmd)
    return
  elseif type == "bang" then
    vim.cmd("!" .. cmd)
    return
  elseif type == "quickfix" then
    quickfix(cmd)
    return
  elseif type == "terminal" then
    term(cmd)
    return
  end

  vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type' | echohl None")
end

local function project(type, file)
  local json = file:read("*a")
  local status, table = pcall(vim.fn.json_decode, json)
  io.close(file)

  if not status then
    vim.cmd("echohl ErrorMsg | echo 'Error: Invalid json' | echohl None")
    return
  end

  if type == "internal" then
    local cmd = table.internal[vim.bo.filetype]
    cmd = substitute(cmd)

    internal(cmd)
    return
  end

  local cmd = table.external[vim.bo.filetype]
  cmd = substitute(cmd)

  run(type, cmd)
end

function M.Jaq(type)
  local file = io.open(vim.fn.expand('%:p:h') .. "/.jaq.json", "r")

  -- Check if the filetype is in config.cmds.internal
  if vim.tbl_contains(vim.tbl_keys(config.cmds.internal), vim.bo.filetype) then
    -- Exit if the type was passed and isn't "internal"
    if type and type ~= "internal" then
      vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type for internal command' | echohl None")
      return
    end
    type = "internal"
  else
    type = type or config.behavior.default
  end

  if file then
    project(type, file)
    return
  end

  if type == "internal" then
    internal()
    return
  end

  run(type)
end

-- プロセス管理関数 (by totochi-2022)
-- 最新プロセスのみkill
function M.kill_current()
  if M.current_process then
    local process = M.current_process
    
    -- ジョブを停止
    if process.job_id then
      pcall(vim.fn.jobstop, process.job_id)
    end
    
    -- プロセスのみ停止（ウィンドウ/バッファは残す）
    -- 結果を確認できるようにバッファは削除しない
    -- if process.buffer and vim.api.nvim_buf_is_valid(process.buffer) then
    --   pcall(vim.api.nvim_buf_delete, process.buffer, { force = true })
    -- end
    
    -- プロセス記録をクリア
    M.current_process = nil
    if M.all_processes[process.buffer] then
      M.all_processes[process.buffer] = nil
    end
    
    print(string.format("Killed process: %s (job_id: %d)", process.command or "unknown", process.job_id or 0))
    return true
  else
    print("No current jaq process found")
    return false
  end
end

-- 全jaqプロセスをkill
function M.kill_all()
  local count = 0
  
  for buf_id, process in pairs(M.all_processes) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      -- ジョブを停止
      if process.job_id then
        pcall(vim.fn.jobstop, process.job_id)
      end
      
      -- プロセスのみ停止（バッファは残す）
      -- pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
      count = count + 1
    end
  end
  
  -- 全記録をクリア
  M.current_process = nil
  M.all_processes = {}
  
  if count > 0 then
    print(string.format("Killed %d jaq process(es)", count))
  else
    print("No jaq processes found")
  end
  
  return count
end

-- アクティブプロセス一覧表示
function M.list_processes()
  local count = 0
  print("Active jaq processes:")
  
  for buf_id, process in pairs(M.all_processes) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      local elapsed = os.time() - process.timestamp
      local current_mark = (M.current_process and M.current_process.job_id == process.job_id) and " [CURRENT]" or ""
      print(string.format("  %s (%s, %ds ago)%s", 
        process.command or "unknown", process.mode or "unknown", elapsed, current_mark))
      count = count + 1
    else
      -- 無効なバッファは記録から削除
      M.all_processes[buf_id] = nil
    end
  end
  
  if count == 0 then
    print("  No active processes")
  end
  
  return count
end

return M
