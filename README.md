# note-tags

This plugin is still in the WIP mode which means not all function works.. For example: register extension to Telescope, or this annoying message about success.
However it is in the state of - **_you can use, but do not complain_**.

And this is my only the second plugin for neovim (or rather for LunarVim) and also my second script in lua so... Do not hit, just explain!

## Introduction

The main idea behind this plugin is to be able go thru #tags (just words with the # at the beginning) that are added in my notes file.
As I was not able to make a decision which approach to take for searching for tags I created for both (separator | wholeFile)

- **Separator** - is a model where `note-tags` gets tags from file after a line with separator.
- **wholeFile** - is a model where `note-tags` gets tags from file not matter where they appear

General usage if this plugin could be described as:

- Displaying list of tags `:Tags`
- Displaying list of notes `:Notes`
- Adding tags to current buffer (from previewer `<CR>`)
- Displaying Notes for a selected tag (from previewer `<C-n>`)
- Adding new tag (from previewer `<C-a>`)

## Installation (not ready)

## Configuration

You can configure:

- **notes_folder** - Folder with notes, if you sets it as '' it will take current working folder
- **read_tag_method** - Method how plugin reads tags:
  - **_separator_** - it will reads tags after line with separator
  - **_wholeFile_** - it will looks for tags in file
- **tags_separator** - separator default: <!--tags--> it is needed when read_tag_method = seperator

```lua
{
  "Praczet/note-tags.nvim",
  config = function()
    require("note-tags").setup({
      notes_folder    = "~/Notes",     -- optional (default: current folder)
      read_tag_method = "separator",   -- optional (default: separator)
      separator       = "<!--tags-->", -- optional (default: <!--tags-->)
    })
  end
}
```

## ToDo

- [x] Add Mapping for control + O to open notes filtered by tag
- [x] Add reading data from config, which I have no Idea how
- [x] Add Mapping for leader n
  - [x] Add mapping for `<C-a>` to create new tag
  - [x] Add mapping for `<C-t>` - Tags
  - [x] Add mapping for `<C-n>` - Notes
  - [ ] Add proper way to name Group (for `<leader>n`)
- [ ] Add it as extension of Telescope
- [ ] Fill this file (README.md)
  - [ ] Introduction
  - [ ] Installation
  - [ ] Screenshots
  - [ ] Usage

[^1]: Folder should be or declared in config or plugin will take current one.
