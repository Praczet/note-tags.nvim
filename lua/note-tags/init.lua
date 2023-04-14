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
          table.insert(tags, tag)
        end
      end
      if string.match(line, separator) ~= nil then
        start = true
      end
    end
  end
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
    finder = finders.new_table(tags),
    sorter = sorters.get_generic_fuzzy_sorter({}),
    previewer = previewers.cat.new(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(
        function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- vim.api.nvim_put({ "#" .. selection[1] .. " " }, "", false, true)
        end
      )
      return true
    end
  }
  -- #story #me
  local tag_picker = pickers.new(pickers_opts)
  tag_picker:find()
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

-- return setmetatable({}, {
--   __index = function(_, k)
--     if M[k] then
--       return M[k]
--     else
--       error("Invalid method " .. k)
--     end
--   end,
-- })
M.tags()
