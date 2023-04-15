local telescope = require('telescope')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local built = require('telescope.builtin')
local utils = require('telescope.utils')
local conf = require('telescope.config').values

local M = {}

local function get_notes_folder()
  if M.notes_folder ~= nil then
    return M.notes_folder
  end
  return "~/Notes"
  -- return vim.fn.getcwd()
end

-- This method will check in configuration if user has own tags seperator
-- if not it will return mine <!--tags-->
local function get_tags_separator()
  return "<!--tags-->"
end

-- This method will check configuration and return method of reading tags
-- there are two methos: separator or wholeFile
-- * **separator** is a method that reads tags after separator (should be at the end of file)
-- * **wholeFile** reads file and return tags matching regular expression
local function get_read_tag_method()
  return "separator"
  -- return "wholeFile"
end

-- this methos will return
local function get_notes_with_separator()
  local search = get_tags_separator()
  local notes_folder = get_notes_folder()
  local grep_command = "grep -r -l '" .. search .. "' " .. notes_folder .. "/*.md | sort | uniq"
  local grep_result = vim.fn.systemlist(grep_command)
  local filenames = {}
  for _, result in ipairs(grep_result) do
    if not vim.tbl_contains(filenames, result) then
      table.insert(filenames, result)
    end
  end
  return filenames
end

-- Reads tags only after the separator
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
  print('Whole file')
  local notes_folder = get_notes_folder()
  local search = "#[^ #=]+"
  local grep_command = "grep -r -E '" .. search .. "' " .. notes_folder .. "/*.md | sort | uniq"
  local grep_result = vim.fn.systemlist(grep_command)
  local tags = {}
  -- print(vim.inspect(grep_result))
  for _, line in ipairs(grep_result) do
    for tag in string.gmatch(line, '#([%w-]+)') do
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

local function display_tags(opts)
  opts = opts or {}
  local tags = opts.tags or {}

  print(vim.inspect(tags))

  local pickers_opts = {
    prompt_title = "Search for tag",
    results_title = "Tags",
    finder = finders.new_table(tags),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Notes",
      width = 0.8,
      define_preview = function(self, entry, status)
        local notes = M.get_notes_for_tag(entry.value) or { "-- notes not found --" }
        local abs_path = vim.fn.expand(get_notes_folder()) .. "/"
        notes = M.table_map(notes, function(item) return string.gsub(item, abs_path, "") end)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, notes)
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(
        function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.add_tag(selection[1])
        end
      )
      return true
    end
  }
  -- #story #me
  local tag_picker = pickers.new(pickers_opts)
  tag_picker:find()
end



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


local function get_notes_for_tag_whilefile(tag)
  local notes_folder = get_notes_folder()
  local grep_command = "grep -r  -l -E '#" .. tag .. "\\s|#" .. tag .. ",' " .. notes_folder .. "/*.md | sort | uniq "
  local grep_result = vim.fn.systemlist(grep_command)
  local notes = {}
  -- print(vim.inspect(grep_result))
  for _, line in ipairs(grep_result) do
    for note in string.gmatch(line, '#([%w-]+)') do
      if not vim.tbl_contains(notes, note) then
        table.insert(notes, note)
      end
    end
  end
  return notes
end

function M.add_tag(tag)
  local tags_found  = false
  local bfnr        = vim.api.nvim_get_current_buf()
  local lines       = vim.api.nvim_buf_line_count(bfnr)
  local separator   = get_tags_separator()
  local r_separator = string.gsub(separator, "-", "%%-")
  -- vim.api.nvim_put({ "#" .. selection[1] .. " " }, "", false, true)
  for i, line in ipairs(vim.fn.getbufline(bfnr, 1, "$")) do
    if string.find(line, "^--" .. r_separator) then
      tags_found = true
      for j = i + 1, #vim.fn.getbufline(bfnr, i, "$") + i do
        local current_line = vim.fn.getbufline(bfnr, j, j)[1]
        if string.find(current_line, "#") then
          if string.find(current_line, "#" .. tag .. "%s") or string.find(current_line, "#" .. tag .. "$") then
            print('Tags exists')
            return
          else
            vim.api.nvim_buf_set_lines(bfnr, j - 1, j, false, { current_line .. " #" .. tag })
            print('adding at the end', j, current_line)
            return
          end
        end
      end
      vim.api.nvim_buf_set_lines(bfnr, lines, lines, false, { "#" .. tag })
      return
    end
  end

  -- If the buffer does not contain a line with "<!--tags-->", add it to the end
  if not tags_found then
    vim.api.nvim_buf_set_lines(bfnr, lines, lines, false, { "---" })
    vim.api.nvim_buf_set_lines(bfnr, lines + 1, lines + 1, false, { '' })
    vim.api.nvim_buf_set_lines(bfnr, lines + 2, lines + 2, false, { separator })
    vim.api.nvim_buf_set_lines(bfnr, lines + 3, lines + 3, false, { '' })
    vim.api.nvim_buf_set_lines(bfnr, lines + 4, lines + 4, false, { "#" .. tag })
  end
end

function M.table_map(tbl, fn)
  local new_tbl = {}
  for i, v in ipairs(tbl) do
    new_tbl[i] = fn(v, i, tbl)
  end
  return new_tbl
end

function M.get_notes_for_tag(tag)
  if get_read_tag_method() == "separator" then
    return get_notes_for_tag_separator(tag)
  else
    return get_notes_for_tag_whilefile(tag)
  end
end

function M.tags()
  local tags = read_tags()
  if #tags == 0 then
    print('No tags found in files in folder')
    print(get_notes_folder())
  else
    print(table.concat(tags, ", "))
  end
  display_tags({ tags = tags })
end

function M.notes()
  built.find_files({
    prompt_title = "Notes for tag",
    cwd = get_notes_folder(),
    attach_mappings = function(_, map)
      map('i', '<cr>', function(prompt_bufnr)
        local selection = actions.state.get_selected_entry()
        vim.cmd("edit " .. selection.value)
        actions.close(prompt_bufnr)
      end)
      return true
    end,
    find_command = { "rg", "--files", "--hidden", "--no-ignore", "--follow", "-g", "*.md" },
  })
end

function M.setup()
  -- vim.cmd([[
  --   command! -nargs=? Encrypt lua require('encrypt-text').encrypt(<f-args>)
  --   command! -nargs=? Decrypt lua require('encrypt-text').decrypt(<f-args>)
  -- ]])
  vim.cmd([[command! Tags lua require('note-tags').tags()]])
  -- Add keymaps to Telescope Tags and Note Tags
  -- vim.api.nvim_set_keymap('n', '<leader>f', ':Telescope Tags<CR>', { noremap = true })
  vim.api.nvim_set_keymap('n', '<leader>t', ':lua require("note-tags").find_files_for_tag("Item")<CR>',
    { noremap = true })
end

return setmetatable({}, {
  __index = function(_, k)
    if M[k] then
      return M[k]
    else
      error("Invalid method " .. k)
    end
  end,
})
-- M.tags()
--<!--tags-->

--#dream #lion
