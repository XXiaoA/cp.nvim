local api = vim.api
local utils = require("cp.utils")
local window = require("cp.window")
local M = {}

M.opts = {}
local defaults = {
    run = {
        -- where should the executable be
        compile_dir = "$(FILEDIR)/build/$(FILENOEXT)",
        command = {
            cpp = {
                compile = { cmd = "g++", args = { "-Wall", "$(FILEFULL)", "-o", "$(FILEDIR)/build/$(FILENOEXT)" } },
                exec = { cmd = "$(FILEDIR)/build/$(FILENOEXT)" },
            },
            python = {
                exec = { cmd = "python", args = { "$(FILEFULL)" } },
            },
        },
    },
    testcases = {
        -- where may the testcase be
        dir = "$(FILEDIR)/build/",
        -- both of them need have $(TCID)
        input_format = "$(FILENOEXT)_$(TCID).in",
        expect_format = "$(FILENOEXT)_$(TCID).out",
    },

    ui = {
        main = function()
            vim.o.equalalways = false
            local original_win = api.nvim_get_current_win()
            local tc = window:new("vs", { width = utils.get_resolution(0.47).width })
            local ep = window:new("sp")
            local op = window:new("sp")
            vim.cmd("wincmd 2k")
            local ip = window:new("vs")
            for _, win in pairs({ tc, ep, op, ip }) do
                win:set_opt({ win = { wfh = true, wfw = true } })
            end
            api.nvim_set_current_win(original_win)
            vim.o.equalalways = true
            api.nvim_set_current_win(tc.win)
            return tc, ep, op, ip
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
end

return M
