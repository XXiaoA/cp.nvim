local uv = vim.loop
local M = {}

function M.write_file(path, content)
    local fd = assert(uv.fs_open(path, "w", 420))
    assert(uv.fs_write(fd, content, 0))
    assert(uv.fs_close(fd))
end

function M.create_file(path)
    M.write_file(path, "")
end

--- read the content of a file. return `nil` if the file does not exist
---@param path string
---@return string[]|nil
function M.read_file(path)
    local fd = uv.fs_open(path, "r", 438)
    if fd == nil then
        return nil
    end
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    data = data:sub(-1) == "\n" and data:sub(1, -2) or data
    return vim.split(data, "\n")
end

function M.round(num)
    return math.floor(num + 0.5)
end

--- get the resolution of the screen and scale it
---@param scale number? defaults to 1
---@return {width: integer, height: integer}
function M.get_resolution(scale)
    scale = scale or 1
    local width = vim.o.columns
    local height = vim.o.lines - vim.o.cmdheight
    height = vim.o.laststatus == 3 and height - 1 or height
    return { width = M.round(width * scale), height = M.round(height * scale) }
end

return M
