local api = vim.api
local M = {}

---@type CpMain[] the index is the buffer id
local CP = {}

--- get the current buffer, or the attached buffer if we are in the main ui
---@return number
local function get_buf()
    local buf = api.nvim_get_current_buf()
    if vim.b[buf].cp_attached then
        buf = vim.b[buf].cp_attached
    end
    return buf
end

---@type table<string, CpSubcommand>
M.subcommands = {
    show = {
        impl = function()
            local buf = get_buf()
            if not CP[buf]._show then
                CP[buf]:show_ui()
            end
        end,
    },
    focus = {
        impl = function()
            local buf = get_buf()
            if CP[buf]._show then
                api.nvim_set_current_win(CP[buf].wins.main.win)
            end
        end,
    },
    hide = {
        impl = function()
            local buf = get_buf()
            if CP[buf]._show then
                CP[buf]:close_ui()
            end
        end,
    },
    toggle = {
        impl = function()
            local buf = get_buf()
            if not CP[buf]._show then
                CP[buf]:show_ui()
            else
                CP[buf]:close_ui()
            end
        end,
    },
    -- compile and execute all testcases
    run = {
        impl = function()
            local buf = get_buf()
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
        end,
    },
    testcase_add = {
        impl = function()
            local buf = get_buf()
            CP[buf]:create_testcase(true)
            if CP[buf]._show then
                CP[buf]:show_testcases()
            end
        end,
    },
    testcase_edit = {
        impl = function(args)
            local buf = get_buf()
            local id = tonumber(args[1])
            if id then
                require("cp.testcase").editor_ui(CP[buf].buf, id)
            else
                vim.notify("Cp.nvim: Invalid testcase id", vim.log.levels.ERROR)
            end
        end,
        complete = function()
            local buf = get_buf()
            if CP[buf] then
                return vim.tbl_map(tostring, vim.tbl_keys(CP[buf].testcases))
            end
            return {}
        end,
    },
}

function M.setup(opts)
    local config = require("cp.config")
    config.setup(opts)

    vim.api.nvim_create_user_command("Cp", function(ctx)
        local fargs = ctx.fargs
        local buf = get_buf()
        local subcommand_key = fargs[1]
        -- Get the subcommand's arguments, if any
        local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
        local subcommand = M.subcommands[subcommand_key]
        if not subcommand then
            vim.notify("Cp.nvim: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
            return
        end
        local lang = vim.bo[buf].filetype
        local lang_config = config.opts.run.command[lang]
        if not lang_config then
            vim.notify("Cp.nvim: No `run.command` config for filetype: " .. lang, vim.log.levels.ERROR)
            return
        end
        if not CP[buf] then
            CP[buf] = require("cp.main"):new(buf)
            CP[buf]:load_testcases()
        end
        -- Invoke the subcommand
        subcommand.impl(args, ctx)
    end, {
        nargs = "+",
        desc = "Cp.nvim",
        complete = function(arg_lead, cmdline, _)
            -- Get the subcommand.
            local subcmd_key, subcmd_arg_lead = cmdline:match("^Cp[!]*%s(%S+)%s(.*)$")
            if subcmd_key and subcmd_arg_lead and M.subcommands[subcmd_key] and M.subcommands[subcmd_key].complete then
                -- The subcommand has completions. Return them.
                return M.subcommands[subcmd_key].complete(subcmd_arg_lead)
            end
            -- Check if cmdline is a subcommand
            if cmdline:match("^Cp[!]*%s+%w*$") then
                -- Filter subcommands that match
                local subcommand_keys = vim.tbl_keys(M.subcommands)
                return vim.iter(subcommand_keys)
                    :filter(function(key)
                        return key:find(arg_lead) ~= nil
                    end)
                    :totable()
            end
        end,
    })
end

return M
