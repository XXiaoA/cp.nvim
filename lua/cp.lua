local config = require("cp.config")
local M = {}

---@type MAIN[]
local CP = {}

function M.setup(opts)
    config.setup(opts)

    vim.api.nvim_create_user_command("Cp", function(ctx)
        local arg = ctx.args
        local buf = vim.api.nvim_get_current_buf()
        if vim.b[buf].cp_attached then
            buf = vim.b[buf].cp_attached
        end
        if arg == "run" then
            if not CP[buf] then
                CP[buf] = require("cp.main"):new()
            end
            CP[buf]:load_testcases()
            CP[buf]:show_ui()
            if CP[buf].compilable == 1 then
                CP[buf]:compile(function()
                    CP[buf]:excute_all()
                end)
            else
                CP[buf]:excute_all()
            end
        elseif arg == "add_testcase" then
            CP[buf]:create_testcase(true)
        else
            vim.notify("cp.nvim: No command " .. ctx.args)
        end
    end, {
        nargs = 1,
        complete = function(arg)
            local list = { "run", "add_testcase" }
            return vim.tbl_filter(function(s)
                return string.match(s, "^" .. arg)
            end, list)
        end,
    })
end

return M
