local api = vim.api

---@class WINDOW
---@field win number
---@field buf number
---@field augroup number
local WINDOW = {}

--- create a new window
---@param mode string `float` or a command passed to the `vim.cmd()`
---@param config table?
---@return WINDOW
function WINDOW:new(mode, config)
    local o = {
        win = nil,
        buf = nil,
        win_opts = {
            nu = true,
            rnu = false,
            list = false,
            wfb = true,
            wrap = false,
        },
        buf_opts = {
            filetype = "cp",
            modifiable = false,
            vartabstop = "10,10", -- align the content
        },
    }
    config = config or {}

    if mode == "float" then
        assert(config ~= nil, "Floating window requires a config table")
        local enter = true
        if config.enter ~= nil then
            enter = config.enter
            -- nvim_open_win dont have the option `enter`
            config.enter = nil
        end
        o.win = api.nvim_open_win(0, enter, config)
    else
        vim.cmd(mode)
        o.win = api.nvim_get_current_win()
        if config.width then
            api.nvim_win_set_width(o.win, config.width)
        end
        if config.height then
            api.nvim_win_set_height(o.win, config.height)
        end
    end
    o.buf = api.nvim_create_buf(false, true)

    api.nvim_win_set_buf(o.win, o.buf)
    for option, value in pairs(o.win_opts) do
        vim.wo[o.win][option] = value
    end
    for option, value in pairs(o.buf_opts) do
        vim.bo[o.buf][option] = value
    end

    o.augroup = api.nvim_create_augroup("cp" .. o.win, { clear = true })
    api.nvim_create_autocmd("WinClosed", {
        buffer = o.buf,
        group = o.augroup,
        callback = function()
            api.nvim_buf_delete(o.buf, { force = true })
            api.nvim_del_augroup_by_name("cp" .. o.win)
        end,
    })

    self.__index = self
    setmetatable(o, self)
    return o
end

--- Examples:
--- ```lua
-- win:set_text({ "123", "456" }) -- replace the whole buffer
-- win:set_text({ "APPEND" }, -1) -- append at the end
-- win:set_text({ "APPEND2" }, 1, 1) -- append after line 1
-- win:set_text({ "REPLACE" }, 1, 2) -- replace line 2
--- ````
---@param texts string[]|nil nil to clean the buffer
---@param start_lnum number? defaults to 0
---@param end_lnum number? defaults to -1
function WINDOW:set_text(texts, start_lnum, end_lnum)
    texts = texts or {}
    start_lnum = start_lnum or 0
    end_lnum = end_lnum or -1
    local _ma
    if vim.bo[self.buf].modifiable == false then
        vim.bo[self.buf].modifiable = true
        _ma = true
    end
    api.nvim_buf_set_lines(self.buf, start_lnum, end_lnum, true, texts)
    if _ma then
        vim.bo[self.buf].modifiable = false
    end
end

--- set the option. eg:
--- ```lua
--- {
---     buf = { ft = "xx" },
---     win = { nu = false }
--- }
--- ```
---@param opts table
function WINDOW:set_opt(opts)
    for mode, opt in pairs(opts) do
        if mode == "buf" then
            for option, value in pairs(opt) do
                vim.bo[self.buf][option] = value
            end
        elseif mode == "win" then
            for option, value in pairs(opt) do
                vim.wo[self.win][option] = value
            end
        end
    end
end

function WINDOW:autocmd(event, callback)
    api.nvim_create_autocmd(event, { group = self.augroup, callback = callback, buffer = self.buf })
end

function WINDOW:keymap(mode, lhs, rhs, opts)
    if type(lhs) == "string" then
        lhs = { lhs }
    end
    for _, l in ipairs(lhs) do
        vim.keymap.set(mode, l, rhs, vim.tbl_extend("force", { buffer = self.buf }, opts or {}))
    end
end

return WINDOW
