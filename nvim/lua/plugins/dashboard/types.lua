---@alias Position "left" | "center" | "right"
---@alias Alignment "left" | "right"
---@alias Higroup string | [string, integer, integer][]
---@alias Element Padding | Text | Button | Group

---@class Padding
---@field type "padding"
---@field val number

---@class Text
---@field type "text"
---@field val string | string[] | fun(): string | string[]
---@field opts { position: Position, hl: Higroup }

---@class FlatText
---@field type "text"
---@field val string
---@field opts { position: Position, hl: Higroup }

---@class Button
---@field type "button"
---@field val string
---@field on_press function
---@field opts ButtonOpts

---@class ButtonOpts
---@field position Position
---@field hl Higroup
---@field shortcut string
---@field align_shortcut Alignment
---@field hl_shortcut string
---@field cursor integer
---@field width integer
---@field keymap table

---@class Group
---@field type "group"
---@field val Element[] | fun(): Element[]
---@field opts { spacing: integer }
