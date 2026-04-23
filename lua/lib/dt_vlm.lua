--[[
    This file is part of darktable,
    copyright (c) 2025 <your-name>

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
    dt_vlm
    Helper library for VLM (Vision-Language Model) API interactions.

    USAGE
    * Include this file from your main lua script:
        local dv = require "lib/dt_vlm"
    * Functions available:
        dv.json_parse(string)             - Parse JSON string to Lua table
        dv.encode_base64(string)          - Encode binary data to base64
        dv.call_vlm(image_path, options)  - Call VLM API and return parsed result
        dv.build_vlm_request(image_path, options) - Build and send request, return raw response
        dv.parse_vlm_response(response)   - Parse VLM JSON response to {title, description}
        dv.encode_image(image_path)       - Read and base64-encode an image file
        dv.resize_image(image_path, max_dim) - Resize image to fit within max_dim pixels
        dv.encode_image_resized(image_path, max_dim) - Resize and encode an image for VLM
        dv.escape_json_string(str)        - Escape a string for use in JSON
        dv.extract_json(str)              - Extract JSON object from freeform text
]]

local dt = require "darktable"

-- ---------------------------------------------------------------------------
-- JSON parser
-- ---------------------------------------------------------------------------

local function json_parse(s)
  local function skip_ws(str, pos)
    while pos <= #str and (str:sub(pos, pos):match("%s")) do
      pos = pos + 1
    end
    return pos
  end

  local function parse_string(str, pos)
    pos = skip_ws(str, pos)
    if str:sub(pos, pos) ~= '"' then return nil, pos end
    pos = pos + 1
    local result = ""
    while pos <= #str do
      local ch = str:sub(pos, pos)
      if ch == '"' then
        return result, pos + 1
      elseif ch == '\\' then
        pos = pos + 1
        local next_ch = str:sub(pos, pos)
        if next_ch == '"' then result = result .. '"'
        elseif next_ch == '\\' then result = result .. '\\'
        elseif next_ch == 'n' then result = result .. '\n'
        elseif next_ch == 't' then result = result .. '\t'
        elseif next_ch == 'r' then result = result .. '\r'
        else result = result .. next_ch
        end
      else
        result = result .. ch
      end
      pos = pos + 1
    end
    return nil, pos
  end

  local function parse_number(str, pos)
    pos = skip_ws(str, pos)
    local start = pos
    if str:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #str and str:sub(pos, pos):match("[%d]") do pos = pos + 1 end
    if pos <= #str and str:sub(pos, pos) == '.' then
      pos = pos + 1
      while pos <= #str and str:sub(pos, pos):match("[%d]") do pos = pos + 1 end
    end
    if pos <= #str and (str:sub(pos, pos) == 'e' or str:sub(pos, pos) == 'E') then
      pos = pos + 1
      if pos <= #str and (str:sub(pos, pos) == '+' or str:sub(pos, pos) == '-') then pos = pos + 1 end
      while pos <= #str and str:sub(pos, pos):match("[%d]") do pos = pos + 1 end
    end
    return tonumber(str:sub(start, pos - 1)), pos
  end

  -- Forward declarations for mutually recursive functions
  local parse_value, parse_object, parse_array

  parse_object = function(str, pos)
    pos = skip_ws(str, pos)
    pos = pos + 1
    local obj = {}
    pos = skip_ws(str, pos)
    if str:sub(pos, pos) == '}' then return {}, pos + 1 end
    while true do
      pos = skip_ws(str, pos)
      local key, new_pos = parse_string(str, pos)
      if not key then return {}, new_pos end
      pos = skip_ws(str, new_pos)
      pos = pos + 1
      local value, new_pos = parse_value(str, pos)
      obj[key] = value
      pos = skip_ws(str, new_pos)
      local ch = str:sub(pos, pos)
      if ch == '}' then return obj, pos + 1 end
      pos = pos + 1
    end
  end

  parse_array = function(str, pos)
    pos = skip_ws(str, pos)
    pos = pos + 1
    local arr = {}
    pos = skip_ws(str, pos)
    if str:sub(pos, pos) == ']' then return {}, pos + 1 end
    local idx = 1
    while true do
      local value, new_pos = parse_value(str, pos)
      arr[idx] = value
      idx = idx + 1
      pos = skip_ws(str, new_pos)
      local ch = str:sub(pos, pos)
      if ch == ']' then return arr, pos + 1 end
      pos = pos + 1
    end
  end

  parse_value = function(str, pos)
    pos = skip_ws(str, pos)
    if pos > #str then return nil, pos end
    local ch = str:sub(pos, pos)
    if ch == '"' then return parse_string(str, pos)
    elseif ch == '{' then return parse_object(str, pos)
    elseif ch == '[' then return parse_array(str, pos)
    elseif ch == 't' then
      if str:sub(pos, pos + 3) == 'true' then return true, pos + 4
      else return nil, pos end
    elseif ch == 'f' then
      if str:sub(pos, pos + 4) == 'false' then return false, pos + 5
      else return nil, pos end
    elseif ch == 'n' then
      if str:sub(pos, pos + 3) == 'null' then return nil, pos + 4
      else return nil, pos end
    else
      return parse_number(str, pos)
    end
  end

  local result, _ = parse_value(s, 1)
  return result
end

-- ---------------------------------------------------------------------------
-- Base64 encoding
-- ---------------------------------------------------------------------------

local function encode_base64(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local result = {}
  local len = #data
  local i = 1
  while i <= len - 2 do
    local c1, c2, c3 = string.byte(data, i, i + 2)
    local a1 = math.floor(c1 / 4)
    local a2 = (c1 % 4) * 16 + math.floor(c2 / 16)
    local a3 = (c2 % 16) * 4 + math.floor(c3 / 64)
    local a4 = c3 % 64
    result[#result + 1] = b:sub(a1 + 1, a1 + 1)
    result[#result + 1] = b:sub(a2 + 1, a2 + 1)
    result[#result + 1] = b:sub(a3 + 1, a3 + 1)
    result[#result + 1] = b:sub(a4 + 1, a4 + 1)
    i = i + 3
  end
  if i <= len then
    local c1 = string.byte(data, i)
    local a1 = math.floor(c1 / 4)
    local a2 = (c1 % 4) * 16
    if i + 1 <= len then
      local c2 = string.byte(data, i + 1)
      a2 = a2 + math.floor(c2 / 16)
      local a3 = (c2 % 16) * 4
      result[#result + 1] = b:sub(a1 + 1, a1 + 1)
      result[#result + 1] = b:sub(a2 + 1, a2 + 1)
      result[#result + 1] = b:sub(a3 + 1, a3 + 1)
      result[#result + 1] = "="
    else
      result[#result + 1] = b:sub(a1 + 1, a1 + 1)
      result[#result + 1] = b:sub(a2 + 1, a2 + 1)
      result[#result + 1] = "="
      result[#result + 1] = "="
    end
  end
  return table.concat(result)
end

-- ---------------------------------------------------------------------------
-- Image encoding
-- ---------------------------------------------------------------------------

local function encode_image(image_path)
  local f = io.open(image_path, "rb")
  if not f then
    return nil, "Cannot open image file: " .. image_path
  end
  local image_data = f:read("*a")
  f:close()
  return encode_base64(image_data), nil
end

-- ---------------------------------------------------------------------------
-- Image resizing for VLM
-- ---------------------------------------------------------------------------

local function resize_image(image_path, max_dim)
  max_dim = max_dim or 1024

  local tmpfile = os.tmpname() .. ".jpg"

  -- Use ImageMagick to resize longest side to max_dim, preserving aspect ratio
  -- "resize 1024x1024>" means: shrink to fit within 1024x1024 box, keep aspect ratio
  local resize_cmd = string.format(
    'convert "%s" -resize "%dx%d>" -quality 85 "%s"',
    image_path,
    max_dim,
    max_dim,
    tmpfile
  )

  local ret = os.execute(resize_cmd)
  local success = type(ret) == "number" and ret == 0 or (type(ret) == "boolean" and ret == true)
  if not success then
    os.remove(tmpfile)
    return nil, "Image resize failed"
  end

  return tmpfile, nil
end

local function encode_image_resized(image_path, max_dim)
  local resized_path, err = resize_image(image_path, max_dim)
  if err then
    return nil, err
  end

  -- Resize returns a temp file that caller must clean up
  local encoded, err = encode_image(resized_path)
  if err then
    os.remove(resized_path)
    return nil, err
  end

  return encoded, resized_path
end

-- ---------------------------------------------------------------------------
-- JSON string escaping
-- ---------------------------------------------------------------------------

local function escape_json_string(str)
  return str
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

-- ---------------------------------------------------------------------------
-- JSON extraction from freeform text
-- ---------------------------------------------------------------------------

local function extract_json(str)
  -- Strip markdown code blocks if present
  str = str:gsub("^%s*```%w*\n?", ""):gsub("\n?```%s*$", "")

  -- Try to find JSON object in the response
  local start_pos = str:find("{")
  local end_pos = str:find("}")
  if start_pos and end_pos and end_pos > start_pos then
    return str:sub(start_pos, end_pos)
  end
  return str
end

-- ---------------------------------------------------------------------------
-- VLM response parsing
-- ---------------------------------------------------------------------------

local function parse_vlm_response(response)
  local result = json_parse(response)

  if not result then
    return nil
  end

  -- Try direct title/description first
  if result.title and result.description then
    return { title = result.title, description = result.description }
  end

  -- Try OpenAI API response format
  local choices = result.choices
  if type(choices) == "table" and #choices > 0 then
    local message = choices[1].message
    if message and type(message) == "table" then
      local content = message.content
      if type(content) == "string" and content ~= "" then
        local json_str = extract_json(content)
        local parsed = json_parse(json_str)
        if parsed and parsed.title and parsed.description then
          return { title = parsed.title, description = parsed.description }
        end
      end
    end
  end

  return nil
end

-- ---------------------------------------------------------------------------
-- VLM request building and sending
-- ---------------------------------------------------------------------------

local function build_vlm_request(image_path, options)
  options = options or {}

  local endpoint = options.endpoint or "http://localhost:8080/v1/chat/completions"
  local model = options.model or ""
  local max_tokens = options.max_tokens or 4096
  local temperature = options.temperature or 0.3
  local prompt = options.prompt or [[Analyze this image and provide a concise title and description in JSON format.
Rules:
- Title: A short, descriptive title (max 80 characters)
- Description: A detailed description of the image content (max 300 characters).
- Return ONLY valid JSON with keys "title" and "description"
- Do not include any markdown formatting, backticks, or explanation text]]

  if options.title and options.title ~= "" then
    prompt = prompt .. "\n\nCurrent title: " .. options.title
  end
  if options.description and options.description ~= "" then
    prompt = prompt .. "\nCurrent description: " .. options.description
  end

  -- Resize and encode image for VLM
  local max_dim = options.max_dim or 1024
  local encoded, tmpfile = encode_image_resized(image_path, max_dim)
  if not encoded then
    return nil, tmpfile
  end

  local data_uri = "data:image/jpeg;base64," .. encoded
  local escaped_prompt = escape_json_string(prompt)

  -- Build request as JSON string
  local request_body = '{"model":"' .. model
    .. '","messages":[{"role":"user","content":['
    .. '{"type":"text","text":"' .. escaped_prompt .. '"},'
    .. '{"type":"image_url","image_url":{"url":"' .. data_uri .. '"}}'
    .. ']}],"max_tokens":' .. max_tokens
    .. ',"temperature":' .. temperature .. '}'

  return request_body, endpoint, tmpfile
end

local function call_vlm(image_path, options)
  options = options or {}

  -- Build request (includes resized image temp file)
  local request_body, endpoint, tmpfile = build_vlm_request(image_path, options)
  if not request_body then
    return nil, endpoint
  end

  -- Write request to temp file to avoid shell argument length limits
  local req_tmpfile = os.tmpname()
  local req_f = io.open(req_tmpfile, "w")
  if not req_f then
    os.remove(tmpfile)
    return nil, "Cannot create temp file for request"
  end
  req_f:write(request_body)
  req_f:close()

  -- Validate request body
  local req_size = #request_body
  dt.print_log("request body size: " .. req_size .. " bytes")
  dt.print_log("request body preview: " .. request_body:sub(1, 200))

  local resp_tmpfile = os.tmpname()
  local err_tmpfile = os.tmpname()

  -- Use os.execute with proper file redirection
  local curl_cmd = string.format(
    'curl -s --max-time 120 -X POST -H "Content-Type: application/json" -d @%s "%s" > %s 2> %s',
    req_tmpfile,
    endpoint,
    resp_tmpfile,
    err_tmpfile
  )

  dt.print_log("curl command: " .. curl_cmd)

  local ret = os.execute(curl_cmd)
  os.remove(req_tmpfile)

  local response = ""
  local resp_f = io.open(resp_tmpfile, "r")
  if resp_f then
    response = resp_f:read("*a")
    resp_f:close()
  end
  os.remove(resp_tmpfile)

  local err_output = ""
  local err_f = io.open(err_tmpfile, "r")
  if err_f then
    err_output = err_f:read("*a")
    err_f:close()
  end
  os.remove(err_tmpfile)

  dt.print_log("curl exit code: " .. tostring(ret))
  dt.print_log("curl stderr: " .. err_output)
  dt.print_log("curl output: " .. response)

  if err_output and #err_output > 0 then
    os.remove(tmpfile)
    return nil, "VLM API call failed: " .. err_output
  end

  os.remove(tmpfile)

  -- Parse response
  return parse_vlm_response(response), nil
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

local dt_vlm = {
  json_parse = json_parse,
  encode_base64 = encode_base64,
  encode_image = encode_image,
  resize_image = resize_image,
  encode_image_resized = encode_image_resized,
  escape_json_string = escape_json_string,
  extract_json = extract_json,
  parse_vlm_response = parse_vlm_response,
  build_vlm_request = build_vlm_request,
  call_vlm = call_vlm,
}

return dt_vlm
