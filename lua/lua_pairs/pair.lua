local A = require("lua_pairs.action")
local D = function(_) return false end
local E = function() return true end
local T = {
  ["<CR>"] = A.enter,
  ["<BS>"] = A.backs,
  ["<M-BS>"] = A.supbs,
  ["<SPACE>"] = A.space,
}

---@class lua_pairs.PairSpec
---@field k string? LHS
---@field l string? Left side of the pair.
---@field r string? Right side of the pair.
---@field d (fun(context:lua_pairs.Context):boolean)? To disable the pair within context.
---@field e (fun():boolean)? To enable the pair.

---@class lua_pairs.Pair
---@field key string? LHS
---@field l_side string? Left side of the pair.
---@field r_side string? Right side of the pair.
---@field enable (fun():boolean)
---@field disable (fun(context:lua_pairs.Context):boolean)
---@field private mates boolean
---@field private quote boolean
---@field private close boolean
---@field private specs function[]
local P = {}

P.__index = P

---Constructor.
---@param args lua_pairs.PairSpec
---@return lua_pairs.Pair
function P.new(args)
  local p = {
    key = args.k,
    l_side = args.l,
    r_side = args.r,
    mates = false,
    quote = false,
    close = false,
    enable = args.e or E,
    disable = args.d or D,
    specs = {},
  }

  if p.key and T[p.key] then
    table.insert(p.specs, T[p.key])
  elseif p.l_side and p.r_side then
    if p.key or (p.l_side == p.r_side and #(p.l_side) == 1) then
      p.quote = true
    else
      p.mates = true
      if p.r_side and #(p.r_side) == 1 then
        p.close = true
      end
    end
  end

  setmetatable(p, P)
  return p
end

---Set keymaps to buffer.
---@param bufnr? integer Buffer number.
function P:set_map(bufnr)
  if not self.enable() then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local _opt = { noremap = true, expr = false, silent = true, buffer = bufnr }

  for _, f in ipairs(self.specs) do
    if self.key then
      vim.keymap.set("i", self.key, function()
        f(self.l_side, self.r_side, self.disable)
      end, _opt)
    end
  end

  if self.close and self.r_side then
    vim.keymap.set("i", self.r_side, function()
      A.close(self.l_side, self.r_side, self.disable)
    end, _opt)
  end

  if self.mates then
    local lhs = self.key or self.l_side
    if lhs then
      vim.keymap.set("i", lhs, function()
        A.mates(self.l_side, self.r_side, self.disable)
      end, _opt)
    end
  end

  if self.quote then
    local lhs = self.key or self.l_side
    if lhs then
      vim.keymap.set("i", lhs, function()
        A.quote(self.l_side, self.r_side, self.disable)
      end, _opt)
    end
  end
end

---Delete keymaps from buffer.
---@param bufnr? integer Buffer number.
function P:del_map(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if self.mates or self.quote then
    pcall(vim.keymap.del, "i", self.key or self.l_side, { buffer = bufnr })
  end

  if self.close then
    pcall(vim.keymap.del, "i", self.r_side, { buffer = bufnr })
  end
end

return P
