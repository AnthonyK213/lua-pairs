---@type table<integer, P[]>
local B = {}

---Get pairs of the buffer.
---@param bufnr? integer Buffer number.
---@return P[]
function B:get(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return self[bufnr]
end

---Set pairs for the buffer.
---@param p_list? P[] Pairs to set for the buffer.
---@param bufnr? integer Buffer number.
function B:set(p_list, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    self[bufnr] = p_list
end

---Check if current context is surrounded by any pair from current buffer.
---@param context table
---@return boolean
function B:is_sur(context)
    local ps = self:get()
    if ps then
        for _, p in ipairs(ps) do
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
