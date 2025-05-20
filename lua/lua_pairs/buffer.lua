local B = {}

---@type table<integer, lua_pairs.Pair[]>
local _buf_tbl = {}

---Get pairs of the buffer.
---@param bufnr? integer Buffer number.
---@return lua_pairs.Pair[]
function B.get(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return _buf_tbl[bufnr]
end

---Set pairs for the buffer.
---@param p_list? lua_pairs.Pair[] Pairs to set for the buffer.
---@param bufnr? integer Buffer number.
function B.set(p_list, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  _buf_tbl[bufnr] = p_list
end

---Check if current context is surrounded by any pair from current buffer.
---@param context lua_pairs.Context
---@return boolean
function B.is_sur(context)
  local pair_list = B.get()
  if pair_list then
    for _, p in ipairs(pair_list) do
      if p.l_side and p.r_side
          and vim.endswith(context.b, p.l_side)
          and vim.startswith(context.f, p.r_side) then
        return true
      end
    end
  end
  return false
end

return B
