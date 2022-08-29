local M = {}
local O = {}
local L = "<C-G>U<Left>"
local R = "<C-G>U<Right>"
local C = {
    { l = "(", r = ")" },
    { l = "[", r = "]" },
    { l = "{", r = "}" },
    { l = '"', r = '"', d = function(context)
        return context.p == "\\"
            or (vim.bo.ft == "vim"
                and context.b:match("^%s*$"))
    end },
    { l = "'", r = "'", e = function()
        return vim.bo.ft ~= "lisp"
    end, d = function(context)
        return context.p == "\\"
            or (vim.bo.ft == "rust"
                and vim.tbl_contains({ "<", "&" }, context.p))
    end },
    { l = "<", r = ">", e = function()
        return vim.tbl_contains({ "html", "xml" }, vim.bo.ft)
    end },
    { k = "<CR>" },
    { k = "<BS>" },
    { k = "<M-BS>" },
    { k = "<SPACE>" },
}


local __e = function() return true end
local __d = function(_) return false end

---Check if current **filetype** has `filetype`.
---@param filetype string File type to be checked.
---@return boolean result True if current **filetype** has `filetype`.
local has_filetype = function(filetype)
    return vim.tbl_contains(vim.split(vim.bo.ft, "%."), filetype)
end

---Convert string to terminal codes.
---@param str string String to be converted.
---@return string terminal_code Termianl code.
local rep_term = function(str)
    return vim.api.nvim_replace_termcodes(str, true, false, true)
end

---Feed keys to current buffer.
---@param str string Operation as string to feed to buffer.
local feed_keys = function(str)
    vim.api.nvim_feedkeys(rep_term(str), "n", true)
end

---Determine if a character is a numeric/alphabetic/CJK(NAC) character.
---@param char string A character to be tested.
---@return boolean result True if the character is a NAC.
local is_nac = function(char)
    local nr = vim.fn.char2nr(char)
    return char:match("[%w_]") or (nr >= 0x4E00 and nr <= 0x9FFF)
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

---Check the surrounding characters of the cursor.
---@param pair_table table Defined pairs to index.
---@return boolean result True if the cursor is surrounded by `pair_table`.
local function is_sur(pair_table)
    local context = get_ctxt()
    return pair_table[context.p] == context.n
end

---@type table<integer, K[]>
local B = {}

function B:get()
    return self[vim.api.nvim_get_current_buf()]
end

function B:set(ks)
    self[vim.api.nvim_get_current_buf()] = ks
end

function B:is_sur()
    local ks = self:get()
    if ks then
        local context = get_ctxt()
        for _, k in ipairs(ks) do
            if k.l_side and k.r_side
                and vim.endswith(context.b, k.l_side)
                and vim.startswith(context.f, k.r_side) then
                return true
            end
        end
    end
    return false
end

---Actions on <CR>.
---Inside a pair of brackets:
---  {|} -> feed <CR> -> {<br>|<br>}
local function lp_enter(_, _, _)
    local context = get_ctxt()
    if B:is_sur() then
        feed_keys [[<CR><C-\><C-O>O]]
    elseif context.b:match("{%s*$") and context.f:match("^%s*}") then
        feed_keys [[<C-\><C-O>"_diB<CR><C-\><C-O>O]]
    else
        feed_keys [[<CR>]]
    end
end

---Actions on <BS>.
---Inside a defined pair(1 character):
---  (|) -> feed <BS> -> |
---Inside a pair of barces with one space:
---  { | } -> feed <BS> -> {|}
local function lp_backs(_, _, _)
    local context = get_ctxt()
    if B:is_sur() then
        feed_keys(R .. "<BS><BS>")
    elseif context.b:match("{%s$") and context.f:match("^%s}") then
        feed_keys [[<C-\><C-O>"_diB]]
    else
        feed_keys("<BS>")
    end
end

---Super backspace.
---Inside a defined pair(no length limit):
---  <u>|</u> -> feed <M-BS> -> |
---Kill a word:
---  Kill a word| -> feed <M-BS> -> Kill a |
local function lp_supbs(_, _, _)
    local context = get_ctxt()
    local back = context.b
    local fore = context.f
    local res = { false, 0, 0 }
    for _, k in ipairs(B:get()) do
        if k.l_side and k.r_side
            and vim.endswith(back, k.l_side)
            and vim.startswith(fore, k.r_side)
            and #k.l_side + #k.r_side > res[2] + res[3] then
            res = { true, #k.l_side, #k.r_side }
        end
    end
    if res[1] then
        feed_keys(string.rep(L, res[2]) ..
            string.rep("<Del>", res[2] + res[3]))
    elseif back:match("{%s*$") and fore:match("^%s*}") then
        feed_keys [[<C-\><C-O>"_diB]]
    else
        feed_keys [[<C-\><C-O>"_db]]
    end
end

---Actions on <SPACE>.
---Inside a pair of braces:
---  {|} -> feed <SPACE> -> { | }
local function lp_space(_, _, _)
    local keys = is_sur({ ["{"] = "}" }) and "<SPACE><SPACE>" .. L or "<SPACE>"
    feed_keys(keys)
end

---Complete *mates*:
---  | -> feed ( -> (|)
---  | -> feed defined_kbd -> pair_a|pair_b
---Before a NAC character:
---  |a -> feed ( -> (|a
---@param l_side string Left part of a pair of *mates*.
local function lp_mates(l_side, r_side, _)
    if is_nac(get_ctxt().n) then
        feed_keys(l_side)
    else
        feed_keys(l_side .. r_side .. string.rep(L, #r_side))
    end
end

---Inside a defined pair:
---  (|) -> feed ) -> ()|
---@param r_side string Right part of a pair of *mates*.
local function lp_close(_, r_side, _)
    local keys = get_ctxt().n == r_side and R or r_side
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
---@param l_side string Left part of a pair of *quote*.
local function lp_quote(l_side, _, disable)
    local context = get_ctxt()
    local prev_char = context.p
    local next_char = context.n
    if next_char == l_side then
        feed_keys(R)
    elseif (prev_char == l_side
        or is_nac(prev_char)
        or is_nac(next_char)
        or disable(context)) then
        feed_keys(l_side)
    else
        feed_keys(l_side .. l_side .. L)
    end
end

local T = {
    Mates = lp_mates,
    Quote = lp_quote,
    Close = lp_close,
    ["<CR>"] = lp_enter,
    ["<BS>"] = lp_backs,
    ["<M-BS>"] = lp_supbs,
    ["<SPACE>"] = lp_space,
}

---@class K
---@field key string?
---@field l_side string
---@field r_side string
---@field mates boolean
---@field quote boolean
---@field close boolean
---@field enable function
---@field disable function
---@field specs function[]
local K = {}

K.__index = K

---Constructor.
---@param args table<string, string>
---@return K
function K.new(args)
    local specs = {}
    local k = {
        key = args.k,
        l_side = args.l,
        r_side = args.r,
        mates = false,
        quote = false,
        close = false,
        enable = args.e or __e,
        disable = args.d or __d,
    }
    if k.key and T[k.key] then
        table.insert(specs, T[k.key])
    elseif k.l_side and k.r_side then
        if k.l_side == k.r_side and #(k.l_side) == 1 then
            k.quote = true
        else
            k.mates = true
            if k.r_side and #k.r_side == 1 then
                k.close = true
            end
        end
    end
    k.specs = specs
    setmetatable(k, K)
    return k
end

function K:set_map()
    if not self.enable() then return end
    local _opt = { noremap = true, expr = false, silent = true, buffer = true }
    for _, f in ipairs(self.specs) do
        vim.keymap.set("i", self.key, function()
            f(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.close then
        vim.keymap.set("i", self.r_side, function()
            T.Close(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.mates then
        vim.keymap.set("i", self.key or self.l_side, function()
            T.Mates(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.quote then
        vim.keymap.set("i", self.key or self.l_side, function()
            T.Quote(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
end

---Define variables and key maps in current buffer.
local function set_all()
    local exclude = O.exclude or {}
    local buftype = exclude.buftype or {}
    local filetype = exclude.filetype or {}

    if B:get()
        or vim.tbl_contains(buftype, vim.bo.bt)
        or vim.tbl_contains(filetype, vim.bo.ft) then
        return
    end

    ---@type K[]
    local b = {}
    for _, args in ipairs(C) do table.insert(b, K.new(args)) end

    if O.extd then
        if O.extd["_"] then
            for _, args in ipairs(O.extd["_"]) do
                table.insert(b, K.new(args))
            end
        end
        for ft, pr in pairs(O.extd) do
            if has_filetype(ft) then
                for _, args in ipairs(pr) do
                    local k_e = args.e
                    if k_e then
                        args.e = function()
                            return k_e() and has_filetype(ft)
                        end
                    else
                        args.e = function() return has_filetype(ft) end
                    end
                    table.insert(b, K.new(args))
                end
                break
            end
        end
    end

    B:set(b)

    for _, k in ipairs(b) do k:set_map() end
end

---Set up **lua-pairs**.
---@param option table User configuration.
-- | Option   | Type      | Description                            |
-- |----------|-----------|----------------------------------------|
-- | extd     | hashtable | To extend the default pairs            |
-- | exclude  | table     | Excluded buffer types and file types   |
function M.setup(option)
    O = option or {}
    local id = vim.api.nvim_create_augroup("lp_buffer_update", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
        group = id,
        pattern = "*",
        callback = set_all
    })
end

return M
