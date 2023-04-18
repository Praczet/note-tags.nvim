local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')

local M = {}
M._Config = {
  -- Folder with Notes it can be empty string
  notes_folder = '',
  -- Tag separator. it is used only when read_tag_method = "separator"
  tags_separator = '<!--tags-->',
  -- It can be set as: 'separator' | 'wholeFile'
  -- - **separator** - will reads tags only after the separator
  -- - **wholeFile** - will reads tags in whole file
  read_tag_method = 'separator'
}

-- Gets Notes' folder based on M.\_Config.notes\_folder. If it is empty it will return current folder
local function get_notes_folder()
  if M._Config.notes_folder ~= nil and M._Config.notes_folder ~= '' then
    return M._Config.notes_folder
  end
  return vim.fn.getcwd()
end

-- This method will check in configuration if user has own tags seperator
-- if not it will return mine <!--tags-->
local function get_tags_separator()
  return M._Config.tags_separator
end

-- This method will check configuration and return method of reading tags
-- there are two methos: separator or wholeFile
-- * **separator** is a method that reads tags after separator (should be at the end of file)
-- * **wholeFile** reads file and return tags matching regular expression
local function get_read_tag_method()
  return M._Config.read_tag_method
end

-- Checks if file file_exists
--
-- @param path True - file exists, False - otherwise
local function file_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == 'file'
end

-- this methos will return list of notes having **tag separator**
local function get_notes_with_separator()
  local search = get_tags_separator()
  local notes_folder = get_notes_folder()
  local grep_command = "grep -r -l '" .. search .. "' " .. notes_folder .. "/*.md | sort | uniq"
  local grep_result = vim.fn.systemlist(grep_command)
  local filenames = {}
  for _, result in ipairs(grep_result) do
    if not vim.tbl_contains(filenames, result) and file_exists(result) then
      table.insert(filenames, result)
    end
  end
  return filenames
end

-- Reads tags only after the separator
-- @return table tags with tags (tags are without #)
local function read_tags_after_separator()
  local files = get_notes_with_separator()
  local separator = get_tags_separator()
  separator = string.gsub(separator, "-", "%%-")
  local tags = {}
  for _, file in ipairs(files) do
    local lines = vim.fn.readfile(file)
    local start = false
    for _, line in ipairs(lines) do
      if start then
        for tag in string.gmatch(line, '#(%S+)') do
          if not vim.tbl_contains(tags, tag) then
            table.insert(tags, tag)
          end
        end
      end
      if string.match(line, separator) ~= nil then
        start = true
      end
    end
  end
  table.sort(tags)
  return tags
end

-- Reads tags in whole file using regularexpression
local function read_tags_whole_file()
  -- print('Whole file')
  local notes_folder = get_notes_folder()
  local search = "#[^ #=]+"
  local grep_command = "grep -r -E '" .. search .. "' " .. notes_folder .. "/*.md | sort | uniq"
  local grep_result = vim.fn.systemlist(grep_command)
  local tags = {}
  -- print(vim.inspect(grep_result))
  for _, line in ipairs(grep_result) do
    for tag in string.gmatch(line, '#([%w-]+) ') do
      if not vim.tbl_contains(tags, tag) then
        table.insert(tags, tag)
      end
    end
    for tag in string.gmatch(line, '#([%w-]+)$') do
      if not vim.tbl_contains(tags, tag) then
        table.insert(tags, tag)
      end
    end
  end
  table.sort(tags)
  return tags
end

-- Main method to read tags basically it choose right method for reading tags based on users preferences
local function read_tags()
  if get_read_tag_method() == "separator" then
    return read_tags_after_separator()
  else
    return read_tags_whole_file()
  end
end

-- Method siplay tags in picker window. (tag that are read from notes)
-- Enter will insert tag <Control>+o will open another picker with the list of notes
-- for selected tag
local function display_tags(opts)
  opts = opts or {}
  local tags = opts.tags or {}
  local current_bufnr = vim.api.nvim_get_current_buf()

  local pickers_opts = {
    prompt_title = "Search for tag",
    results_title = "Tags",
    finder = finders.new_table(tags),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Notes (<C-n> Notes)",
      width = 0.8,
      define_preview = function(self, entry, status)
        local notes = M.get_notes_for_tag(entry.value) or { "-- notes not found --" }
        local abs_path = vim.fn.expand(get_notes_folder()) .. "/"
        notes = M.table_map(notes, function(item) return string.gsub(item, abs_path, "") end)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, notes)
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      local function open_notes()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.notes({ tag = selection[1] })
      end
      local function local_add_new_tag()
        local user_input = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)[1] or ''
        if string.len(user_input) > 4 then
          user_input = string.sub(user_input, 5)
        else
          user_input = ''
        end
        -- actions.close(prompt_bufnr)
        -- print('user input', user_input)
        M.add_new_tag(user_input, current_bufnr)
      end
      actions.select_default:replace(
        function()
          -- actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection ~= nil then M.add_tag(selection[1], current_bufnr) end
        end
      )
      map('i', '<C-n>', open_notes)
      map('n', '<C-n>', open_notes)
      map('i', '<C-a>', local_add_new_tag)
      map('n', '<C-a>', local_add_new_tag)
      return true
    end
  }
  local tag_picker = pickers.new(pickers_opts)
  tag_picker:find()
end


-- Get list of notes that for tag. It searches after tag separator
local function get_notes_for_tag_separator(tag)
  local files = get_notes_with_separator()
  local separator = get_tags_separator()
  separator = string.gsub(separator, "-", "%%-")
  local notes = {}
  for _, file in ipairs(files) do
    local lines = vim.fn.readfile(file)
    local start = false
    for _, line in ipairs(lines) do
      if start then
        for note in string.gmatch(line, '#' .. tag .. '') do
          if not vim.tbl_contains(notes, file) then
            table.insert(notes, file)
          end
        end
      end
      if string.match(line, separator) ~= nil then
        start = true
      end
    end
  end
  return notes
end

-- Gets list of notes for tag
-- This method search for tag in the file (no matter where)
-- @param tag tag to search for
local function get_notes_for_tag_wholefile(tag)
  local notes_folder = get_notes_folder()
  local grep_command = "grep -r  -l -E '#" .. tag .. "\\s|#" .. tag .. "$' " .. notes_folder .. "/*.md | sort | uniq "
  local grep_result = vim.fn.systemlist(grep_command)
  local notes = {}
  -- print(vim.inspect(grep_result))
  for _, note in ipairs(grep_result) do
    if not vim.tbl_contains(notes, note) and file_exists(note) then
      table.insert(notes, note)
    end
  end
  return notes
end

-- Gets notes from notes_folder
-- It uses `find` for it
local function get_all_notes()
  local notes_folder = get_notes_folder()
  local find_command = "find " .. notes_folder .. "  -type f -name '*.md*'"
  local find_results = vim.fn.systemlist(find_command)
  return find_results
end

-- Add tags to buffer
-- Adds tags to current buffer in the cursor position
-- Not like in separator method where tag is added at the bottom of file..
-- @param tag tag to add
local function add_tag_wholeFile(tag)
  tag = tag:gsub("^#", "")
  vim.api.nvim_put({ "#" .. tag .. " " }, "", false, true)
end

-- Adds tag to tags
-- If separator can not be found in the buffer this method will:
-- - Add horizontal line
-- - Add separator
-- - Tag
-- If separator exists this method will add tag to tags (if tag exists message will be shown)
-- @param tag tag to add
-- @param current_bufnr buffer where note will be added
local function add_tag_separator(tag, current_bufnr)
  tag               = tag:gsub("^#", "")
  local tags_found  = false
  local bfnr        = current_bufnr or vim.api.nvim_get_current_buf()
  local lines       = vim.api.nvim_buf_line_count(bfnr)
  local separator   = get_tags_separator()
  local r_separator = string.gsub(separator, "-", "%%-")

  -- vim.api.nvim_put({ "#" .. selection[1] .. " " }, "", false, true)
  for i, line in ipairs(vim.fn.getbufline(bfnr, 1, "$")) do
    if string.find(line, "^" .. r_separator) then
      tags_found = true
      for j = i + 1, #vim.fn.getbufline(bfnr, i, "$") + i do
        local current_line = vim.fn.getbufline(bfnr, j, j)[1]
        if string.find(current_line, "#") then
          if string.find(current_line, "#" .. tag .. "%s") or string.find(current_line, "#" .. tag .. "$") then
            vim.cmd("redraw")
            print('Tags exists')
            return
          else
            vim.api.nvim_buf_set_lines(bfnr, j - 1, j, false, { current_line .. " #" .. tag })
            vim.cmd("redraw")
            print('Tag: #' .. tag .. ' added.')
            return
          end
        end
      end
      vim.api.nvim_buf_set_lines(bfnr, lines, lines, false, { "#" .. tag })
      vim.cmd("redraw")
      print('Tag: #' .. tag .. ' added.')
      return
    end
  end

  -- If the buffer does not contain a line with "<!--tags-->", add it to the end
  if not tags_found then
    vim.api.nvim_buf_set_lines(bfnr, lines, lines, false, { '' })
    vim.api.nvim_buf_set_lines(bfnr, lines + 1, lines + 1, false, { "---" })
    vim.api.nvim_buf_set_lines(bfnr, lines + 2, lines + 2, false, { '' })
    vim.api.nvim_buf_set_lines(bfnr, lines + 3, lines + 3, false, { separator })
    vim.api.nvim_buf_set_lines(bfnr, lines + 4, lines + 4, false, { '' })
    vim.api.nvim_buf_set_lines(bfnr, lines + 5, lines + 5, false, { "#" .. tag })
    vim.cmd("redraw")
    print('Tag: #' .. tag .. ' added.')
  end
end

-- Base of read_tag_method it called proper function for adding tag
-- It triggers eitghr add_tag_wholeFile or add_tag_separator
-- @param tag Tag to add
-- @param current_bufnr Buffer where tag should be added
function M.add_tag(tag, current_bufnr)
  tag = tag:gsub("^#", "")
  if tag == nil or tag == '' then return end
  if get_read_tag_method() == "separator" then
    add_tag_separator(tag, current_bufnr)
  else
    add_tag_wholeFile(tag, current_bufnr)
  end
end

-- Adds new tag, if called without parameter Prompt for new tag will be displayed
function M.add_new_tag(...)
  local new_tag = ''
  local current_bufnr = vim.api.nvim_get_current_buf()
  if select("#", ...) > 0 then
    new_tag = select(1, ...)
  end
  if select("#", ...) > 1 then
    current_bufnr = select(2, ...)
  end
  if new_tag == '' then
    new_tag = vim.fn.input({ prompt = "New Tag: #" })
    if new_tag == '' then
      vim.cmd("redraw")
      print('Tag can not be empty')
      return
    end
  end
  M.add_tag(new_tag, current_bufnr)
end

-- Return given array but processed by given function
-- It is poor substitute for JavaScript method Array.map()
-- used for removing notes_folder from note's path
-- @param tbl Table to process
-- @param fn Function for processing
function M.table_map(tbl, fn)
  local new_tbl = {}
  for i, v in ipairs(tbl) do
    new_tbl[i] = fn(v, i, tbl)
  end
  return new_tbl
end

-- Based on read_tag_method gets notes for tag
-- @param tag Tags to search for
function M.get_notes_for_tag(tag)
  if get_read_tag_method() == "separator" then
    return get_notes_for_tag_separator(tag)
  else
    return get_notes_for_tag_wholefile(tag)
  end
end

-- Displays FInder, Prompt and previewer with Tags, if tags are not found the message will be shown
function M.tags()
  local tags = read_tags()
  if #tags == 0 then
    vim.cmd("redraw")
    print('No tags found in files in folder: ')
    print(get_notes_folder())
  else
    -- print(table.concat(tags, ", "))
  end
  display_tags({ tags = tags })
end

-- Display list of Notes. It can have parameter opts.tag if passed it displays Notes for that Tag
-- It also display selected note preview. It tries to use glow if not present it will just `cat` a note
function M.notes(...)
  local opts = {}
  if select("#", ...) > 0 then
    opts = select(1, ...)
  end
  local tag = opts.tag or ""
  local notes = {}
  local title = ''
  if tag == '' then
    notes = get_all_notes() or {}
    title = "All notes (<C-t> Tags)"
  else
    notes = M.get_notes_for_tag(tag) or {}
    title = "Notes tagged -=#" .. tag .. "=- (<C-t> Tags)"
  end
  local abs_path = vim.fn.expand(get_notes_folder()) .. "/"
  local pickers_opts = {
    prompt_title = "Search for notes",
    results_title = title,
    dynamic_preview_title = true,
    finder = finders.new_table({
      results = notes,
      entry_maker = function(note)
        return {
          value = note,
          display = string.gsub(note, abs_path, ""),
          ordinal = string.gsub(note, abs_path, ""),
        }
      end
    }),
    sorter = sorters.get_fuzzy_file({}),
    -- sorter = sorters.get_generic_fuzzy_sorter({}),
    previewer = previewers.new_termopen_previewer({
      title = 'Preview',
      get_command = function(entry)
        local f = io.popen('which glow')
        -- fallback if there is no 'which' command
        if f == nil then
          return { 'cat', entry.value }
        end
        local output = f:read('*a')
        f:close()
        if output ~= '' then
          return { 'glow', entry.value }
        else
          return { 'cat', entry.value }
        end
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      local function back_to_tags()
        actions.close(prompt_bufnr)
        M.tags()
      end
      map('i', '<C-t>', back_to_tags)
      map('n', '<C-t>', back_to_tags)
      return true
    end
  }
  local note_picker = pickers.new(pickers_opts)
  note_picker:find()
end

-- You can configure:
-- * **notes_folder** - Folder with notes, if you sets it as '' it will take current working folder
-- * **read_tag_method** - Method how plugin reads tags:
--   * ***separator*** - it will reads tags after line with separator
--   * ***wholeFile*** - it will looks for tags in file
-- * **tags_separator** - separator default: <!--tags--> it is needed when read_tag_method = seperator
function M.setup(opts)
  if opts ~= nil then
    M._Config.notes_folder = opts.notes_folder or M._Config.notes_folder
    M._Config.read_tag_method = opts.read_tag_method or M._Config.read_tag_method
    M._Config.tags_separator = opts.tags_separator or M._Config.tags_separator
  end
  vim.cmd([[command! Tags lua require('note-tags').tags()]])
  vim.cmd([[command! Notes lua require('note-tags').notes()]])
  -- Add keymaps to Telescope Tags and Note Tags
  vim.keymap.set('n', '<leader>n', 'echo', { desc = "Notes / Tags", })
  vim.api.nvim_set_keymap('n', '<leader>nt', ':lua require("note-tags").tags()<CR>', { desc = "Tags' list" })
  vim.api.nvim_set_keymap('n', '<leader>na', ':lua require("note-tags").add_new_tag()<CR>', { desc = "Add New Tag" })
  vim.api.nvim_set_keymap('n', '<leader>nn', ':lua require("note-tags").notes()<CR>', { desc = "Notes' list" })
end

-- Export's public function (instead of it, can be added list od method to export)
return setmetatable({}, {
  __index = function(_, k)
    if M[k] then
      return M[k]
    else
      error("Invalid method " .. k)
    end
  end,
})
-- M.notes()
