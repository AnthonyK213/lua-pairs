-- File:       lua-pairs.lua
-- Repository: https://github.com/AnthonyK213/nvim
-- License:    The MIT License (MIT)


local M = {}
local vim = vim
local api = vim.api

local opt = {}
local lp_comm={ ["("]=")", ["["]=']', ["{"]="}", ["'"]="'", ['"']='"' }

local left  = '<C-g>U<Left>'
local right = '<C-g>U<Right>'


---------- Local functions ---------

--- Extend table b to a.
--- @param a table Table to be extended.
--- @param b table Table to extend.
local tab_extd = function(a, b)
    for key, val in pairs(b) do a[key] = val end
end

--- Convert string to terminal codes.
--- @param str string String to be converted.
--- @return string terminal_code Termianl code.
local rep_term = function(str)
    return api.nvim_replace_termcodes(str, true, false, true)
end

--- Feed keys to current buffer.
--- @param str string Operation as string to feed to buffer.
local feed_keys = function(str)
    api.nvim_feedkeys(rep_term(str), 'n', true)
end

--- Determine if a character is a numeric/alphabetic/CJK(NAC) character.
--- @param char string A character to be tested.
--- @return boolean result True if the character is a NAC.
local function is_NAC(char)
    local nr = vim.fn.char2nr(char)
    return char:match('[%w_]') or (nr >= 0x4E00 and nr <= 0x9FFF)
end

local get_ctxt_pat = {
    p = { [[.\%]], [[c]] },
    n = { [[\%]], [[c.]] },
    b = { [[^.*\%]], 'c' },
    f = { [[\%]], 'c.*$' }
}

--- Get characters around the cursor by `mode`.
--- @param mode string Four modes to get the context.
---   - *p* -> Return the character before cursor (previous);
---   - *n* -> Return the character after cursor  (next);
---   - *b* -> Return the half line before cursor (backward);
---   - *f* -> Return the half line after cursor  (forward).
--- @return string context Characters around the cursor.
local function get_ctxt(mode)
    local pat = get_ctxt_pat[mode]
    local line = api.nvim_get_current_line()
    local s, e = vim.regex(
    pat[1]..(api.nvim_win_get_cursor(0)[2] + 1)..pat[2]):match_str(line)
    if s then
        return line:sub(s + 1, e)
    else
        return ""
    end
end

--- Define the buffer variables.
--- @bufvar lp_prev_spec string    No paifing if the previous character matches.
--- @bufvar lp_next_spec string    No pairing if the next character matches.
--- @bufvar lp_back_spec string    No pairing if the left half line matches.
--- @bufvar lp_buf       hashtable { (string)pair_left = (string)pair_right }
--- @bufvar lp_buf_map   hashtable { (string)key = (string)pair_type }
---   - *enter* -> Enter/Return;
---   - *backs* -> Backspace;
---   - *supbs* -> Super backspace;
---   - *space* -> Space;
---   - *mates* -> A pair of characters consisting of different characters;
---   - *quote* -> A pair of characters consisting of identical characters;
---   - *close* -> Character to close a pair (right part of a pair).
--- @bufvar lp_map_list  arraytable { (string)keys_to_map }
local function def_var()
    vim.b.lp_prev_spec = "[\"'\\]"
    vim.b.lp_next_spec = "[\"']"
    vim.b.lp_back_spec = "[^%s%S]"
    local lp_buf = vim.deepcopy(lp_comm)
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
        lp_buf["'"] = nil
    elseif vim.tbl_contains({ 'html', 'xml' }, vim.bo.filetype) then
        table.insert(lp_map_list, '<')
        table.insert(lp_map_list, '>')
        lp_buf['<'] = '>'
    end

    for key, val in pairs(lp_buf) do
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

    vim.b.lp_buf = lp_buf
    vim.b.lp_buf_map = lp_buf_map
    vim.b.lp_map_list = lp_map_list
end

--- Check the surrounding characters of the cursor.
--- @param pair_table table Defined pairs to index.
--- @return boolean result True if the cursor is surrounded by `pair_table`.
local function is_sur(pair_table)
    local prev_char = get_ctxt('p')
    return pair_table[prev_char] and vim.b.lp_buf[prev_char] == get_ctxt('n')
end

--- Difine buffer key maps.
--- @param kbd string Key binding.
--- @param key string Key to feed to the buffer.
local function def_map(kbd, key)
    local k = key:match('<%u.*>') and '' or '"'..vim.fn.escape(key, '"')..'"'
    api.nvim_buf_set_keymap(
    0, 'i', kbd,
    '<CMD>lua require("lua-pairs").lp_'..vim.b.lp_buf_map[key]..'('..k..')<CR>',
    { noremap = true, expr = false, silent = true })
end


---------- Module functions ---------

--- Clear key maps of current buffer according to `b:lp_map_list`.
function M.clr_map()
    if vim.b.lp_map_list then
        for _, key in ipairs(vim.b.lp_map_list) do
            api.nvim_buf_set_keymap(0, 'i', key, key,
            { noremap = true, expr = false, silent = true })
        end
        vim.b.lp_map_list = nil
    end
end

--- Actions on <CR>.
--- Inside a pair of brackets:
---   {|} -> feed <CR> -> {<br>|<br>}
function M.lp_enter()
    if is_sur(vim.b.lp_buf) then
        feed_keys('<CR><C-\\><C-O>O')
    elseif get_ctxt('b'):match('{%s*$') and
        get_ctxt('f'):match('^%s*}') then
        feed_keys('<C-\\><C-O>diB<CR><C-\\><C-O>O')
    else
        feed_keys('<CR>')
    end
end

--- Actions on <BS>.
--- Inside a defined pair(1 character):
---   (|) -> feed <BS> -> |
--- Inside a pair of barces with one space:
---   { | } -> feed <BS> -> {|}
function M.lp_backs()
    if is_sur(vim.b.lp_buf) then
        feed_keys(right..'<BS><BS>')
    elseif get_ctxt('b'):match('{%s$') and
        get_ctxt('f'):match('^%s}') then
        feed_keys('<C-\\><C-O>diB')
    else
        feed_keys('<BS>')
    end
end

--- Super backspace.
--- Inside a defined pair(no length limit):
---   <u>|</u> -> feed <M-BS> -> |
--- Kill a word:
---   Kill a word| -> feed <M-BS> -> Kill a |
function M.lp_supbs()
    local back = get_ctxt('b')
    local fore = get_ctxt('f')
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
        feed_keys('<C-\\><C-O>diB')
    else
        feed_keys('<C-\\><C-O>db')
    end
end

--- Actions on <SPACE>.
--- Inside a pair of braces:
---   {|} -> feed <SPACE> -> { | }
function M.lp_space()
    local keys = is_sur({ ['{']='}' }) and
    '<SPACE><SPACE>'..left or '<SPACE>'
    feed_keys(keys)
end

--- Complete *mates*:
---   | -> feed ( -> (|)
---   | -> feed defined_kbd -> pair_a|pair_b
--- Before a NAC character:
---   |a -> feed ( -> (|a
--- @param pair_a string Left part of a pair of *mates*
function M.lp_mates(pair_a)
    local keys
    if is_NAC(get_ctxt('n')) then
        keys = pair_a
    else
        local pair_b = vim.b.lp_buf[pair_a]
        keys = pair_a..pair_b..string.rep(left, #pair_b)
    end
    feed_keys(keys)
end

--- Inside a defined pair:
---   (|) -> feed ) -> ()|
--- @param pair_b string Right part of a pair of *mates*
function M.lp_close(pair_b)
    local keys = get_ctxt('n') == pair_b and right or pair_b
    feed_keys(keys)
end

--- Complete *quote*:
---   | -> feed " -> "|"
--- Next character is *quote*:
---   |" -> feed " -> "|
--- After the escape character("\"), a *quote* character or a NAC character:
---   \| -> feed " -> \"|
---   "| -> feed " -> ""|
---   a| -> feed " -> a"|
--- Before a NAC character:
---   |a -> feed " -> "|a
--- @param quote string Left part of a pair of *quote*.
function M.lp_quote(quote)
    local prev_char = get_ctxt('p')
    local next_char = get_ctxt('n')
    local keys
    if next_char == quote then
        keys = right
    elseif (prev_char == quote or
        is_NAC(prev_char) or
        is_NAC(next_char) or
        prev_char:match(vim.b.lp_prev_spec) or
        next_char:match(vim.b.lp_next_spec) or
        get_ctxt('b'):match(vim.b.lp_back_spec)) then
        keys = quote
    else
        keys = quote..quote..left
    end
    feed_keys(keys)
end

--- Define variables and key maps in current buffer.
function M.def_all()
    if vim.b.lp_map_list then return end

    if opt.extd then
        tab_extd(lp_comm, opt.extd)
    end

    def_var()

    if opt.ret then
        def_map('<CR>', '<CR>')
    else
        api.nvim_set_keymap(
        'i',
        '<Plug>(lua_pairs_enter)',
        '<CMD>lua require("lua-pairs").lp_enter()<CR>',
        { silent=true, expr=false, noremap=true })
    end

    if opt.bak then
        def_map("<BS>", "<BS>")
        def_map("<M-BS>", "<M-BS>")
    end

    if opt.spc then
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

--- Set up **lua-pairs**.
--- @param option table User configuration
--- | type      | option   | comment                                |
--- |-----------|----------|----------------------------------------|
--- | boolean   | ret      | True to map <CR>                       |
--- | boolean   | bak      | True to map <BS> and <M-BS>            |
--- | boolean   | spc      | True to map <SPACE>                    |
--- | hashtable | extd     | To extend the default pairs            |
--- | hashtable | extd_map | To define key bindings of extend pairs |
function M.setup(option)
    opt = option
    vim.cmd('augroup lp_buffer_update')
    vim.cmd('autocmd!')
    vim.cmd('au BufEnter * lua require("lua-pairs").def_all()')
    vim.cmd([[au FileType * lua ]]..
    [[require("lua-pairs").clr_map() ]]..
    [[require("lua-pairs").def_all()]])
    vim.cmd('augroup end')
end


return M
