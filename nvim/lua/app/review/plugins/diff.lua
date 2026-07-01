-- codediff provides the word-level diff engine (app.review.diff.word).
-- Config.add is idempotent — the default app also adds this repo, so the
-- duplicate add is a no-op when review runs embedded there.
Config.add("esmuellert/codediff.nvim")
