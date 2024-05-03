---@alias status "ERROR"|"DONE"|"NONE"|"AC"|"WA"
---@alias testcase { id: number, kind: string, status: status, duration: number|nil, input: string[], expect: string[], output: string[] }

---@class MAIN
---@field wins table
---@field testcases testcase[]
---@field buf number
---@field compilable number 1 means true, 0 means false
