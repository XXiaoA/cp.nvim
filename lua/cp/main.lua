local api = vim.api
local tc_mod = require("cp.testcase") -- a suboptimal name to avoid so many variables named "testcase"
local utils = require("cp.utils")
local modifier = require("cp.modifier")
local config = require("cp.config").opts
local runner = require("cp.runner")

---@class CpMain
local MAIN = {}

local function get_testcase_id()
    local context = api.nvim_get_current_line()
    local pattern = "Test%s+(%d+)"
    return tonumber(context:match(pattern))
end

---@param buf number 0 for current buffer
---@return CpMain
function MAIN:new(buf)
    buf = buf == 0 and api.nvim_get_current_buf() or buf
    -- each main ui is attached to a specific buffer
    local o = {
        _show = false, -- whether the ui is shown
        buf = buf,
        compilable = 0,
        wins = {
            main = nil, -- including compile and test case
            expect = nil, -- expectation
            output = nil, -- output
            input = nil, -- input
        },
        testcases = {},
    }

    local lang = vim.bo[buf].filetype
    local lang_config = config.run.command[lang]
    if lang_config.compile then
        o.compilable = 1
        -- duration is in millisecond (uv.now())
        o.testcases[1] = { id = 0, kind = "Compile", status = "NONE", duration = nil }
    end

    setmetatable(o, self)
    self.__index = self
    return o
end

function MAIN:show_ui()
    self.wins.main, self.wins.expect, self.wins.output, self.wins.input = config.main.ui()

    self._show = true

    if config.main.winbar then
        self.wins.main:set_opt({ win = { winbar = "main" } })
        self.wins.expect:set_opt({ win = { winbar = "expect" } })
        self.wins.output:set_opt({ win = { winbar = "output" } })
        self.wins.input:set_opt({ win = { winbar = "input" } })
    end

    for _, win in pairs(self.wins) do
        -- for modifier mainly
        vim.b[win.buf].cp_attached = self.buf

        win:keymap("n", { "q", "<C-w>c", "<C-w>q" }, function()
            self:close_ui()
        end)
        win:keymap("n", "r", function()
            self:execute(get_testcase_id())
        end)
        win:keymap("n", "R", function()
            require("cp").subcommands.run.impl(_, _)
        end)
        win:keymap("n", "a", function()
            self:create_testcase(true)
            self:show_testcases()
        end)
        win:keymap("n", "d", function()
            -- TODO: implement it
        end)
        win:keymap("n", "e", function()
            local id = get_testcase_id()
            local testcase = self.testcases[id + self.compilable]
            tc_mod.editor_ui(self.buf, id, function(data)
                testcase.input = data.input
                testcase.expect = data.expect
                testcase.status = "NONE"
                testcase.duration = nil
                self:show_testcases()
            end)
        end)
    end

    self:show_testcases()

    self.wins.main:autocmd("CursorMoved", function()
        if vim.tbl_isempty(self.testcases) then
            return
        end
        local testcase_id = get_testcase_id()
        local testcase = self.testcases[testcase_id + self.compilable]

        -- show the compile information
        if testcase.kind == "Compile" then
            self.wins.output:set_text(testcase.output)
        end

        -- only update when compiling successfully
        -- (uncompilable) or (compilable and compile status is DONE)
        if self.compilable == 0 or self.testcases[1].status == "DONE" then
            self.wins.input:set_text(testcase.input)
            self.wins.expect:set_text(testcase.expect)
            self.wins.output:set_text(testcase.output)
        end
    end)
end

function MAIN:close_ui()
    self._show = false
    for _, win in pairs(self.wins) do
        api.nvim_win_close(win.win, true)
    end
end

function MAIN:update_tcid(buf)
    local testcases_id = vim.tbl_keys(self.testcases)
    local last_index = testcases_id[#testcases_id]
    vim.b[buf].cp_tcid = self.testcases[last_index] and self.testcases[last_index].id or 0
end

function MAIN:load_testcases()
    local testcases = tc_mod.buf_get_testcases(self.buf)
    if self.compilable == 1 then
        -- keep compile testcase
        self.testcases = { self.testcases[1] }
    else
        self.testcases = {}
    end
    for id, testcase in pairs(testcases) do
        self.testcases[id + self.compilable] = testcase
    end

    self:update_tcid(self.buf)
end

---@param edit boolean? defaults to true
function MAIN:create_testcase(edit)
    if edit == nil then
        edit = true
    end

    local new_tcid = vim.b[self.buf].cp_tcid + 1
    local dir = modifier.convert(config.testcases.dir)
    local input_file = modifier.convert(config.testcases.input_format:gsub("%$%(TCID%)", new_tcid))
    local expect_file = modifier.convert(config.testcases.expect_format:gsub("%$%(TCID%)", new_tcid))
    utils.create_file(dir .. input_file)
    utils.create_file(dir .. expect_file)

    if edit then
        tc_mod.editor_ui(self.buf, new_tcid)
    end

    self.testcases[new_tcid + self.compilable] = {
        id = new_tcid,
        kind = "Test",
        status = "NONE",
        duration = nil,
    }

    self:update_tcid(self.buf)
end

function MAIN:show_testcases()
    local buf_lines = {}
    for _, testcase in pairs(self.testcases) do
        local kind = testcase.kind == "Test" and ("%s %d"):format(testcase.kind, testcase.id) or testcase.kind
        local duration
        if not testcase.duration then
            duration = "N/A"
        else
            duration = ("%.3fs"):format(testcase.duration / 1000)
        end
        local line = ("%s\t%s\t%s"):format(kind, testcase.status, duration)
        table.insert(buf_lines, line)
    end
    self.wins.main:set_text(buf_lines)
end

--- only vaild when compilable
---@param callback function|nil useful for executing after compilation
function MAIN:compile(callback)
    if not self.compilable then
        return
    end

    local lang = vim.bo[self.buf].filetype
    local lang_config = config.run.command[lang]
    local exec = modifier.convert(lang_config.compile.cmd)
    local args = {}
    for _, arg in ipairs(lang_config.compile.args) do
        table.insert(args, modifier.convert(arg))
    end

    local testcase = self.testcases[1]
    runner.compile(exec, args, function(data)
        vim.schedule(function()
            testcase.duration = data.duration
            if data.error then
                testcase.status = "ERROR"
            else
                testcase.status = "DONE"
            end
            if data.msg then
                data.msg = data.msg:sub(-1) == "\n" and data.msg:sub(1, -2) or data.msg
                testcase.output = vim.split(data.msg, "\n")
            end
            self:show_testcases()

            if type(callback) == "function" then
                callback()
            end
        end)
    end)
end

function MAIN:execute(id)
    local lang = vim.bo[self.buf].filetype

    local exec = modifier.convert(config.run.command[lang].exec.cmd)
    local args = {}
    for _, arg in ipairs(config.run.command[lang].exec.args or {}) do
        table.insert(args, modifier.convert(arg))
    end

    local testcase = self.testcases[id + self.compilable]
    local input = testcase.input
    runner.execute(exec, args, input, function(data)
        vim.schedule(function()
            testcase.duration = data.duration
            if data.error then
                testcase.status = "ERROR"
            elseif data.msg then
                data.msg = data.msg:sub(-1) == "\n" and data.msg:sub(1, -2) or data.msg
                testcase.output = vim.split(data.msg, "\n")
                if data.msg == table.concat(testcase.expect, "\n") then
                    testcase.status = "AC"
                else
                    testcase.status = "WA"
                end
            end
            self:show_testcases()
        end)
    end)
end

function MAIN:excute_all()
    for _, testcase in pairs(self.testcases) do
        local id = testcase.id
        if id ~= 0 then
            self:execute(id)
        end
    end
end

return MAIN
