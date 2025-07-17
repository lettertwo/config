local StringUtil = require("util.string")

describe("StringUtil.capcase", function()
  it("capitalizes the first character", function()
    assert.equals("Hello", StringUtil.capcase("hello"))
  end)

  it("returns string unchanged if already capitalized", function()
    assert.equals("Hello", StringUtil.capcase("Hello"))
  end)

  it("handles empty string", function()
    assert.equals("", StringUtil.capcase(""))
  end)

  it("handles single character", function()
    assert.equals("A", StringUtil.capcase("a"))
    assert.equals("B", StringUtil.capcase("B"))
  end)

  it("handles strings starting with non-letter", function()
    assert.equals("1test", StringUtil.capcase("1test"))
    assert.equals("_underscore", StringUtil.capcase("_underscore"))
  end)
end)

describe("StringUtil.format_highlight", function()
  it("formats string with highlight group", function()
    assert.equals("%#ErrorMsg#hello%*", StringUtil.format_highlight("hello", "ErrorMsg"))
  end)

  it("works with empty string", function()
    assert.equals("%#WarningMsg#%*", StringUtil.format_highlight("", "WarningMsg"))
  end)

  it("works with empty group", function()
    assert.equals("%##hello%*", StringUtil.format_highlight("hello", ""))
  end)

  it("works with both empty", function()
    assert.equals("%##%*", StringUtil.format_highlight("", ""))
  end)

  it("handles special characters in string", function()
    assert.equals("%#InfoMsg#hello_world!%*", StringUtil.format_highlight("hello_world!", "InfoMsg"))
  end)
end)

describe("StringUtil.smart_shorten_path", function()
  it("returns path unchanged if shorter than target width", function()
    local path = "src/main.lua"
    assert.equals("src/main.lua", StringUtil.smart_shorten_path(path, { target_width = 20 }))
  end)

  it("shortens path if longer than target width", function()
    local path = "src/plugins/lsp/util/main.lua"
    local shortened = StringUtil.smart_shorten_path(path, { target_width = 15 })
    assert.is_true(#shortened < #path)
  end)

  it("handles ambiguous segments", function()
    local path = "src/tests/plugins/lsp/util/main.lua"
    local shortened = StringUtil.smart_shorten_path(path, { target_width = 18 })
    assert.is_true(#shortened <= 18)
  end)

  it("uses custom cwd for normalization", function()
    local path = "../project/util/main.lua"
    local shortened = StringUtil.smart_shorten_path(path, { cwd = "/home/user/project", target_width = 20 })
    assert.equals("p/util/main.lua", shortened)
  end)

  it("returns buffer name if path is nil", function()
    vim.api.nvim_buf_set_name(0, "tmp/test.lua")
    assert.equals("tmp/test.lua", StringUtil.smart_shorten_path(nil))
  end)

  it("returns path unchanged if exactly at target width", function()
    local path = "src/main.lua"
    assert.equals("src/main.lua", StringUtil.smart_shorten_path(path, { target_width = #path }))
  end)
end)

describe("Next.js app router patterns", function()
  it("matches page and default files", function()
    assert.is_true(StringUtil.matches_any_pattern("app/(group)/page.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/@auth/[id]/default.js"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/page.tsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/default.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/page.mdx"))
    assert.is_true(StringUtil.matches_any_pattern("app/test/page.md"))
    assert.is_true(StringUtil.matches_any_pattern("nested/app/resume/page.mdx"))
  end)

  it("matches forbidden, not-found, unauthorized files", function()
    assert.is_true(StringUtil.matches_any_pattern("app/[user]/forbidden.tsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/not-found.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/@bar/unauthorized.js"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/forbidden.tsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/not-found.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/unauthorized.js"))
  end)

  it("matches layout, loading, error, template files", function()
    assert.is_true(StringUtil.matches_any_pattern("app/(group)/loading.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/@admin/error.js"))
    assert.is_true(StringUtil.matches_any_pattern("app/[slug]/template.tsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/layout.tsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/loading.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/error.js"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/template.tsx"))
  end)

  it("matches api route files", function()
    assert.is_true(StringUtil.matches_any_pattern("app/api/route.ts"))
    assert.is_true(StringUtil.matches_any_pattern("app/(group)/api/route.js"))
    assert.is_true(StringUtil.matches_any_pattern("app/@foo/[bar]/api/route.jsx"))
    assert.is_true(StringUtil.matches_any_pattern("app/(foo)/@bar/[baz]/api/route.tsx"))
  end)

  it("does not match root-level Next.js files", function()
    assert.is_false(StringUtil.matches_any_pattern("app/page.tsx"))
    assert.is_false(StringUtil.matches_any_pattern("app/error.jsx"))
    assert.is_false(StringUtil.matches_any_pattern("app/route.jsx"))
    assert.is_false(StringUtil.matches_any_pattern("app/page.mdx"))
  end)

  it("does not match unrelated files", function()
    assert.is_false(StringUtil.matches_any_pattern("pages/index.tsx"))
    assert.is_false(StringUtil.matches_any_pattern("app/somefile.ts"))
    assert.is_false(StringUtil.matches_any_pattern("app/page.md"))
    assert.is_false(StringUtil.matches_any_pattern("app/layout.css"))
    assert.is_false(StringUtil.matches_any_pattern("app/api/route.go"))
  end)
end)

describe("StringUtil.title_path", function()
  it("handles root-level Next.js files", function()
    assert.equals("page.tsx", StringUtil.title_path("app/page.tsx"))
    assert.equals("error.jsx", StringUtil.title_path("app/error.jsx"))
  end)

  it("handles nested Next.js files", function()
    assert.equals("(group)/page.jsx", StringUtil.title_path("app/(group)/page.jsx"))
    assert.equals("@auth/[id]/default.js", StringUtil.title_path("app/@auth/[id]/default.js"))
    assert.equals("(foo)/@bar/[baz]/layout.tsx", StringUtil.title_path("app/(foo)/@bar/[baz]/layout.tsx"))
    assert.equals("resume/page.mdx", StringUtil.title_path("app/resume/page.mdx"))
  end)

  it("handles Next.js pattern with ambiguous segment", function()
    assert.equals("tests/page.tsx", StringUtil.title_path("app/tests/page.tsx"))
  end)

  it("handles non-ambiguous segments and files", function()
    assert.equals("util.lua", StringUtil.title_path("lua/plugins/lsp/util.lua"))
    assert.equals("Button.tsx", StringUtil.title_path("src/components/Button.tsx"))
    assert.equals("main.go", StringUtil.title_path("main.go"))
  end)

  it("handles ambiguous filetypes", function()
    assert.equals("lsp/init.lua", StringUtil.title_path("lua/plugins/lsp/init.lua"))
    assert.equals("pkg/index.js", StringUtil.title_path("packages/pkg/index.js"))
    assert.equals("crate/lib.rs", StringUtil.title_path("crates/crate/lib.rs"))
    assert.equals("docs/README.md", StringUtil.title_path("packages/pkg/docs/README.md"))
  end)

  it("handles ambiguous segments with ambiguous filetypes", function()
    assert.equals("lib/tests/main.rs", StringUtil.title_path("packages/pkg/lib/tests/main.rs"))
    assert.equals("lib/__tests__/README.md", StringUtil.title_path("lib/__tests__/README.md"))
    assert.equals("pkg/src/index.js", StringUtil.title_path("packages/pkg/src/index.js"))
    assert.equals("plugins/tests/lib/init.lua", StringUtil.title_path("plugins/tests/lib/init.lua"))
  end)

  it("handles ambiguous segment at root", function()
    assert.equals("tests/main.rs", StringUtil.title_path("tests/main.rs"))
  end)

  it("handles path with no filename", function()
    assert.equals("example", StringUtil.title_path("neat/example/"))
  end)

  it("handles custom options overriding defaults", function()
    local opts = {
      ambiguous_filetypes = { "custom.js" },
      ambiguous_segments = { "customseg" },
    }
    assert.equals("btw/customseg/custom.js", StringUtil.title_path("ex/src/btw/customseg/custom.js", opts))
    assert.equals("example/customseg/after.js", StringUtil.title_path("neat/example/customseg/after.js", opts))
    assert.equals("ex/customseg/btw/custom.js", StringUtil.title_path("neat/ex/customseg/btw/custom.js", opts))
    assert.equals("randomseg/custom.js", StringUtil.title_path("neat/ex/randomseg/custom.js", opts))
  end)
end)

describe("StringUtil.timeago", function()
  it("returns 'just now' for current time", function()
    assert.equals("just now", StringUtil.timeago(os.time()))
  end)

  it("returns minutes ago", function()
    local t = os.time() - 60
    assert.equals("1 minute ago", StringUtil.timeago(t))
    t = os.time() - 120
    assert.equals("2 minutes ago", StringUtil.timeago(t))
  end)

  it("returns hours ago", function()
    local t = os.time() - 3600
    assert.equals("1 hour ago", StringUtil.timeago(t))
    t = os.time() - 7200
    assert.equals("2 hours ago", StringUtil.timeago(t))
  end)

  it("returns days ago", function()
    local t = os.time() - 86400
    assert.equals("1 day ago", StringUtil.timeago(t))
    t = os.time() - 172800
    assert.equals("2 days ago", StringUtil.timeago(t))
  end)
end)
