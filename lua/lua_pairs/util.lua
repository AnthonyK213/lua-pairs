local M = {}

---Feed keys to current buffer.
---@param str string Operation as string to feed to buffer.
function M.feed_keys(str)
    vim.api.nvim_feedkeys(M.rep_term(str), "n", true)
end

---Get characters around the cursor.
---@return table<string, string> context Context table with keys below:
---  - *p* -> The character before cursor (previous);
---  - *n* -> The character after cursor  (next);
---  - *b* -> The half line before cursor (backward);
---  - *f* -> The half line after cursor  (forward).
function M.get_ctxt()
    local context = {}
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line()
    local back = line:sub(1, col)
    local fore = line:sub(col + 1, #line)
    context.b = back
    context.f = fore
    if #back > 0 then
        local utfindex = vim.str_utfindex(back)
        local s = vim.str_byteindex(back, utfindex - 1)
        context.p = back:sub(s + 1, #back)
    else
        context.p = ""
    end
    if #fore > 0 then
        local e = vim.str_byteindex(fore, 1)
        context.n = fore:sub(1, e)
    else
        context.n = ""
    end
    return context
end

---Check if current **filetype** has `filetype`.
---@param filetype string File type to be checked.
---@return boolean result True if current **filetype** has `filetype`.
function M.has_filetype(filetype)
    return vim.tbl_contains(vim.split(vim.bo.ft, "%."), filetype)
end

---Determine if a character is a numeric/alphabetic/CJK(NAC) character.
---@param char string A character to be tested.
---@return boolean result True if the character is a NAC.
function M.is_nac(char)
    local nr = vim.fn.char2nr(char)
    return char:match("[%w_]") or (nr >= 0x4E00 and nr <= 0x9FFF)
end

---Check the surrounding characters of the cursor.
---@param pair_table table Defined pairs to index.
---@return boolean result True if the cursor is surrounded by `pair_table`.
function M.is_sur(pair_table)
    local context = M.get_ctxt()
    return pair_table[context.p] == context.n
end

---Convert string to terminal codes.
---@param str string String to be converted.
---@return string terminal_code Termianl code.
function M.rep_term(str)
    return vim.api.nvim_replace_termcodes(str, true, false, true)
end

return M
