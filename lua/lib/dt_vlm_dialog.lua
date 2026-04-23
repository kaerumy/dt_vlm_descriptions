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
    dt_vlm_dialog
    Reusable dialog component for editing VLM-suggested metadata.

    USAGE
    * Include this file from your main lua script:
        local dvd = require "lib/dt_vlm_dialog"
    * Functions available:
        dvd.show(options) - Display the edit dialog
            options.title        - Pre-filled title string
            options.description  - Pre-filled description string
            options.image        - darktable image object to save to
            options.on_save      - Callback(title, description, image) on save
            options.on_cancel    - Callback() on cancel
            options.on_clear     - Callback() on clear
        dvd.hide()           - Close the currently open dialog
        dvd.is_visible()     - Returns true if dialog is open
]]

local dt = require "darktable"

local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

local _dialog = nil
local _title_entry = nil
local _desc_buffer = nil
local _current_image = nil
local _on_save = nil
local _on_cancel = nil
local _on_clear = nil

-- ---------------------------------------------------------------------------
-- Dialog creation
-- ---------------------------------------------------------------------------

local function _create_dialog(options)
  options = options or {}

  -- Destroy existing dialog if any
  if _dialog then
    dt.gui.widgets.dialog:destroy()
    _dialog = nil
  end

  -- Title input
  _title_entry = dt.new_widget("entry") {
    tooltip = _("Enter or edit the title"),
    placeholder = _("enter title here"),
  }
  _title_entry.text = options.title or ""

  local title_box = dt.new_widget("box") {
    orientation = "horizontal",
    fill = true,
    dt.new_widget("label") { label = _("Title:") },
    _title_entry,
  }

  _desc_buffer = dt.new_widget("text_view") {
    tooltip = _("Enter or edit the description"),
    editable = true,
  }
  _desc_buffer.text = options.description or ""

  local desc_box = dt.new_widget("box") {
    orientation = "horizontal",
    expand = true,
    fill = true,
    dt.new_widget("label") { label = _("Description:") },
    _desc_buffer,
  }

  -- Save button
  local save_button = dt.new_widget("button") {
    label = _("Save"),
    tooltip = _("Save title and description to image metadata"),
  }

  -- Clear button
  local clear_button = dt.new_widget("button") {
    label = _("Clear"),
    tooltip = _("Clear title and description fields"),
  }

  -- Cancel button
  local cancel_button = dt.new_widget("button") {
    label = _("Cancel"),
    tooltip = _("Close without saving"),
  }

  -- Save callback
  save_button.clicked_callback = function()
    local title = _title_entry and _title_entry.text or ""
    local description = _desc_buffer and _desc_buffer.text or ""
    if _on_save then
      _on_save(title, description, _current_image)
    end
    _close_dialog()
  end

  -- Clear callback
  clear_button.clicked_callback = function()
    if _title_entry then
      _title_entry.text = ""
    end
    if _desc_buffer then
      _desc_buffer.text = ""
    end
    if _on_clear then
      _on_clear()
    end
  end

  -- Cancel callback
  cancel_button.clicked_callback = function()
    if _on_cancel then
      _on_cancel()
    end
    _close_dialog()
  end

  -- Button row
  local button_box = dt.new_widget("box") {
    orientation = "horizontal",
    dt.new_widget("center") {},
    save_button,
    clear_button,
    cancel_button,
  }

  -- Content
  local content_box = dt.new_widget("box") {
    orientation = "vertical",
    title_box,
    desc_box,
    button_box,
  }

  -- Dialog
  _dialog = dt.new_widget("dialog") {
    title = _("Edit Title & Description"),
    content_box,
  }

  _dialog:show()
end

-- ---------------------------------------------------------------------------
-- Close / Cleanup
-- ---------------------------------------------------------------------------

local function _close_dialog()
  if _dialog then
    _dialog:destroy()
    _dialog = nil
  end
  _title_entry = nil
  _desc_buffer = nil
  _current_image = nil
  _on_save = nil
  _on_cancel = nil
  _on_clear = nil
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

local dt_vlm_dialog = {}

function dt_vlm_dialog.show(options)
  options = options or {}
  _current_image = options.image
  _on_save = options.on_save
  _on_cancel = options.on_cancel
  _on_clear = options.on_clear
  _create_dialog(options)
end

function dt_vlm_dialog.hide()
  _close_dialog()
end

function dt_vlm_dialog.is_visible()
  return _dialog ~= nil
end

function dt_vlm_dialog.get_title()
  if _title_entry then
    return _title_entry.text
  end
  return ""
end

function dt_vlm_dialog.get_description()
  if _desc_buffer then
    return _desc_buffer.text or ""
  end
  return ""
end

function dt_vlm_dialog.get_image()
  return _current_image
end

function dt_vlm_dialog.save_now()
  if not _dialog or not _title_entry or not _desc_buffer then
    return false
  end
  local title = _title_entry.text
  local description = _desc_buffer.text
  if _on_save then
    _on_save(title, description, _current_image)
  end
  _close_dialog()
  return true
end

function dt_vlm_dialog.clear_now()
  if _title_entry then
    _title_entry.text = ""
  end
  if _desc_buffer then
    _desc_buffer.text = ""
  end
  if _on_clear then
    _on_clear()
  end
end

return dt_vlm_dialog
