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
    dt_vlm_test
    Unit tests for the dt_vlm helper library.

    USAGE
    * Run from darktable lua console or include in a test script:
        local dv = require "lib/dt_vlm"
        require "lib/dt_vlm_test"
    * Tests are run automatically when this file is loaded
]]

local dv = require "lib/dt_vlm"

local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function assert_equal(actual, expected, test_name)
  tests_run = tests_run + 1
  if actual == expected then
    tests_passed = tests_passed + 1
  else
    tests_failed = tests_failed + 1
  end
end

local function assert_true(val, test_name)
  tests_run = tests_run + 1
  if val then
    tests_passed = tests_passed + 1
  else
    tests_failed = tests_failed + 1
  end
end

local function assert_nil(val, test_name)
  tests_run = tests_run + 1
  if val == nil then
    tests_passed = tests_passed + 1
  else
    tests_failed = tests_failed + 1
  end
end

local function assert_type(val, expected_type, test_name)
  tests_run = tests_run + 1
  if type(val) == expected_type then
    tests_passed = tests_passed + 1
  else
    tests_failed = tests_failed + 1
  end
end

-- ---------------------------------------------------------------------------
-- JSON parser tests
-- ---------------------------------------------------------------------------

-- Simple object
local result = dv.json_parse('{"title": "Test", "description": "OK"}')
assert_equal(result.title, "Test", "json_parse: simple object - title")
assert_equal(result.description, "OK", "json_parse: simple object - description")

-- Empty object
result = dv.json_parse('{}')
assert_type(result, "table", "json_parse: empty object")

-- Empty string
result = dv.json_parse('')
assert_nil(result, "json_parse: empty string")

-- Escaped characters in strings
result = dv.json_parse('{"text": "hello\\nworld\\ttab"}')
assert_equal(result.text, "hello\nworld\ttab", "json_parse: escaped characters")

-- Nested object
result = dv.json_parse('{"outer": {"inner": "value"}}')
assert_equal(result.outer.inner, "value", "json_parse: nested object")

-- Array
result = dv.json_parse('[1, 2, 3]')
assert_equal(result[1], 1, "json_parse: array - first element")
assert_equal(result[3], 3, "json_parse: array - third element")

-- Mixed types
result = dv.json_parse('{"bool": true, "num": 42, "null": null, "neg": -5}')
assert_true(result.bool, "json_parse: boolean true")
assert_equal(result.num, 42, "json_parse: integer")
assert_nil(result.null, "json_parse: null")
assert_equal(result.neg, -5, "json_parse: negative number")

-- Float
result = dv.json_parse('{"pi": 3.14}')
assert_equal(result.pi, 3.14, "json_parse: float")

-- ---------------------------------------------------------------------------
-- Base64 encoding tests
-- ---------------------------------------------------------------------------

local encoded = dv.encode_base64("Man")
assert_equal(encoded, "TWFu", "encode_base64: simple string")

encoded = dv.encode_base64("Ma")
assert_equal(encoded, "TWE=", "encode_base64: 2 bytes (padded)")

encoded = dv.encode_base64("M")
assert_equal(encoded, "TQ==", "encode_base64: 1 byte (padded)")

encoded = dv.encode_base64("")
assert_equal(encoded, "", "encode_base64: empty string")

-- ---------------------------------------------------------------------------
-- JSON string escaping tests
-- ---------------------------------------------------------------------------

local escaped = dv.escape_json_string('hello "world"')
assert_equal(escaped, 'hello \\"world\\"', "escape_json_string: quotes")

escaped = dv.escape_json_string("line1\nline2")
assert_equal(escaped, "line1\\nline2", "escape_json_string: newline")

escaped = dv.escape_json_string("tab\there")
assert_equal(escaped, "tab\\there", "escape_json_string: tab")

escaped = dv.escape_json_string("back\\slash")
assert_equal(escaped, "back\\\\slash", "escape_json_string: backslash")

-- ---------------------------------------------------------------------------
-- JSON extraction tests
-- ---------------------------------------------------------------------------

local extracted = dv.extract_json('```json\n{"title": "test"}\n```')
assert_equal(extracted, '{"title": "test"}', "extract_json: markdown code blocks")

extracted = dv.extract_json('Some text {"key": "value"} more text')
assert_equal(extracted, '{"key": "value"}', "extract_json: embedded JSON")

extracted = dv.extract_json('{"standalone": true}')
assert_equal(extracted, '{"standalone": true}', "extract_json: plain JSON")

-- ---------------------------------------------------------------------------
-- VLM response parsing tests
-- ---------------------------------------------------------------------------

local result = dv.parse_vlm_response('{"title": "Sunset", "description": "Beautiful sunset"}')
assert_equal(result.title, "Sunset", "parse_vlm_response: valid JSON")
assert_equal(result.description, "Beautiful sunset", "parse_vlm_response: valid JSON desc")

-- Markdown-wrapped response
result = dv.parse_vlm_response('```json\n{"title": "Mountain", "description": "Peaks"}\n```')
assert_equal(result.title, "Mountain", "parse_vlm_response: markdown-wrapped JSON")

-- Invalid JSON
result = dv.parse_vlm_response("not json at all")
assert_nil(result, "parse_vlm_response: invalid JSON returns nil")

-- Missing fields
result = dv.parse_vlm_response('{"title": "Only title"}')
assert_nil(result, "parse_vlm_response: missing description returns nil")

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

print("========================================")
print("dt_vlm_test results:")
print("  Tests run:    " .. tests_run)
print("  Passed:       " .. tests_passed)
print("  Failed:       " .. tests_failed)
print("========================================")

if tests_failed == 0 then
  print("All tests passed!")
else
  print("Some tests failed!")
end
