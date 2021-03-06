-- File:       lua-pairs.lua
-- Repository: https://github.com/AnthonyK213/nvim
-- License:    The MIT License (MIT)


local M = {}
local vim = vim
local api = vim.api

local opt = {}
local lp_comm = {
    ["("] = ")",
    ["["] = ']',
    ["{"] = "}",
    ["'"] = "'",
    ['"'] = '"'
}
local left  = '<C-G>U<Left>'
local right = '<C-G>U<Right>'


---Extend table b to a.
---@param a table Table to be extended.
---@param b table Table to extend.
local tbl_extd = function(a, b)
    for key, val in pairs(b) do a[key] = val end
end

---Remove first item with value `val` in table.
---@param tbl table Table to operate.
---@param val any Item value to remove.
local tbl_remove = function(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            table.remove(tbl, i)
            return
        end
    end
end

---Convert string to terminal codes.
---@param str string String to be converted.
---@return string terminal_code Termianl code.
local rep_term = function(str)
    return api.nvim_replace_termcodes(str, true, false, true)
end

---Feed keys to current buffer.
---@param str string Operation as string to feed to buffer.
local feed_keys = function(str)
    api.nvim_feedkeys(rep_term(str), 'n', true)
end

---Determine if a character is a numeric/alphabetic/CJK(NAC) character.
---@param char string A character to be tested.
---@return boolean result True if the character is a NAC.
local function is_NAC(char)
    local nr = vim.fn.char2nr(char)
    return char:match('[%w_]') or (nr >= 0x4E00 and nr <= 0x9FFF)
end

---Get characters around the cursor.
---@return table<string, string> context Context table with keys below:
---  - *p* -> The character before cursor (previous);
---  - *n* -> The character after cursor  (next);
---  - *b* -> The half line before cursor (backward);
---  - *f* -> The half line after cursor  (forward).
local function get_ctxt()
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

---Define the buffer variables.
---@bufvar lp_prev_spec string    No paifing if the previous character matches.
---@bufvar lp_next_spec string    No pairing if the next character matches.
---@bufvar lp_back_spec string    No pairing if the left half line matches.
---@bufvar lp_buf       hashtable { (string)pair_left = (string)pair_right }
---@bufvar lp_buf_map   hashtable { (string)key = (string)pair_type }
---  - *enter* -> Enter/Return;
---  - *backs* -> Backspace;
---  - *supbs* -> Super backspace;
---  - *space* -> Space;
---  - *mates* -> A pair of characters consisting of different characters;
---  - *quote* -> A pair of characters consisting of identical characters;
---  - *close* -> Character to close a pair (right part of a pair).
---@bufvar lp_map_list  arraytable { (string)keys_to_map }
local function def_var()
    vim.b.lp_prev_spec = "[\"'\\]"
    vim.b.lp_next_spec = "[\"']"
    vim.b.lp_back_spec = "[^%s%S]"
    local lp_comm_copy = vim.deepcopy(lp_comm)
    local lp_buf_map = {
        ["<CR>"]    = "enter",
        ["<BS>"]    = "backs",
        ["<M-BS>"]  = "supbs",
        ["<SPACE>"] = "space"
    }
    local lp_map_list = { "(", "[", "{", ")", "]", "}", "'", '"' }

    if vim.bo.filetype == 'vim' then
        vim.b.lp_back_spec = '^%s*$'
    elseif vim.bo.filetype == 'rust' then
        vim.b.lp_prev_spec = "[\"'\\&<]"
    elseif vim.bo.filetype == 'lisp' then
        lp_comm_copy["'"] = nil
        tbl_remove(lp_map_list, "'")
    elseif vim.tbl_contains({ 'html', 'xml' }, vim.bo.filetype) then
        table.insert(lp_map_list, '<')
        table.insert(lp_map_list, '>')
        lp_comm_copy['<'] = '>'
    end

    local lp_buf = {}

    for key, val in pairs(lp_comm_copy) do
        if val then
            lp_buf[key] = val
            if key == val then
                if #val == 1 then
                    lp_buf_map[key] = 'quote'
                else
                    lp_buf_map[key] = 'mates'
                end
            else
                lp_buf_map[key] = 'mates'
                lp_buf_map[val] = 'close'
            end
        end
    end

    vim.b.lp_buf = lp_buf
    vim.b.lp_buf_map = lp_buf_map
    vim.b.lp_map_list = lp_map_list
end

---Check the surrounding characters of the cursor.
---@param pair_table table Defined pairs to index.
---@return boolean result True if the cursor is surrounded by `pair_table`.
local function is_sur(pair_table)
    local context = get_ctxt()
    return pair_table[context.p] and vim.b.lp_buf[context.p] == context.n
end

---Difine buffer key maps.
---@param kbd string Key binding.
---@param key string Key to feed to the buffer.
local function def_map(kbd, key)
    vim.keymap.set('i', kbd, function ()
        require("lua-pairs")["lp_"..vim.b.lp_buf_map[key]](key)
    end, { noremap = true, expr = false, silent = true, buffer = true })
end



---Clear key maps of current buffer according to `b:lp_map_list`.
function M.clr_map()
    if vim.b.lp_map_list then
        for _, key in ipairs(vim.b.lp_map_list) do
            vim.keymap.del('i', key, { buffer = true })
        end
        vim.b.lp_map_list = nil
    end
end

---Actions on <CR>.
---Inside a pair of brackets:
---  {|} -> feed <CR> -> {<br>|<br>}
function M.lp_enter(_)
    local context = get_ctxt()
    if is_sur(vim.b.lp_buf) then
        feed_keys('<CR><C-\\><C-O>O')
    elseif context.b:match('{%s*$') and context.f:match('^%s*}') then
        feed_keys('<C-\\><C-O>"_diB<CR><C-\\><C-O>O')
    else
        feed_keys('<CR>')
    end
end

---Actions on <BS>.
---Inside a defined pair(1 character):
---  (|) -> feed <BS> -> |
---Inside a pair of barces with one space:
---  { | } -> feed <BS> -> {|}
function M.lp_backs(_)
    local context = get_ctxt()
    if is_sur(vim.b.lp_buf) then
        feed_keys(right..'<BS><BS>')
    elseif context.b:match('{%s$') and context.f:match('^%s}') then
        feed_keys('<C-\\><C-O>"_diB')
    else
        feed_keys('<BS>')
    end
end

---Super backspace.
---Inside a defined pair(no length limit):
---  <u>|</u> -> feed <M-BS> -> |
---Kill a word:
---  Kill a word| -> feed <M-BS> -> Kill a |
function M.lp_supbs(_)
    local context = get_ctxt()
    local back = context.b
    local fore = context.f
    local res = { false, 0, 0 }
    for key, val in pairs(vim.b.lp_buf) do
        if (back:match(vim.pesc(key)..'$') and
            fore:match('^'..vim.pesc(val)) and
            #key + #val > res[2] + res[3]) then
            res = { true, #key, #val }
        end
    end
    if res[1] then
        feed_keys(string.rep(left, res[2])..
        string.rep('<Del>', res[2] + res[3]))
    elseif back:match('{%s*$') and fore:match('^%s*}') then
        feed_keys('<C-\\><C-O>"_diB')
    else
        feed_keys('<C-\\><C-O>"_db')
    end
end

---Actions on <SPACE>.
---Inside a pair of braces:
---  {|} -> feed <SPACE> -> { | }
function M.lp_space(_)
    local keys = is_sur({ ['{']='}' }) and
    '<SPACE><SPACE>'..left or '<SPACE>'
    feed_keys(keys)
end

---Complete *mates*:
---  | -> feed ( -> (|)
---  | -> feed defined_kbd -> pair_a|pair_b
---Before a NAC character:
---  |a -> feed ( -> (|a
---@param pair_a string Left part of a pair of *mates*.
function M.lp_mates(pair_a)
    local keys
    if is_NAC(get_ctxt().n) then
        keys = pair_a
    else
        local pair_b = vim.b.lp_buf[pair_a]
        keys = pair_a..pair_b..string.rep(left, #pair_b)
    end
    feed_keys(keys)
end

---Inside a defined pair:
---  (|) -> feed ) -> ()|
---@param pair_b string Right part of a pair of *mates*.
function M.lp_close(pair_b)
    local keys = get_ctxt().n == pair_b and right or pair_b
    feed_keys(keys)
end

---Complete *quote*:
---  | -> feed " -> "|"
---Next character is *quote*:
---  |" -> feed " -> "|
---After the escape character("\"), a *quote* character or a NAC character:
---  \| -> feed " -> \"|
---  "| -> feed " -> ""|
---  a| -> feed " -> a"|
---Before a NAC character:
---  |a -> feed " -> "|a
---@param quote string Left part of a pair of *quote*.
function M.lp_quote(quote)
    local context = get_ctxt()
    local prev_char = context.p
    local next_char = context.n
    local keys
    if next_char == quote then
        keys = right
    elseif (prev_char == quote or
        is_NAC(prev_char) or
        is_NAC(next_char) or
        prev_char:match(vim.b.lp_prev_spec) or
        next_char:match(vim.b.lp_next_spec) or
        context.b:match(vim.b.lp_back_spec)) then
        keys = quote
    else
        keys = quote..quote..left
    end
    feed_keys(keys)
end

---Define variables and key maps in current buffer.
function M.def_all()
    local exclude = opt.exclude or {}
    local buftype = exclude.buftype or {}
    local filetype = exclude.filetype or {}
    if vim.b.lp_map_list
        or vim.tbl_contains(buftype, vim.bo.bt)
        or vim.tbl_contains(filetype, vim.bo.ft) then
        return
    end

    if opt.extd then
        tbl_extd(lp_comm, opt.extd)
    end

    def_var()

    local ret = opt.ret == nil and true or opt.ret
    local bak = opt.bak == nil and true or opt.bak
    local spc = opt.spc == nil and true or opt.spc

    if ret then
        def_map('<CR>', '<CR>')
    else
        api.nvim_set_keymap(
        'i',
        '<Plug>(lua_pairs_enter)',
        '<CMD>lua require("lua-pairs").lp_enter()<CR>',
        { silent = true, expr = false, noremap = true })
    end

    if bak then
        def_map("<BS>", "<BS>")
        def_map("<M-BS>", "<M-BS>")
    end

    if spc then
        def_map("<SPACE>", "<SPACE>")
    end

    for _, key in ipairs(vim.b.lp_map_list) do
        def_map(key, key)
    end

    if opt.extd_map then
        for key, val in pairs(opt.extd_map) do
            def_map(key, val)
        end
    end
end

---Set up **lua-pairs**.
---@param option table User configuration.
-- | Option   | Type      | Description                            |
-- |----------|-----------|----------------------------------------|
-- | ret      | boolean   | True to map <CR>                       |
-- | bak      | boolean   | True to map <BS> and <M-BS>            |
-- | spc      | boolean   | True to map <SPACE>                    |
-- | extd     | hashtable | To extend the default pairs            |
-- | extd_map | hashtable | To define key bindings of extend pairs |
-- | exclude  | table     | Excluded buffer types and file types   |
function M.setup(option)
    opt = option or {}

    local id = api.nvim_create_augroup("lp_buffer_update", {
        clear = true
    })

    api.nvim_create_autocmd("BufEnter", {
        group = id,
        pattern = "*",
        callback = M.def_all
    })

    api.nvim_create_autocmd("FileType", {
        group = id,
        pattern = "*",
        callback = function ()
            M.clr_map()
            M.def_all()
        end
    })
end


return M
