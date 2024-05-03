local api, fn = vim.api, vim.fn
local M = {}

-- $(XXX)
M.modifiers = {
    -- current working directory
    CWD = function()
        return fn.getcwd()
    end,
    -- full file path
    FILEFULL = function(buf)
        return api.nvim_buf_get_name(buf)
    end,
    -- file name without path
    FILE = function(buf)
        return fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
    end,
    -- file directory
    FILEDIR = function(buf)
        return fn.fnamemodify(api.nvim_buf_get_name(buf), ":p:h")
    end,
    -- file name without extension and path
    FILENOEXT = function(buf)
        return fn.fnamemodify(api.nvim_buf_get_name(buf), ":t:r")
    end,
    -- file extension
    FILEEXT = function(buf)
        return fn.fnamemodify(api.nvim_buf_get_name(buf), ":e")
    end,
    -- the biggest number of testcase id
    TCID = function(buf)
        return vim.b[buf].cp_tcid or 0
    end,
}

---@param content string
function M.convert(content)
    local buf = api.nvim_get_current_buf()
    if vim.b[buf].cp_attached then
        buf = vim.b[buf].cp_attached
    end
    for mod, action in pairs(M.modifiers) do
        content = content:gsub("%$%(" .. mod .. "%)", action(buf))
    end

    return content
end

return M
