local A = require("lua_pairs.action")
local D = function(_) return false end
local E = function() return true end
local T = {
    ["<CR>"] = A.enter,
    ["<BS>"] = A.backs,
    ["<M-BS>"] = A.supbs,
    ["<SPACE>"] = A.space,
}

---@class P
---@field key string?
---@field l_side string?
---@field r_side string?
---@field mates boolean
---@field quote boolean
---@field close boolean
---@field enable function
---@field disable function
---@field specs function[]
local P = {}

P.__index = P

---Constructor.
---@param args table<string, string>
---@return P
function P.new(args)
    local specs = {}
    local p = {
        key = args.k,
        l_side = args.l,
        r_side = args.r,
        mates = false,
        quote = false,
        close = false,
        enable = args.e or E,
        disable = args.d or D,
    }
    if p.key and T[p.key] then
        table.insert(specs, T[p.key])
    elseif p.l_side and p.r_side then
        if p.l_side == p.r_side and #(p.l_side) == 1 then
            p.quote = true
        else
            p.mates = true
            if p.r_side and #p.r_side == 1 then
                p.close = true
            end
        end
    end
    p.specs = specs
    setmetatable(p, P)
    return p
end

function P:set_map()
    if not self.enable() then return end
    local _opt = { noremap = true, expr = false, silent = true, buffer = true }
    for _, f in ipairs(self.specs) do
        vim.keymap.set("i", self.key, function()
            f(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.close then
        vim.keymap.set("i", self.r_side, function()
            A.close(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.mates then
        vim.keymap.set("i", self.key or self.l_side, function()
            A.mates(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
    if self.quote then
        vim.keymap.set("i", self.key or self.l_side, function()
            A.quote(self.l_side, self.r_side, self.disable)
        end, _opt)
    end
end

return P
