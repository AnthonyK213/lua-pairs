local M = {}
local O = {}
local B = require("lua_pairs.buffer")
local P = require("lua_pairs.pair")
local U = require("lua_pairs.util")
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

    ---@type P[]
    local b = {}
    for _, args in ipairs(C) do table.insert(b, P.new(args)) end

    if O.extd then
        if O.extd["_"] then
            for _, args in ipairs(O.extd["_"]) do
                table.insert(b, P.new(args))
            end
        end
        for ft, pr in pairs(O.extd) do
            if U.has_filetype(ft) then
                for _, args in ipairs(pr) do
                    local p = P.new(args)
                    local p_e = args.e
                    if p_e then
                        p.e = function()
                            return p_e() and U.has_filetype(ft)
                        end
                    else
                        p.e = function() return U.has_filetype(ft) end
                    end
                    table.insert(b, p)
                end
                break
            end
        end
    end

    B:set(b)

    for _, p in ipairs(b) do p:set_map() end
end

---Set up **lua-pairs**.
---@param option table User configuration.
-- | Option   | Type  | Description                            |
-- |----------|-------|----------------------------------------|
-- | extd     | table | To extend the default pairs            |
-- | exclude  | table | Excluded buffer types and file types   |
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
