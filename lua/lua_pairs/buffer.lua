---@type table<integer, P[]>
local B = {}

function B:get()
    return self[vim.api.nvim_get_current_buf()]
end

function B:set(ks)
    self[vim.api.nvim_get_current_buf()] = ks
end

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
