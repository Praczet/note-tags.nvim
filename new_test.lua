local telescope = require('telescope')

telescope.setup {
  defaults = {
    layout_config = {
      preview_width = 0.5, -- default preview width
    },
    previewer = {
      cat = {
        width = 0.5, -- first previewer width
      },
      bat = {
        width = 0.5, -- second previewer width
      },
    },
  },
}

telescope.extensions.dual_selector:new {
  items = {
    { display = "Item 1", cat_preview = "This is the cat preview for item 1",
                                                                                bat_preview =
      "This is the bat preview for item 1" },
    { display = "Item 2", cat_preview = "This is the cat preview for item 2",
                                                                                bat_preview =
      "This is the bat preview for item 2" },
    { display = "Item 3", cat_preview = "This is the cat preview for item 3",
                                                                                bat_preview =
      "This is the bat preview for item 3" },
  },
  sorting_strategy = 'ascending',
  entry_maker = function(entry)
    return {
      value = entry.display,
      ordinal = entry.display,
      cat_previewer = entry.cat_preview,
      bat_previewer = entry.bat_preview,
    }
  end,
}:find()
