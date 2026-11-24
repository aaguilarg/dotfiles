-- Pre-review: walk a branch commit by commit and leave notes for Claude Code (/pre-review). Installed 2026-11-10.
-- Walk a branch commit by commit in one buffer per commit (message + stat + patch, like the
-- GitHub commit page) and append notes to <git-dir>/pre-review.jsonl for the agent to consume.
--
--   :PreReview [base]   start at the oldest commit of base..HEAD (base defaults to master)
--   ]r / [r             next / previous commit
--   c  (normal/visual)  note on the line or selection under the cursor
--                       on the commit header -> note about the commit itself (title, order, split)
--                       on a file header     -> note about the whole file
--   x                   delete the note under the cursor
--   gl                  all open notes in the quickfix list
--   <CR>                open the file at that commit and line (needs fugitive)
--   q                   close

local M = {}
local ns = vim.api.nvim_create_namespace 'pre_review'
local state = { base = nil, commits = {}, index = 0, buf = nil }

local function git(args)
  local result = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
  if result.code ~= 0 then error(result.stderr) end
  return vim.split(vim.trim(result.stdout), '\n', { plain = true })
end

local function notes_path() return vim.fn.fnamemodify(git({ 'rev-parse', '--git-path', 'pre-review.jsonl' })[1], ':p') end

local function read_notes()
  local notes = {}
  local file = io.open(notes_path(), 'r')
  if not file then return notes end
  for line in file:lines() do
    if line ~= '' then table.insert(notes, vim.json.decode(line)) end
  end
  file:close()
  return notes
end

local function write_notes(notes)
  local file = assert(io.open(notes_path(), 'w'))
  for _, note in ipairs(notes) do
    file:write(vim.json.encode(note), '\n')
  end
  file:close()
end

-- Maps a row of `git show` output to { path, side, line }.
-- No path: the row is in the commit header. Path without line: the row is in a file header.
function M.locate(lines, row)
  local hunk_row, file_row
  for i = row, 1, -1 do
    if not hunk_row and lines[i]:match '^@@ ' then hunk_row = i end
    if lines[i]:match '^diff %-%-git ' then
      file_row = i
      break
    end
  end
  if not file_row then return {} end

  local path
  for i = file_row + 1, #lines do
    local old, new = lines[i]:match '^%-%-%- a/(.+)$', lines[i]:match '^%+%+%+ b/(.+)$'
    path = new or path or old
    if new or lines[i]:match '^@@ ' or lines[i]:match '^diff %-%-git ' then break end
  end
  path = path or lines[file_row]:match ' b/(.+)$'
  if not hunk_row or hunk_row == row then return { path = path } end

  local old_line, new_line = lines[hunk_row]:match '^@@ %-(%d+),?%d* %+(%d+)'
  old_line, new_line = tonumber(old_line), tonumber(new_line)
  for i = hunk_row + 1, row - 1 do
    local prefix = lines[i]:sub(1, 1)
    if prefix ~= '+' then old_line = old_line + 1 end
    if prefix ~= '-' then new_line = new_line + 1 end
  end
  if lines[row]:sub(1, 1) == '-' then return { path = path, side = 'old', line = old_line } end
  return { path = path, side = 'new', line = new_line }
end

local function current_commit() return state.commits[state.index] end

local function render_notes()
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local by_key = {}
  for _, note in ipairs(read_notes()) do
    if note.commit == current_commit().sha then
      local key = table.concat({ note.path or '', note.side or '', note.end_line or note.line or '' }, '|')
      by_key[key] = by_key[key] or {}
      table.insert(by_key[key], note)
    end
  end
  for row = 1, #lines do
    local at = M.locate(lines, row)
    local header = (not at.path and row == 1) or (at.path and not at.line and lines[row]:match '^diff %-%-git ')
    if at.line or header then
      local key = table.concat({ at.path or '', at.side or '', at.line or '' }, '|')
      for _, note in ipairs(by_key[key] or {}) do
        vim.api.nvim_buf_set_extmark(state.buf, ns, row - 1, 0, {
          virt_lines = { { { '  >> ' .. note.note, 'DiagnosticWarn' } } },
        })
      end
      by_key[key] = nil
    end
  end
end

local function show(index)
  if index < 1 or index > #state.commits then return vim.notify 'pre-review: no more commits' end
  state.index = index
  local commit = current_commit()
  local lines = git { 'show', '--no-color', '--stat', '--patch', '--format=commit %H%nAuthor: %an%nDate:   %ad%n%n    %B', commit.sha }
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_set_name(state.buf, ('prereview://%d of %d %s'):format(index, #state.commits, commit.sha:sub(1, 9)))
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  render_notes()
end

function M.add(text, first_row, last_row)
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local first, last = M.locate(lines, first_row), M.locate(lines, last_row or first_row)
  local commit = current_commit()
  local notes = read_notes()
  table.insert(notes, {
    id = ('n%d'):format(#notes + 1),
    branch = git({ 'branch', '--show-current' })[1],
    base = state.base,
    commit = commit.sha,
    subject = commit.subject,
    path = last.path,
    side = last.side,
    line = first.line,
    end_line = last.line ~= first.line and last.line or nil,
    code = last.line and table.concat(vim.list_slice(lines, first_row, last_row or first_row), '\n') or nil,
    note = text,
    created_at = os.date '!%Y-%m-%dT%H:%M:%SZ',
  })
  write_notes(notes)
  render_notes()
end

local function location(note)
  local lines = note.line and (':' .. note.line .. (note.end_line and ('-' .. note.end_line) or '')) or ''
  return note.path and (note.path .. lines) or '(commit)'
end

local function prompt(first_row, last_row)
  local actions, action_state = require 'telescope.actions', require 'telescope.actions.state'
  last_row = last_row or first_row
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local first, last = M.locate(lines, first_row), M.locate(lines, last_row)
  local target = location { path = last.path, line = first.line, end_line = last.line ~= first.line and last.line or nil }
  local code = last.line and vim.list_slice(lines, first_row, last_row) or {}
  local commit = current_commit()

  require('telescope.pickers')
    .new(require('telescope.themes').get_dropdown { layout_config = { height = 5 } }, {
      prompt_title = 'Note',
      finder = require('telescope.finders').new_dynamic {
        fn = function(text) return { text } end,
        entry_maker = function(text) return { value = text, display = target, ordinal = text } end,
      },
      sorter = require('telescope.sorters').empty(),
      previewer = require('telescope.previewers').new_buffer_previewer {
        title = commit.sha:sub(1, 9) .. ' ' .. commit.subject,
        get_buffer_by_name = function() return 'pre-review-note' end,
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.list_extend({ '  >> ' .. entry.value, '' }, code))
          vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
          vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, { line_hl_group = 'DiagnosticWarn' })
          vim.bo[bufnr].filetype = 'diff'
          vim.wo[self.state.winid].wrap = true
          vim.wo[self.state.winid].linebreak = true
        end,
      },
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local text = action_state.get_current_picker(prompt_bufnr):_get_prompt()
          actions.close(prompt_bufnr)
          if text ~= '' then M.add(text, first_row, last_row) end
        end)
        return true
      end,
    })
    :find()
end

local function delete_at_cursor()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local at = M.locate(lines, vim.fn.line '.')
  local kept = vim.tbl_filter(function(note)
    local same = note.commit == current_commit().sha
      and note.path == at.path
      and note.side == at.side
      and (note.end_line or note.line) == at.line
    return not same
  end, read_notes())
  write_notes(kept)
  render_notes()
end

local function open_file()
  local at = M.locate(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false), vim.fn.line '.')
  if not at.path then return end
  local rev = at.side == 'old' and current_commit().sha .. '^' or current_commit().sha
  vim.cmd(('Gtabedit %s:%s'):format(rev, at.path))
  if at.line then vim.api.nvim_win_set_cursor(0, { at.line, 0 }) end
end

function M.list()
  local items = {}
  for _, note in ipairs(read_notes()) do
    table.insert(items, { text = ('%s %s  %s  -- %s'):format(note.id, note.commit:sub(1, 9), location(note), note.note) })
  end
  vim.fn.setqflist({}, ' ', { title = 'pre-review notes', items = items })
  vim.cmd 'copen'
end

function M.start(base)
  state.base = git({ 'merge-base', base ~= '' and base or 'master', 'HEAD' })[1]
  state.commits = {}
  for _, line in ipairs(git { 'log', '--reverse', '--format=%H %s', state.base .. '..HEAD' }) do
    local sha, subject = line:match '^(%x+) (.*)$'
    if sha then table.insert(state.commits, { sha = sha, subject = subject }) end
  end
  if #state.commits == 0 then return vim.notify 'pre-review: no commits ahead of base' end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].filetype = 'git'
  vim.bo[state.buf].bufhidden = 'wipe'
  vim.api.nvim_set_current_buf(state.buf)

  local function map(mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { buffer = state.buf, nowait = true }) end
  map('n', ']r', function() show(state.index + 1) end)
  map('n', '[r', function() show(state.index - 1) end)
  map('n', 'c', function() prompt(vim.fn.line '.') end)
  map('x', 'c', function()
    local first, last = vim.fn.line 'v', vim.fn.line '.'
    vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'nx', false)
    prompt(math.min(first, last), math.max(first, last))
  end)
  map('n', 'x', delete_at_cursor)
  map('n', 'gl', M.list)
  map('n', '<CR>', open_file)
  map('n', 'q', '<Cmd>bwipeout<CR>')
  show(1)
end

vim.api.nvim_create_user_command('PreReview', function(opts) M.start(opts.args) end, { nargs = '?' })

return M
