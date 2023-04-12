local telescope = require('telescope')
local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values

local M = {}

M.list_notes = function()
  local notes_folder = vim.fn.expand(vim.fn['g:notes_folder'] or vim.fn.getcwd())
  local results = {}

  -- find all markdown files in the notes_folder
  for _, file in ipairs(vim.fn.glob(notes_folder .. '/*.md', false, true)) do
    local lines = vim.fn.readfile(file)
    local tags = {}

    -- get all the tags in the file
    for _, line in ipairs(lines) do
      if vim.startswith(line, '#') then
        for tag in vim.gsplit(line, '%s+') do
          if vim.startswith(tag, '#') then
            table.insert(tags, tag)
          end
        end
      else
        break
      end
    end

    -- add the file to the results for each tag it has
    for _, tag in ipairs(tags) do
      results[tag] = results[tag] or {}
      table.insert(results[tag], file)
    end
  end

  local tag_picker = pickers.new({}, {
    prompt_title = 'Notes Tags',
    finder = finders.new_table({
      results = vim.tbl_keys(results),
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local select_tag = function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        local files = results[selection.value]
        M.list_files(files)
      end

      map('i', '<CR>', select_tag)
      map('n', '<CR>', select_tag)

      return true
    end,
  })

  tag_picker:find()
end

M.list_files = function(files)
  local file_picker = pickers.new({}, {
    prompt_title = 'Notes Files',
    finder = finders.new_table({
      results = files,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local view_file = function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        vim.cmd('e ' .. selection.value)
      end

      map('i', '<CR>', view_file)
      map('n', '<CR>', view_file)

      return true
    end,
  })

  file_picker:find()
end

function M.setup()
  -- vim.cmd([[
  --   command! -nargs=? Encrypt lua require('encrypt-text').encrypt(<f-args>)
  --   command! -nargs=? Decrypt lua require('encrypt-text').decrypt(<f-args>)
  -- ]])
  -- vim.cmd([[command! Tags lua require('note-tags').tags()]])
  -- Add keymaps to Telescope Tags and Note Tags
  -- vim.api.nvim_set_keymap('n', '<leader>f', ':Telescope Tags<CR>', { noremap = true })
  -- vim.api.nvim_set_keymap('n', '<leader>t', ':lua require("note-tags").find_files_for_tag()<CR>', { noremap = true })
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
