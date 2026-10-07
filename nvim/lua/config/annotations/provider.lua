-- Lets a module that owns scratch buffers (no file path, line numbers that
-- aren't the file's) show and create annotations in them, without this
-- module knowing about it. A provider claims buffers with `match`, turns a
-- buffer line range into the record fields with `resolve`, and maps a
-- stored record back to buffer lines with `rows`.
--
---@class Config.Annotations.Target
---@field file string repo-relative path
---@field rev? string see Config.Annotations.Record.rev
---@field lnum integer line in the file at `rev`
---@field end_lnum integer
---@field anchor_text string

---@class Config.Annotations.Provider
---@field name? string registering the same name again replaces the earlier provider
---@field match fun(buf: integer): boolean
---@field resolve fun(buf: integer, lnum: integer, end_lnum: integer): Config.Annotations.Target?  notifies and returns nil when the range has no source line
---@field rows fun(buf: integer, rec: Config.Annotations.Record): integer?, integer?  first and last buffer line (1-indexed) the record is drawn on, nil when this buffer doesn't show it

local Provider = {}

---@type Config.Annotations.Provider[]
local providers = {}

---@param provider Config.Annotations.Provider
function Provider.register(provider)
  if provider.name then
    for i, existing in ipairs(providers) do
      if existing.name == provider.name then
        providers[i] = provider
        return
      end
    end
  end
  table.insert(providers, provider)
end

---@param buf integer
---@return Config.Annotations.Provider?
function Provider.for_buf(buf)
  for _, provider in ipairs(providers) do
    if provider.match(buf) then
      return provider
    end
  end
end

return Provider
