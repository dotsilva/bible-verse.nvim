local M = {}

--- Parse raw diatheke output to the expected format.
--- Converts multi-line, tagged SWORD module output into a clean Lua table.
---@param output string raw diatheke output
---@return Verse[] verses
local function parse_raw_output(output)
  local verses = {}

  -- 1. SANITIZATION
  -- Strip all OSIS XML/HTML tags (e.g., <w>, <l>, <lg>).
  -- This is required for critical text modules like ASV, LEB, and SBLGNT
  -- which embed Strong's numbers and poetry markers directly in the text.
  output = output:gsub("<[^>]+>", "")

  -- 2. STATE MACHINE INITIALIZATION
  -- We use a state machine instead of a single regex because diatheke
  -- often uses hard line breaks mid-sentence for poetic stanzas.
  local current_verse = nil

  -- Iterate through the sanitized output line-by-line
  for line in output:gmatch("[^\r\n]+") do
    -- Trim trailing spaces, but preserve leading spaces for paragraph detection
    -- We will trim the final strings before insertion.
    local trimmed_line = vim.trim(line)

    -- Skip empty lines and translation footers (e.g., "(ASV)", "(KJV)")
    if trimmed_line ~= "" and not trimmed_line:match("^%([%w]+%)$") then
      -- Look for a standard verse header.
      -- Capture Groups:
      -- 1. ^(.-)   : Book name (lazy match to support numbered books like '1 John')
      -- 2. (%d+)   : Chapter number
      -- 3. (%d+)   : Verse number
      -- 4. (%s*)   : Whitespace immediately following the colon (crucial for paragraph detection)
      -- 5. (.*)    : The actual verse text on this line
      local book, chap, vnum, space, text = line:match("^(.-)%s+(%d+):(%d+):(%s*)(.*)")

      if book and chap and vnum then
        -- A new verse header was found.
        -- Push the previously accumulated verse into the results table.
        if current_verse then
          table.insert(verses, current_verse)
        end

        -- PARAGRAPH DETECTION (Backward Compatibility)
        -- Diatheke signals a paragraph break either by outputting the text
        -- on a completely new line (text == ""), or by injecting multiple
        -- spaces after the colon (space:len() > 1).
        local is_paragraph_break = string.len(space) > 1 or text == ""

        -- Start accumulating the new verse
        current_verse = {
          book = vim.trim(book),
          chapter = chap,
          verse_number = vnum,
          verse_prefix_newline = is_paragraph_break,
          verse = vim.trim(text),
          verse_suffix_newline = false,
        }
      elseif current_verse then
        -- No header found. This line is a continuation of the current verse
        -- due to a hard line break in the SWORD module.

        -- Append the text. If the buffer is currently empty (due to a paragraph break),
        -- assign it directly to prevent injecting an unwanted leading space.
        if current_verse.verse == "" then
          current_verse.verse = trimmed_line
        else
          current_verse.verse = current_verse.verse .. " " .. trimmed_line
        end
      end
    end
  end

  -- Loop finished. Push the final accumulated verse into the table.
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
