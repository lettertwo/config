-- TODO: Extract into some kinda telescope-git-jump plugin?
-- things jump can do:
-- - jump to hunks in diff
-- - jump to conflicts in merge
-- - jump to matches in grep (not sure if this is all that useful?)
-- - jump to whitespace errors in diff
-- See https://github.com/git/git/tree/master/contrib/git-jump

return require("telescope").register_extension({
  setup = require("telescope._extensions.git_jump.config"),
  exports = {
    hunks = require("telescope._extensions.git_jump.hunks"),
  },
})
