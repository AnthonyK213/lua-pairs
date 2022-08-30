local B = {}

function B:get()
    return self[vim.api.nvim_get_current_buf()]
end

function B:set(ks)
    self[vim.api.nvim_get_current_buf()] = ks
end

function B:is_sur(context)
    local ks = self:get()
    if ks then
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

return B
