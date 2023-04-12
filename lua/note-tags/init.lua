local telescope = require('telescope')
local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local built = require('telescope.builtin')
local conf = require('telescope.config').values

local M = {}

local function get_notes_folder()
  if M.notes_folder ~= nil then
    return M.notes_folder
  end
  return vim.fn.getcwd()
end

local function read_tags()
  local notes_folder = get_notes_folder()
  local tag_set = {}
  for _, file in ipairs(vim.fn.glob(notes_folder .. "/*.md", true, true)) do
    local file_tags = vim.fn.matchlist(vim.fn.readfile(file), "\\v#([^ ]+)", 0)
    for _, tag in ipairs(file_tags) do
      if tag ~= "" then
        tag_set[tag] = true
      end
    end
  end
  return vim.tbl_keys(tag_set)
end

function M.find_files_for_tag(tag)
  local files = vim.fn.glob("~/Notes/**/*.md", true, true)
  local tags = {}

  for _, file in ipairs(files) do
    local contents = io.open(file):read("*all")
    if contents:find("#" .. tag, 1, true) then
      table.insert(tags, { filename = file, text = tag, lnum = 1 })
    end
  end

  if #tags > 0 then
    print(vim.inspect(tags))
    require('telescope.builtin').quickfix({ entries = tags })
  else
    print("No files found for tag " .. tag)
  end
end

local function find_notes_for_tag(tag)
  local notes_folder = get_notes_folder()
  local notes_list = {}
  for _, file in ipairs(vim.fn.glob(notes_folder .. "/*.md", true, true)) do
    local file_tags = vim.fn.matchlist(vim.fn.readfile(file), "\\v#([^ ]+)", 0)
    for _, t in ipairs(file_tags) do
      if t == tag then
        table.insert(notes_list, file)
        break
      end
    end
  end
  return notes_list
end

function M.tags()
  local tags = read_tags()
  if #tags == 0 then
    print('No tags found in files in folder')
    print(get_notes_folder())
  else
    print(table.concat(tags, ", "))
  end
  require("telescope.builtin").quickfix({ entries = tags })
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
  vim.api.nvim_set_keymap('n', '<leader>t', ':lua require("note-tags").find_files_for_tag()<CR>', { noremap = true })
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
