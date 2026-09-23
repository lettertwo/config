-- The review app's action registry: every operation a key can be bound to,
-- named once so config, keymap install, the outline's action table, and
-- refusal copy all read from the same list instead of drifting apart.
--
-- Each entry carries a `desc` and a handler per view that supports it
-- (`diff`, `outline`); a view missing from an action is not a legal binding
-- target there. The two selection ops only run from Visual mode, so their
-- diff handler carries `mode = "x"`; every other handler is normal-mode.
-- Nav handlers also carry `refocus = true`: before running, the diff-pane
-- installer moves focus to the row's primary (right) window, since nav is a
-- docket-position change that should always land the cursor where the diff
-- is read, not wherever the keypress happened to land (left pane, folded
-- gutter, etc).
--
-- A handler receives a context table (`docket`, and for outline handlers
-- `view`/`picker`; for the two selection ops, `lo`/`hi` source line numbers
-- from the visual range). `ctx.close` is the review-teardown callback,
-- supplied by whichever caller installs the action (init.lua for diff
-- panes, the outline for its own close key) — the action itself has no
-- notion of standalone-quit vs. tab-close.

local M = {}

M.list = {
  next_file = {
    desc = "next file",
    diff = { refocus = true, handler = function(ctx) ctx.docket:next_file() end },
    outline = { handler = function(ctx) ctx.docket:next_file() end },
  },
  prev_file = {
    desc = "previous file",
    diff = { refocus = true, handler = function(ctx) ctx.docket:prev_file() end },
    outline = { handler = function(ctx) ctx.docket:prev_file() end },
  },
  next_hunk = {
    desc = "next hunk",
    diff = { refocus = true, handler = function(ctx) ctx.docket:next_hunk() end },
    outline = { handler = function(ctx) ctx.docket:next_hunk() end },
  },
  prev_hunk = {
    desc = "previous hunk",
    diff = { refocus = true, handler = function(ctx) ctx.docket:prev_hunk() end },
    outline = { handler = function(ctx) ctx.docket:prev_hunk() end },
  },
  next_changeset = {
    desc = "next changeset",
    diff = { refocus = true, handler = function(ctx) ctx.docket:next_changeset() end },
    outline = { handler = function(ctx) ctx.docket:next_changeset() end },
  },
  prev_changeset = {
    desc = "previous changeset",
    diff = { refocus = true, handler = function(ctx) ctx.docket:prev_changeset() end },
    outline = { handler = function(ctx) ctx.docket:prev_changeset() end },
  },

  toggle_layout = {
    desc = "toggle side-by-side layout",
    diff = { handler = function(ctx) ctx.docket:toggle_layout() end },
    outline = { handler = function(ctx) ctx.docket:toggle_layout() end },
  },
  toggle_whole = {
    -- Refusal copy (docket.lua) reads this desc by name so the two can
    -- never drift out of sync with whatever key happens to be bound.
    desc = "toggle whole view",
    diff = { handler = function(ctx) ctx.docket:toggle_view() end },
    outline = { handler = function(ctx) ctx.docket:toggle_view() end },
  },
  stage = {
    desc = "stage",
    diff = { handler = function(ctx) ctx.docket:stage_current() end },
    outline = {
      handler = function(ctx)
        local item = ctx.picker:current()
        if not item then
          return
        end
        if item.type == "file" then
          ctx.docket:toggle_stage_file(item.change)
        elseif item.type == "dir" then
          ctx.docket:toggle_stage_tree(item.path)
        elseif item.type == "changeset" then
          ctx.docket:toggle_all()
        end
      end,
    },
  },
  discard = {
    desc = "discard",
    diff = { handler = function(ctx) ctx.docket:discard_current() end },
    outline = {
      handler = function(ctx)
        local item = ctx.picker:current()
        if item and item.change then
          ctx.docket:discard_file(item.change)
        end
      end,
    },
  },
  refresh = {
    desc = "refresh source",
    diff = { handler = function(ctx) ctx.docket:refresh() end },
    outline = { handler = function(ctx) ctx.docket:refresh() end },
  },
  close = {
    desc = "close review",
    diff = {
      handler = function(ctx)
        if require("app.review.ui.peek").close() then
          return
        end
        ctx.close()
      end,
    },
    outline = {
      handler = function(ctx)
        if require("app.review.ui.peek").close() then
          return
        end
        ctx.close()
      end,
    },
  },

  stage_file = {
    desc = "toggle-stage file",
    diff = { handler = function(ctx) ctx.docket:stage_current_file() end },
  },
  discard_file = {
    desc = "discard file",
    diff = { handler = function(ctx) ctx.docket:discard_current_file() end },
  },
  focus_outline = {
    desc = "focus outline",
    diff = {
      handler = function(ctx)
        if not ctx.docket._closed and ctx.docket.outline then
          ctx.docket.outline:open()
        end
      end,
    },
  },
  stage_selection = {
    desc = "toggle-stage selected lines",
    diff = { mode = "x", handler = function(ctx, lo, hi) ctx.docket:stage_selection(lo, hi) end },
  },
  discard_selection = {
    desc = "discard selected lines",
    diff = { mode = "x", handler = function(ctx, lo, hi) ctx.docket:discard_selection(lo, hi) end },
  },

  stage_all = {
    desc = "stage/unstage all",
    outline = { handler = function(ctx) ctx.docket:toggle_all() end },
  },
  cycle_mode = {
    desc = "cycle outline mode",
    outline = { handler = function(ctx) ctx.view:cycle_mode() end },
  },
  toggle_stack_order = {
    desc = "toggle stack order",
    outline = { handler = function(ctx) ctx.view:toggle_stack_order() end },
  },
  peek = {
    desc = "peek",
    outline = {
      handler = function(ctx)
        local item = ctx.picker:current()
        if item then
          require("app.review.ui.peek").peek(item, ctx.docket)
        end
      end,
    },
  },
}

return M
