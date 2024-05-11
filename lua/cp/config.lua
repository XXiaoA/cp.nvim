local api = vim.api
local utils = require("cp.utils")
local window = require("cp.window")
local M = {}

M.opts = {}
local defaults = {
    run = {
        command = {
            cpp = {
                -- use a table format
                compile = { cmd = "g++", args = { "-Wall", "$(FILEFULL)", "-o", "$(FILEDIR)/build/$(FILENOEXT)" } },
                exec = { cmd = "$(FILEDIR)/build/$(FILENOEXT)" },
            },
            python = {
                -- or just a string
                exec = "python $(FILEFULL)",
                -- which is equal to
                -- exec = { cmd = "python", args = { "$(FILEFULL)" } },
            },
        },
    },
    testcases = {
        -- where should the testcase be
        dir = "$(FILEDIR)/build/",
        -- both of them need have $(TCID)
        input_format = "$(FILENOEXT)_$(TCID).in",
        expect_format = "$(FILENOEXT)_$(TCID).out",
    },
    ui = {
        -- whether the winbar should be shown in the main window
        winbar_in_main = true,
        main = function()
            vim.o.equalalways = false
            local original_win = api.nvim_get_current_win()
            local main = window:new("vertical botright sp", { width = utils.get_resolution(0.47).width })
            local expect = window:new("rightbelow sp")
            local output = window:new("rightbelow sp")
            vim.cmd("wincmd 2k")
            local input = window:new("vertical rightbelow sp")
            for _, win in pairs({ main, expect, output, input }) do
                win:set_opt({ win = { wfh = true, wfw = true } })
            end
            api.nvim_set_current_win(original_win)
            vim.o.equalalways = true
            api.nvim_set_current_win(main.win)
            return main, expect, output, input
        end,

        ---@param id number the id of the testcase
        editor = function(id)
            local height = utils.get_resolution().height
            local function config(opt)
                return vim.tbl_extend("force", opt or {}, {
                    relative = "editor",
                    width = utils.round(vim.o.columns * 0.4),
                    height = utils.round(height * 0.8),
                    border = "rounded",
                    title_pos = "center",
                })
            end
            -- stylua: ignore start
            local input = window:new("float", config({
                row = utils.round(height * 0.1),
                col = utils.round(vim.o.columns * 0.09),
                title = "Input " .. id,
            }))
            local expect = window:new("float", config({
                enter = false,
                row = utils.round(height * 0.1),
                col = utils.round(vim.o.columns * (0.4 + 0.09)) + 2,
                title = "Expectation " .. id,
            }))
            -- stylua: ignore end
            return input, expect
        end,

        -- use the tabpage if you want
        -- editor = function()
        --     local input = window:new("tabnew")
        --     local expect = window:new("vs")
        --     api.nvim_set_current_win(input.win)
        --     return input, expect
        -- end,
    },
}

function M.setup(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", defaults, opts)

    -- transform the string type command to table
    for lang, config in pairs(M.opts.run.command) do
        for kind, command in pairs(config) do
            if type(command) == "string" then
                local parts = vim.split(command, "%s+")
                local cmd = table.remove(parts, 1)
                local args = parts
                M.opts.run.command[lang][kind] = {
                    cmd = cmd,
                    args = args,
                }
            end
        end
    end
end

return M
