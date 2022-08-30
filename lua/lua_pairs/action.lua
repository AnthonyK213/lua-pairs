local A = {}
local L = "<C-G>U<Left>"
local R = "<C-G>U<Right>"
local B = require("lua_pairs.buffer")
local U = require("lua_pairs.util")

---Inside a defined pair:
---  (|) -> feed ) -> ()|
---@param r_side string Right part of a pair of *mates*.
function A.close(_, r_side, _)
    local keys = U.get_ctxt().n == r_side and R or r_side
    U.feed_keys(keys)
end

---Actions on <BS>.
---Inside a defined pair(1 character):
---  (|) -> feed <BS> -> |
---Inside a pair of barces with one space:
---  { | } -> feed <BS> -> {|}
function A.backs(_, _, _)
    local context = U.get_ctxt()
    if B:is_sur(context) then
        U.feed_keys(R .. "<BS><BS>")
    elseif context.b:match("{%s$") and context.f:match("^%s}") then
        U.feed_keys [[<C-\><C-O>"_diB]]
    else
        U.feed_keys [[<BS>]]
    end
end

---Actions on <CR>.
---Inside a pair of brackets:
---  {|} -> feed <CR> -> {<br>|<br>}
function A.enter(_, _, _)
    local context = U.get_ctxt()
    if B:is_sur(context) then
        U.feed_keys [[<CR><C-\><C-O>O]]
    elseif context.b:match("{%s*$") and context.f:match("^%s*}") then
        U.feed_keys [[<C-\><C-O>"_diB<CR><C-\><C-O>O]]
    else
        U.feed_keys [[<CR>]]
    end
end

---Complete *mates*:
---  | -> feed ( -> (|)
---  | -> feed defined_kbd -> pair_a|pair_b
---Before a NAC character:
---  |a -> feed ( -> (|a
---@param l_side string Left part of a pair of *mates*.
---@param r_side string Right part of a pair of *mates*.
function A.mates(l_side, r_side, _)
    if U.is_nac(U.get_ctxt().n) then
        U.feed_keys(l_side)
    else
        U.feed_keys(l_side .. r_side .. string.rep(L, #r_side))
    end
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
---@param r_side string Right part of a pair of *quote*.
---@param disable function If true, just input the key.
function A.quote(l_side, r_side, disable)
    local context = U.get_ctxt()
    if l_side == r_side and vim.startswith(context.f, r_side) then
        U.feed_keys(string.rep(R, #r_side))
    elseif (vim.endswith(context.b, l_side)
        or U.is_nac(context.p)
        or U.is_nac(context.n)
        or disable(context)) then
        U.feed_keys(l_side)
    else
        U.feed_keys(l_side .. r_side .. string.rep(L, #r_side))
    end
end

---Actions on <SPACE>.
---Inside a pair of braces:
---  {|} -> feed <SPACE> -> { | }
function A.space(_, _, _)
    local keys = U.is_sur({ ["{"] = "}" }) and "  " .. L or " "
    U.feed_keys(keys)
end

---Super backspace.
---Inside a defined pair(no length limit):
---  <u>|</u> -> feed <M-BS> -> |
---Kill a word:
---  Kill a word| -> feed <M-BS> -> Kill a |
function A.supbs(_, _, _)
    local context = U.get_ctxt()
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
        U.feed_keys(string.rep(L, res[2]) .. string.rep("<Del>", res[2] + res[3]))
    elseif back:match("{%s*$") and fore:match("^%s*}") then
        U.feed_keys [[<C-\><C-O>"_diB]]
    else
        U.feed_keys [[<C-\><C-O>"_db]]
    end
end

return A
