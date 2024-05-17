local api = vim.api
local config = require("cp.config")
local M = {}

---@type MAIN[] the index is the buffer id
local CP = {}

function M.setup(opts)
    config.setup(opts)

    api.nvim_create_user_command("Cp", function(ctx)
        local arg = ctx.args
        local buf = api.nvim_get_current_buf()
        if vim.b[buf].cp_attached then
            buf = vim.b[buf].cp_attached
        end

        local lang = vim.bo[buf].filetype
        local lang_config = config.opts.run.command[lang]
        if not lang_config then
            vim.notify("cp.nvim: No `run.command` config for filetype: " .. lang, vim.log.levels.ERROR)
            return
        end

        if not CP[buf] then
            CP[buf] = require("cp.main"):new(buf)
            CP[buf]:load_testcases()
        end
        if arg == "" then
            if not CP[buf]._show then
                CP[buf]:show_ui()
            else
                api.nvim_set_current_win(CP[buf].wins.main.win)
            end
        elseif arg == "toggle" then
            if not CP[buf]._show then
                CP[buf]:show_ui()
            else
                CP[buf]:close_ui()
            end
        elseif arg == "show" then
            if not CP[buf]._show then
                CP[buf]:show_ui()
            end
        elseif arg == "hide" then
            if CP[buf]._show then
                CP[buf]:close_ui()
            end
        elseif arg == "run" then
            if not CP[buf]._show then
                CP[buf]:show_ui()
            end
            CP[buf]:load_testcases()
            if CP[buf].compilable == 1 then
                CP[buf]:compile(function()
                    -- only execute all when compiled successfully
                    if CP[buf].testcases[1].status == "DONE" then
                        CP[buf]:excute_all()
                    end
                end)
            else
                CP[buf]:excute_all()
            end
        elseif arg == "add_testcase" then
            CP[buf]:create_testcase(true)
            if CP[buf]._show then
                CP[buf]:show_testcases()
            end
        else
            vim.notify("cp.nvim: No command " .. ctx.args)
        end
    end, {
        nargs = "*",
        complete = function(arg)
            local list = { "run", "add_testcase", "toggle", "show", "hide" }
            return vim.tbl_filter(function(s)
                return string.match(s, "^" .. arg)
            end, list)
        end,
    })
end

return M
