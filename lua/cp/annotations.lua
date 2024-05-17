---@alias status "ERROR"|"DONE"|"NONE"|"AC"|"WA"
---@alias testcase { id: number, kind: string, status: status, duration: number|nil, input: string[], expect: string[], output: string[] }

---@class CpMain
---@field wins table
---@field testcases testcase[]
---@field buf number
---@field compilable number 1 means true, 0 means false

---@class CpSubcommand
---@field impl fun(args:string[], opts: table) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments
