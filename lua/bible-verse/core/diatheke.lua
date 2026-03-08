local M = {}

--- Parse raw diatheke output to the expected format.
---@param output string raw diatheke output
---@return Verse[] verses
local function parse_raw_output(output)
  local verses = {}

  -- 1. Strip all XML/HTML tags (Strongs, Poetry, etc.)
  output = output:gsub("<[^>]+>", "")

  -- 2. Line-by-line parsing to handle broken formatting
  for line in output:gmatch("[^\r\n]+") do
    -- ^(.-)   : Captures the Book (including numbers like '1 John')
    -- %s+     : Space between Book and Chapter
    -- (%d+)   : Chapter number
    -- :(%d+): : Verse number wrapped in colons
    -- %s*(.*) : The actual verse text
    local book, chap, vnum, v = line:match("^(.-)%s+(%d+):(%d+):%s*(.*)")

    if book and chap and vnum and v then
      table.insert(verses, {
        book = vim.trim(book),
        chapter = chap,
        verse_number = vnum,
        verse_prefix_newline = false,
        verse = vim.trim(v),
        verse_suffix_newline = false,
      })
    end
  end

  return verses
end

--- Call diatheke CLI and return the parsed output.
---@param translation string translation type of bible; corresponds to -b flag of diatheke. e.g. KJV, ISV
---@param format string output_format of diatheke; corresponds to -f flag of diatheke. e.g. plain, HTML
---@param locale string locale on the local machine. e.g. en
---@param query string query to diatheke.
---@return Verse[] verses
function M.call(translation, format, locale, query)
  local command = string.format("diatheke -b %s -f %s -l %s -k %s", translation, format, locale, query)
  local command_output = vim.fn.system(command)

  if vim.v.shell_error ~= 0 then
    error("diatheke command return error|command=" .. command)
  end

  return parse_raw_output(command_output)
end

return M
