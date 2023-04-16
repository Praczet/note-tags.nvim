# note-tags

**THIS IS WIP** and for now there is no point to install it :-) Still learning

Some update it starts to look like plugin I wanted... It can read folder, it can read tags from files, it supports <!--tags--> section.

Now it almost works... Still how to read config? How to dynamically change Previewer title, and a few questions..

Ok. This is my second plugin. This time I will try to use telescope. The main purpose of it is to tags notes. On the bottom of notes I am putting tags such as `#sql #JSON` etc. This plugin should open Telescope read all tags from files in a folder[^1] and display list in telescope. After selecting tag it should show list of files having this tag.

# ToDo

- [x] Add Mapping for control + O to open notes filtered by tag
- [ ] Add reading data from config, which I have no Idea how
- [ ] Add Mapping for leader n
  - [x] Add mapping for <C-n> to create new tag
- [ ] Add it as extension of Telescope

[^1]: Folder should be or declared in config or plugin will take current one.
