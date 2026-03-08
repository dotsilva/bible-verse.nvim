local M = {}

--- Parse raw diatheke output to the expected format.
---@param output string raw diatheke output
---@return Verse[] verses
local function parse_raw_output(output)
  local verses = {}

  -- 1. Strip XML/HTML tags
  output = output:gsub("<[^>]+>", "")

  -- 2. State machine to accumulate multi-line verses
  local current_verse = nil

  for line in output:gmatch("[^\r\n]+") do
    line = vim.trim(line)

    -- Skip empty lines and the translation footer (e.g., "(ASV)")
    if line ~= "" and not line:match("^%([%w]+%)$") then
      -- Look for a new verse header: "Book Name 1:2: Text"
      local book, chap, vnum, text = line:match("^(.-)%s+(%d+):(%d+):%s*(.*)")

      if book and chap and vnum then
        -- Save the previous verse before starting a new one
        if current_verse then
          table.insert(verses, current_verse)
        end

        -- Start accumulating the new verse
        current_verse = {
          book = vim.trim(book),
          chapter = chap,
          verse_number = vnum,
          verse_prefix_newline = false,
          verse = vim.trim(text),
          verse_suffix_newline = false,
        }
      elseif current_verse then
        -- If no header is found, this line belongs to the current verse. Append it.
        current_verse.verse = current_verse.verse .. " " .. line
      end
    end
  end

  -- Push the final accumulated verse into the table
  if current_verse then
    table.insert(verses, current_verse)
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
