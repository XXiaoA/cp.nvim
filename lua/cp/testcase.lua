local api, uv, fn = vim.api, vim.loop, vim.fn
local utils = require("cp.utils")
local config = require("cp.config").opts
local modifier = require("cp.modifier")

local M = {}

---@param buf number 0 for current buffer
function M.buf_get_testcases(buf)
    buf = buf == 0 and api.nvim_get_current_buf() or buf

    local dir = modifier.convert(config.testcases.dir)
    local input_regex = modifier.convert(config.testcases.input_format:gsub("%$%(TCID%)", "(%%d+)"))
    local expect_regex = modifier.convert(config.testcases.expect_format:gsub("%$%(TCID%)", "(%%d+)"))
    local files = vim.fs.find(function(name)
        return name:match(input_regex) or name:match(expect_regex)
    end, { limit = math.huge, type = "file", path = dir })

    local testcases = {}
    local existed_id = {}
    for _, file in ipairs(files) do
        local id = tonumber(file:match(input_regex) or file:match(expect_regex))
        -- we can make sure the id exists because we have used regex before
        assert(id) -- remove the LSP warning
        if not existed_id[id] then
            existed_id[id] = true
            testcases[id] = { id = id, kind = "Test", status = "NONE" }
        end
        if file:match(input_regex) then
            testcases[id].input = utils.read_file(file)
        elseif file:match(expect_regex) then
            testcases[id].expect = utils.read_file(file)
        end
    end

    return testcases
end

--- show the input ui
---@param buf number 0 for current buffer
---@param tc_id number testcase id
function M.editor_ui(buf, tc_id)
    if not buf or buf == 0 then
        buf = api.nvim_get_current_buf()
    end
    ---@type WINDOW, WINDOW
    local input_win, expect_win = config.ui.editor(tc_id)
    local _jumping = false -- prevent closing ui while jumping between input and expect windows

    -- NOTE: set the cp_attached before the modifier.convert() !!!
    vim.b[input_win.buf].cp_attached = buf
    vim.b[expect_win.buf].cp_attached = buf
    local dir = modifier.convert(config.testcases.dir)
    ---@param mode "input" | "expect"
    local function write_testcase(content, mode)
        local file
        if mode == "input" then
            file = modifier.convert(config.testcases.input_format:gsub("%$%(TCID%)", tc_id))
        else
            file = modifier.convert(config.testcases.expect_format:gsub("%$%(TCID%)", tc_id))
        end
        utils.write_file(dir .. file, content)
    end
    ---@param mode "input" | "expect"
    local function read_testcase(mode)
        local file
        if mode == "input" then
            file = modifier.convert(config.testcases.input_format:gsub("%$%(TCID%)", tc_id))
        else
            file = modifier.convert(config.testcases.expect_format:gsub("%$%(TCID%)", tc_id))
        end
        return utils.read_file(dir .. file)
    end

    for mode, win in pairs({ input = input_win, expect = expect_win }) do
        win:set_opt({ buf = { modifiable = true } })

        win:keymap("n", "q", function()
            vim.cmd("q")
        end)
        win:keymap("i", "<C-s>", function()
            vim.cmd("q | stopinsert")
        end)
        for _, lhs in ipairs({ "<C-l>", "<C-h>" }) do
            win:keymap({ "n", "i" }, lhs, function()
                _jumping = true
                if api.nvim_get_current_win() == input_win.win then
                    api.nvim_set_current_win(expect_win.win)
                else
                    api.nvim_set_current_win(input_win.win)
                end
                _jumping = false
            end)
        end

        win:autocmd({ "TextChanged", "InsertLeave" }, function(ctx)
            local content = api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
            write_testcase(fn.join(content, "\n"), mode)
        end)

        win:autocmd("WinLeave", function()
            local input_content = api.nvim_buf_get_lines(input_win.buf, 0, -1, false)
            local expect_content = api.nvim_buf_get_lines(expect_win.buf, 0, -1, false)
            write_testcase(fn.join(input_content, "\n"), "input")
            write_testcase(fn.join(expect_content, "\n"), "expect")
            if _jumping == false then
                api.nvim_win_close(input_win.win, true)
                api.nvim_win_close(expect_win.win, true)
            end
        end)

        win:set_text(read_testcase(mode))
    end
end
return M
