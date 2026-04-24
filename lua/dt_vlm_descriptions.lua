--[[
    This file is part of darktable,
    copyright (c) 2025 Khairil Yusof.

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
    dt_vlm_descriptions
    Uses a local AI VLM via OpenAI-compatible endpoint to suggest Title
    and Description metadata for selected photos in darktable.

    USAGE
    * require this file from your main lua config file (luarc):
        require "dt_vlm_descriptions"
    * A new panel "VLM Descriptions" will appear in lighttable
    * Select an image and click "Suggest" to get AI-generated title/description
    * Edit the suggestions, then click "Save" to store in metadata
    * Click "Clear" to clear the dialog fields
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local dv = require "dt_vlm_descriptions/lua/lib/dt_vlm"
local dvd = require "dt_vlm_descriptions/lua/lib/dt_vlm_dialog"

du.check_min_api_version("7.0.0", "dt_vlm_descriptions")

local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- ---------------------------------------------------------------------------
-- Configuration / Preferences
-- ---------------------------------------------------------------------------

dt.preferences.register(
  "dt_vlm_descriptions",
  "vlm_endpoint",
  "string",
  _("VLM API Endpoint URL"),
  _("Full URL of the OpenAI-compatible VLM endpoint (e.g. http://localhost:8000/v1/chat/completions)"),
  "http://localhost:8000/v1/chat/completions"
)

dt.preferences.register(
  "dt_vlm_descriptions",
  "vlm_model",
  "string",
  _("VLM Model Name"),
  _("Name of the model to use for suggestions"),
  ""
)

dt.preferences.register(
  "dt_vlm_descriptions",
  "vlm_max_tokens",
  "integer",
  _("VLM Max Tokens"),
  _("Maximum number of tokens in the VLM response"),
  4096,
  50,
  8192
)

dt.preferences.register(
  "dt_vlm_descriptions",
  "vlm_temperature",
  "float",
  _("VLM Temperature"),
  _("Creativity level for VLM generation (0.0 - 1.0)"),
  0.6,
  0.0,
  1.0,
  0.1
)

dt.preferences.register(
  "dt_vlm_descriptions",
  "vlm_max_dim",
  "integer",
  _("VLM Max Image Dimension"),
  _("Maximum dimension (longest side) for image resize before sending to VLM (pixels)"),
  1024,
  256,
  4096
)

dt.preferences.register(
  "dt_vlm_descriptions",
  "panel_position",
  "enum",
  _("VLM Descriptions Panel Position"),
  _("Panel location in the lighttable view"),
  "DT_UI_CONTAINER_PANEL_RIGHT_CENTER",
  "DT_UI_CONTAINER_PANEL_RIGHT_CENTER",
  "DT_UI_CONTAINER_PANEL_RIGHT_BOTTOM",
  "DT_UI_CONTAINER_PANEL_LEFT_CENTER",
  "DT_UI_CONTAINER_PANEL_LEFT_BOTTOM"
)

-- ---------------------------------------------------------------------------
-- VLM API call (delegates to lib/dt_vlm)
-- ---------------------------------------------------------------------------

local function call_vlm(image_path, title, description, image_obj)
  local endpoint = dt.preferences.read("dt_vlm_descriptions", "vlm_endpoint", "string")
  local model = dt.preferences.read("dt_vlm_descriptions", "vlm_model", "string")
  local max_tokens = dt.preferences.read("dt_vlm_descriptions", "vlm_max_tokens", "integer")
  local temperature = dt.preferences.read("dt_vlm_descriptions", "vlm_temperature", "float")
  local max_dim = dt.preferences.read("dt_vlm_descriptions", "vlm_max_dim", "integer")

  local result, err = dv.call_vlm(image_path, {
    endpoint = endpoint,
    model = model,
    max_tokens = max_tokens,
    temperature = temperature,
    max_dim = max_dim,
    title = title,
    description = description,
    image_obj = image_obj,
  })

  if err then
    dt.print_error(err)
  end

  return result
end

-- ---------------------------------------------------------------------------
-- Dialog for editing suggestions (delegates to lib/dt_vlm_dialog)
-- ---------------------------------------------------------------------------

local function show_edit_dialog(suggested_title, suggested_description, image)
  dvd.show({
    title = suggested_title,
    description = suggested_description,
    image = image,
    on_save = function(title, description, img)
      if img then
        img.title = title
        img.description = description
        dt.print_log(_("Saved title and description to: ") .. img.filename)
      end
      dt.print(_("Title and description saved"))
    end,
    on_cancel = function()
      dt.print_log(_("Dialog cancelled"))
    end,
    on_clear = function()
      dt.print_log(_("Dialog fields cleared"))
    end,
  })
end

local function populate_panel_fields(title, description)
  if not _title_entry_ref and not _desc_text_ref then
    dt.print_log("populate_panel_fields: panel not installed yet, skipping")
    return
  end
  if _title_entry_ref then
    _title_entry_ref.text = title or ""
  end
  if _desc_text_ref then
    _desc_text_ref.text = description or ""
  end
end

local function get_panel_fields()
  local title = ""
  local description = ""
  if _title_entry_ref then
    title = _title_entry_ref.text or ""
  end
  if _desc_text_ref then
    description = _desc_text_ref.text or ""
  end
  return title, description
end

-- ---------------------------------------------------------------------------
-- Main action: Suggest
-- ---------------------------------------------------------------------------

local function action_suggest(event, images)
  if not images or #images == 0 then
    dt.print_error(_("No image selected"))
    return
  end

  local image = images[1]
  local image_path = image.path .. "/" .. image.filename
  image_path = dv.resolve_image_path(image_path, image)

  dt.print_log(_("Suggesting title and description for: ") .. image.filename)

  local current_title = image.title or ""
  local current_desc = image.description or ""

  dt.print(_("Analyzing image with VLM..."))

  local result = call_vlm(image_path, current_title, current_desc, image)

  if result then
    dt.print_log(_("VLM suggestion received"))
    dt.print_log(_("Title: ") .. result.title)
    dt.print_log(_("Description: ") .. result.description)
    dt.print(_("VLM suggestion received. Edit and save."))

    populate_panel_fields(result.title, result.description)
  else
    dt.print_error(_("VLM suggestion failed. Check endpoint and model settings."))
  end
end

-- ---------------------------------------------------------------------------
-- Save metadata from dialog to image
-- ---------------------------------------------------------------------------

local function save_to_group(img, title, description)
  if #img:get_group_members() > 1 then
    for _, member in ipairs(img:get_group_members()) do
      member.title = title
      member.description = description
    end
    dt.print_log(_("Saved to group: ") .. img.filename)
  else
    img.title = title
    img.description = description
    dt.print_log(_("Saved title and description to: ") .. img.filename)
  end
end

local function action_save_from_dialog(event, images)
  local title, description = get_panel_fields()

  if not title and not description then
    dt.print_error(_("No title or description set. Use Suggest first."))
    return
  end

  local img = images and images[1]
  if img then
    save_to_group(img, title, description)
  end

  dt.print(_("Title and description saved"))
end

-- ---------------------------------------------------------------------------
-- Batch processing
-- ---------------------------------------------------------------------------

local _batch_results = nil
local _batch_progress_dialog = nil
local _batch_progress_label = nil
local _batch_progress_bar = nil

local function get_unique_images(images)
  if not images or #images == 0 then
    return {}
  end

  local seen = {}
  local unique = {}

  for _, img in ipairs(images) do
    local key = img.id
    if not seen[key] then
      seen[key] = true
      local members = img:get_group_members()
      if #members > 1 then
        for _, member in ipairs(members) do
          seen[member.id] = true
        end
      end
      unique[#unique + 1] = img
    end
  end

  return unique
end

local function show_batch_progress(total)
  if _batch_progress_dialog then
    _batch_progress_dialog:destroy()
  end

  _batch_progress_label = dt.new_widget("label") {
    label = _("Processing image 1 of ") .. total .. "...",
  }

  _batch_progress_bar = dt.new_widget("box") {
    orientation = "horizontal",
    expand = true,
    dt.new_widget("label") { label = "" },
    dt.new_widget("separator") {},
    dt.new_widget("label") { label = "" },
  }

  local progress_box = dt.new_widget("box") {
    orientation = "vertical",
    _batch_progress_label,
    dt.new_widget("separator") {},
    _batch_progress_bar,
  }

  _batch_progress_dialog = dt.new_widget("dialog") {
    title = _("Batch Processing"),
    progress_box,
  }

  _batch_progress_dialog:show()
end

local function update_batch_progress(current, total, image_name)
  if _batch_progress_label then
    _batch_progress_label.label = _("Processing image ") .. current .. " of " .. total .. ": " .. image_name
  end
end

local function hide_batch_progress()
  if _batch_progress_dialog then
    _batch_progress_dialog:destroy()
    _batch_progress_dialog = nil
  end
  _batch_progress_label = nil
  _batch_progress_bar = nil
end

local function show_batch_results(results)
  if not results or #results == 0 then
    dt.print_error(_("No results to display"))
    return
  end

  local scroll_area = dt.new_widget("box") {
    orientation = "vertical",
  }

  for i, result in ipairs(results) do
    local img_label = dt.new_widget("label") {
      label = result.filename or ("Image " .. i),
    }

    local title_label = dt.new_widget("label") {
      label = _("Title: "),
    }

    local title_text = dt.new_widget("label") {
      label = result.title or _("(error)"),
      selectable = true,
    }

    local title_row = dt.new_widget("box") {
      orientation = "horizontal",
      title_label,
      title_text,
    }

    local desc_label = dt.new_widget("label") {
      label = _("Description: "),
    }

    local desc_text = dt.new_widget("text_view") {
      text = result.description or "",
      editable = true,
    }

    local desc_row = dt.new_widget("box") {
      orientation = "horizontal",
      expand = true,
      fill = true,
      desc_label,
      desc_text,
    }

    local item_box = dt.new_widget("box") {
      orientation = "vertical",
      img_label,
      dt.new_widget("separator") {},
      title_row,
      desc_row,
      dt.new_widget("separator") {},
    }

    scroll_area[#scroll_area + 1] = item_box
  end

  local warning_label = dt.new_widget("label") {
    label = _("Warning: This will overwrite existing title and description metadata for all listed images."),
  }

  local apply_button = dt.new_widget("button") {
    label = _("Apply"),
    tooltip = _("Save all suggestions to image metadata"),
  }

  local cancel_button = dt.new_widget("button") {
    label = _("Cancel"),
    tooltip = _("Close without saving"),
  }

  local button_row = dt.new_widget("box") {
    orientation = "horizontal",
    dt.new_widget("center") {},
    cancel_button,
    apply_button,
  }

  local content_box = dt.new_widget("box") {
    orientation = "vertical",
    warning_label,
    dt.new_widget("separator") {},
    scroll_area,
    dt.new_widget("separator") {},
    button_row,
  }

  local dialog = dt.new_widget("dialog") {
    title = _("Batch Results"),
    content_box,
  }

  dialog:show()

  cancel_button.clicked_callback = function()
    dialog:destroy()
  end

  apply_button.clicked_callback = function()
    local saved = 0
    local failed = 0

    for _, result in ipairs(results) do
      if result.title or result.description then
        local img = result.image
        if img then
          save_to_group(img, result.title or "", result.description or "")
          saved = saved + 1
        end
      else
        failed = failed + 1
      end
    end

    dialog:destroy()
    if failed > 0 then
      dt.print_log(_("Batch save complete: ") .. saved .. _(" saved, ") .. failed .. _(" failed"))
    end
    dt.print(_("Batch save complete: ") .. saved .. _(" saved"))
  end
end

-- ---------------------------------------------------------------------------
-- Module / Panel
-- ---------------------------------------------------------------------------

local module_installed = false
local _module_lib = nil
local _title_entry_ref = nil
local _desc_text_ref = nil

local function install_module()
  if module_installed then return end

  local suggest_button = dt.new_widget("button") {
    label = _("Suggest"),
    tooltip = _("Use VLM to suggest title and description for selected image"),
    clicked_callback = function()
      if not dt.gui.action_images or #dt.gui.action_images == 0 then
        dt.print_error(_("No image selected"))
        return
      end
      local image = dt.gui.action_images[1]
      local image_path = image.path .. "/" .. image.filename
      image_path = dv.resolve_image_path(image_path, image)
      dt.print_log(_("Suggesting title and description for: ") .. image.filename)
      local current_title = image.title or ""
      local current_desc = image.description or ""
      dt.print(_("Analyzing image with VLM..."))
      local result = call_vlm(image_path, current_title, current_desc, image)
      if result then
        dt.print_log(_("VLM suggestion received"))
        dt.print_log(_("Title: ") .. result.title)
        dt.print_log(_("Description: ") .. result.description)
        dt.print(_("VLM suggestion received. Edit and save."))
        if _title_entry_ref then
          _title_entry_ref.text = result.title or ""
        end
        if _desc_text_ref then
          _desc_text_ref.text = result.description or ""
        end
      else
        dt.print_error(_("VLM suggestion failed. Check endpoint and model settings."))
      end
    end,
  }

  local save_button = dt.new_widget("button") {
    label = _("Save"),
    tooltip = _("Save title and description to image metadata"),
    clicked_callback = function()
      local title = ""
      local description = ""
      if _title_entry_ref then
        title = _title_entry_ref.text or ""
      end
      if _desc_text_ref then
        description = _desc_text_ref.text or ""
      end
      if not title and not description then
        dt.print_error(_("No title or description set. Use Suggest first."))
        return
      end
      local img = dt.gui.action_images and dt.gui.action_images[1]
      if img then
        save_to_group(img, title, description)
      end
      dt.print(_("Title and description saved"))
    end,
  }

  local clear_button = dt.new_widget("button") {
    label = _("Clear"),
    tooltip = _("Clear title and description fields in this panel"),
    clicked_callback = function()
      if _title_entry_ref then
        _title_entry_ref.text = ""
      end
      if _desc_text_ref then
        _desc_text_ref.text = ""
      end
      dt.print(_("Title and description fields cleared"))
    end,
  }

  local batch_button = dt.new_widget("button") {
    label = _("Batch"),
    tooltip = _("Suggest title and description for multiple selected images"),
    clicked_callback = function()
      if not dt.gui.action_images or #dt.gui.action_images == 0 then
        dt.print_error(_("No image selected"))
        return
      end

      local unique_images = get_unique_images(dt.gui.action_images)
      if #unique_images == 0 then
        dt.print_error(_("No images to process"))
        return
      end

      local total = #unique_images
      dt.print(_("Processing ") .. total .. _(" images with VLM..."))
      show_batch_progress(total)

      local results = {}
      for i, img in ipairs(unique_images) do
        local image_path = img.path .. "/" .. img.filename
        image_path = dv.resolve_image_path(image_path, img)
        local current_title = img.title or ""
        local current_desc = img.description or ""

        update_batch_progress(i, total, img.filename)

        dt.print_log(_("Processing image ") .. i .. " of " .. total .. ": " .. img.filename)
        local result = call_vlm(image_path, current_title, current_desc, img)

        if result then
          results[#results + 1] = {
            image = img,
            filename = img.filename,
            title = result.title or "",
            description = result.description or "",
          }
          dt.print_log(_("Suggestion ") .. i .. " received: " .. img.filename)
        else
          results[#results + 1] = {
            image = img,
            filename = img.filename,
            title = "",
            description = "",
          }
          dt.print_log(_("Suggestion ") .. i .. " failed: " .. img.filename)
        end
      end

      hide_batch_progress()

      local success_count = 0
      for _, r in ipairs(results) do
        if r.title or r.description then
          success_count = success_count + 1
        end
      end

      dt.print_log(_("Batch complete: ") .. success_count .. _(" succeeded, ") .. (total - success_count) .. _(" failed"))
      dt.print(_("Batch processing complete: ") .. success_count .. _(" succeeded"))

      show_batch_results(results)
    end,
  }

  local title_entry = dt.new_widget("entry") {
    tooltip = _("Title for the image"),
  }

  local title_field = dt.new_widget("box") {
    orientation = "vertical",
    dt.new_widget("label") { label = _("Title:"), halign = "start" },
    title_entry,
  }

  local desc_text = dt.new_widget("text_view") {
    tooltip = _("Description for the image"),
    editable = true,
  }
  desc_text.text = ""

  local desc_field = dt.new_widget("box") {
    orientation = "vertical",
    expand = true,
    dt.new_widget("label") { label = _("Description:"), halign = "start" },
    desc_text,
  }

  local info_label = dt.new_widget("label") {
    label = _("VLM Descriptions"),
  }

  local status_label = dt.new_widget("label") {
    label = _(""),
  }

  local button_box = dt.new_widget("box") {
    orientation = "horizontal",
    suggest_button,
    batch_button,
    save_button,
    clear_button,
  }

  local module_box = dt.new_widget("box") {
    orientation = "vertical",
    info_label,
    dt.new_widget("separator") {},
    title_field,
    desc_field,
    dt.new_widget("separator") {},
    dt.new_widget("separator") {},
    button_box,
    dt.new_widget("separator") {},
    status_label,
  }

  local panel_pos = dt.preferences.read("dt_vlm_descriptions", "panel_position", "enum")

  _module_lib = dt.register_lib(
    "vlm_descriptions",
    _("VLM Descriptions"),
    true,
    false,
    {[dt.gui.views.lighttable] = {panel_pos, 0}},
    module_box
  )

  _title_entry_ref = title_entry
  _desc_text_ref = desc_text

  module_installed = true
end

-- ---------------------------------------------------------------------------
-- Destroy / Cleanup
-- ---------------------------------------------------------------------------

local function destroy()
  if dvd.is_visible() then
    dvd.hide()
  end
  if _module_lib then
    _module_lib.visible = false
  end
end

-- ---------------------------------------------------------------------------
-- Entry Point
-- ---------------------------------------------------------------------------

local script_data = {}

script_data.metadata = {
  name = _("VLM Descriptions"),
  purpose = _("Uses local AI VLM to suggest and edit Title/Description metadata for photos"),
  author = "Khairil Yusof",
  help = "https://github.com/kaerumy/dt_vlm_descriptions"
}

script_data.destroy = destroy
script_data.destroy_method = "hide"

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  dt.register_event(
    "vlm_descriptions_view",
    "view-changed",
    function(event, old_view, new_view)
      if new_view.name == "lighttable" then
        install_module()
      end
    end
  )
end

return script_data

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
