-- Shared nav keymap table for the docket: the commands whose effect on
-- docket.idx (or the diff cursor) both the diff panes and the outline need
-- to expose identically. Kept separate from staging/layout keymaps, whose
-- outline and diff-pane shapes are legitimately different (cursor-item vs
-- docket-position) rather than duplicated.

---@class Review.NavKeymap
---@field lhs string
---@field method string  Docket method name
---@field desc string

---@type Review.NavKeymap[]
return {
  { lhs = "]f", method = "next_file", desc = "Review: next file" },
  { lhs = "[f", method = "prev_file", desc = "Review: previous file" },
  { lhs = "]h", method = "next_hunk", desc = "Review: next hunk" },
  { lhs = "[h", method = "prev_hunk", desc = "Review: previous hunk" },
  { lhs = "]c", method = "next_changeset", desc = "Review: next changeset" },
  { lhs = "[c", method = "prev_changeset", desc = "Review: previous changeset" },
}
