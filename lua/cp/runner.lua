local uv = vim.uv
local M = {}

---@param exec string
---@param args string[]
---@param callback fun(data: table)
function M.compile(exec, args, callback)
    -- wrap the process
    -- we will run plenty of test at the same time. If we don't do so, we may close the same pip or handle multiple times
    local process = {}
    process.stderr = uv.new_pipe()
    if process.stderr == nil then
        vim.notify("cp.nvim: Failed to create pipe", vim.log.levels.WARN)
        return
    end

    local stderr_data
    local start_time = uv.now()

    ---@diagnostic disable-next-line: missing-fields
    process.handle = uv.spawn(exec, {
        args = args,
        stdio = { nil, nil, process.stderr },
    }, function(code, signal) -- on exit
        local result = { duration = uv.now() - start_time, msg = stderr_data }
        if code ~= 0 or signal ~= 0 then
            result.error = true
        else
            result.error = false
        end
        callback(result)
        process.stderr:close()
        process.handle:close()
    end)

    process.stderr:read_start(function(_, data)
        stderr_data = data
        process.stderr:read_stop()
    end)
end

---@param exec string
---@param args string[]
---@param input string|string[]
---@param callback fun(data: table)
function M.execute(exec, args, input, callback)
    if type(input) == "table" then
        input = table.concat(input, "\n")
    end

    local process = {}
    process.stderr = uv.new_pipe()
    process.stdin = uv.new_pipe()
    process.stdout = uv.new_pipe()
    if process.stderr == nil or process.stdin == nil or process.stdout == nil then
        vim.notify("cp.nvim: Failed to create pipe", vim.log.levels.WARN)
        return
    end

    local stdout_data
    local start_time = uv.now()

    ---@diagnostic disable-next-line: missing-fields
    process.handle = uv.spawn(exec, {
        args = args,
        stdio = { process.stdin, process.stdout, process.stderr },
    }, function(code, signal) -- on exit
        local result = { duration = uv.now() - start_time, error = false, msg = stdout_data }
        if code ~= 0 then
            result.error = "code"
            result.msg = code
        elseif signal ~= 0 then
            result.error = "signal"
            result.msg = signal
        end
        callback(result)
        process.stdout:close()
        process.stderr:close()
        process.handle:close()
    end)

    process.stdin:write(input)
    process.stdin:shutdown(function()
        process.stdin:close()
    end)

    process.stdout:read_start(function(_, data)
        stdout_data = data
        process.stdout:read_stop()
    end)

    -- process.stderr:read_start(function(_, data)
    --     if data then
    --         print(data)
    --     end
    --     process.stderr:read_stop()
    -- end)
end

return M
