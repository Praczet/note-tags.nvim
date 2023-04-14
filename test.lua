local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values

-- Define the left and right column tables
local left_column = { 'apple', 'banana', 'cherry', 'date' }
local right_column = { 'orange', 'pineapple', 'raspberry', 'strawberry' }

-- Define the picker
local picker = pickers.new({}, {
  results_title = "Tags",
  prompt_title = "Search for tags",
  finder = finders.new_table({
    results = left_column,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry,
        ordinal = entry,
      }
    end
  }),
  sorter = sorters.get_generic_fuzzy_sorter(),
  previewer = previewers.new_buffer_previewer({
    title = "Notes",
    width = 0.8,
    define_preview = function(self, entry, status)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { 'Preview: ' .. entry.value, "asds" })
    end
  }),
  attach_mappings = function(prompt_bufnr)
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry(prompt_bufnr)
      print('Selected:', selection.left, selection.right)
      actions.close(prompt_bufnr)
    end)

    return true
  end,
  layout_config = {
    width = 0.5,
    height = 0.8,
    prompt_position = "top",
    preview_cutoff = 1,
    horizontal = {
      preview_width = function(_, cols, _)
        return math.floor(cols * 0.4)
      end,
    },
  },
})

-- Add the left and right column tables to the picker
-- for _, left in ipairs(left_column) do
--   for _, right in ipairs(right_column) do
--     picker:a({ left = left, right = right })
--   end
-- end

-- Display the picker
picker:find()
