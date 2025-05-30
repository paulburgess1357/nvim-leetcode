-- Setup for problem directories and dependencies
local vim = vim
local C = require "LeetNeoCode.config"
local cache = require "LeetNeoCode.problem.cache"
local paths = require "LeetNeoCode.utils.path"
local languages = require "LeetNeoCode.problem.helper.languages"
local file_utils = require "LeetNeoCode.problem.util.file_utils"
local directory = require "LeetNeoCode.problem.util.directory"
local fetcher = require "LeetNeoCode.problem.util.fetcher"

local M = {}

-- Prepare solution directory for a problem (delegate to directory module)
M.prepare_solution_dir = directory.prepare_solution_dir

-- Setup dependencies (symlinks or copies)
function M.setup_dependencies(prob_dir)
  local dep_dir = paths.find_dependencies_dir()
  local language = C.default_language

  -- Get language from file extension
  local lang = languages.language_map[language]
  local deps = languages.dependencies[lang]

  if not deps then
    vim.notify("No dependency configuration for language: " .. language, vim.log.levels.WARN)
    return
  end

  for _, dep in ipairs(deps) do
    local src = dep_dir .. "/" .. dep.src
    local dst = prob_dir .. "/" .. dep.dst
    file_utils.create_dependency_link(src, dst)
  end
end

-- Fetch problem data (delegate to fetcher module)
-- Fetch problem data (optionally limited to just code)
function M.fetch_problem_data(slug, code_only)
  if not slug then
    return nil, nil
  end

  local snippets
  do
    local ok, res = pcall(fetcher.fetch_code_stub, slug)
    snippets = ok and res or nil
    if not snippets then
      vim.notify("Could not fetch code stub for problem", vim.log.levels.WARN)
    end
  end

  -- If code_only is true, return empty problem_data
  if code_only then
    return { content = "" }, snippets
  end

  -- Otherwise fetch the full problem data
  local problem_data
  do
    local ok, result = pcall(fetcher.fetch_problem_description, slug)
    problem_data = ok and type(result) == "table" and result or { content = "" }
    if problem_data.content == "" then
      vim.notify("Could not fetch description for problem", vim.log.levels.WARN)
    end
  end

  return problem_data, snippets
end

-- Determine next solution version and save file
function M.save_solution_file(prob_dir, snippets, problem_data)
  if not snippets then
    return nil, 0
  end

  -- Find next version number
  local version = file_utils.get_next_solution_version(prob_dir)

  -- Get file extension for current language
  local extension = languages.extension_map[C.default_language] or "txt"

  local fname = string.format("Solution_%d.%s", version, extension)
  local fpath = prob_dir .. "/" .. fname

  -- Get fold markers
  local fold_start = C.fold_marker_start or "▼"
  local fold_end = C.fold_marker_end or "▲"

  -- Write the solution file with appropriate headers and metadata
  local success = file_utils.write_solution_file(fpath, snippets, problem_data, fold_start, fold_end)

  if not success then
    vim.notify("Failed to write solution file", vim.log.levels.ERROR)
    return nil, 0
  end

  return fpath, version
end

return M
