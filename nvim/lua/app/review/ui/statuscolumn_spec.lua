local statuscolumn = require("app.review.ui.statuscolumn")

describe("statuscolumn._virt_row", function()
  -- A real row is left(2) .. old .. " " .. new .. " " .. right(2).
  local function real_row(old, new, width)
    local function pad(s)
      return string.rep(" ", width - #s) .. s
    end
    return "  " .. pad(old) .. " " .. pad(new) .. " " .. "  "
  end

  it("puts the old number in the same columns as on a real row", function()
    local real = real_row("12", "14", 3)
    local virt = statuscolumn._virt_row(" 12", 3)
    assert.equals(#real, #virt)
    assert.equals(real:find("12", 1, true), virt:find("12", 1, true))
  end)

  it("is all blank, at real-row width, with no old number", function()
    local virt = statuscolumn._virt_row(nil, 3)
    assert.equals(#real_row("1", "1", 3), #virt)
    assert.is_nil(virt:find("%S"))
  end)
end)
