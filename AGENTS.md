# AGENTS.md - darktable VLM Descriptions Plugin

## Project Overview

This is a **darktable Lua plugin** that uses a local AI Vision-Language Model (VLM) via a local OpenAI-compatible endpoint to suggest **Title** and **Description** metadata for photos. The user can edit the suggestions before saving them to the image metadata.

## Functionality

- **Auto-suggest**: Sends the selected image to a local VLM model and receives suggested title and description
- **Edit**: User can modify the suggested title and description in a dialog
- **Save**: Saves the title and description to the image's metadata (XMP sidecar / database)
- **Clear**: Clears existing title and description metadata

## Darktable Lua Script Conventions

### Standard Header
Every script must start with the GPL2+ license header and a comment block with metadata:

```lua
--[[
    This file is part of darktable,
    copyright (c) <year> <author>

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
    SCRIPT_NAME
    Brief description of what the script does.

    USAGE
    * require this file from your main lua config file:
        require "<path/to/script>"
]]
```

### Required Structure
Every script must return a `script_data` table with:

```lua
local script_data = {}

script_data.metadata = {
  name = "Script Name",
  purpose = "Brief description",
  author = "Author Name",
  help = "Documentation URL"
}

script_data.destroy = function() end  -- cleanup routine

return script_data
```

### Required Imports
```lua
local dt = require "darktable"
local du = require "lib/dtutils"
```

### API Version Check
Always check the minimum API version at the top of the script:
```lua
du.check_min_api_version("2.0.0", "script_name")
```

### Translation Support
```lua
local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end
```

## Key APIs to Use

### Image Metadata
- `dt.core.metadata.get(image, key)` - Get metadata value
- `dt.core.metadata.set(image, key, value)` - Set metadata value
- For title/description, use keys like `Title` and `Description`

### GUI Elements
- `dt.gui.widgets` - Available widget types (buttons, labels, text views, etc.)
- `dt.new_action()` - Register actions for menu/toolbar integration
- `dt.guiActions` - Trigger GUI actions programmatically

### HTTP / Network Requests
- Use Lua's `socket` library or `os.execute()` with `curl` to call the OpenAI-compatible endpoint
- The endpoint is local (e.g., `http://localhost:PORT/v1/chat/completions`)

### Image Operations
- `dt.lib.selected_images()` - Get currently selected images in lighttable
- `dt.image.new()` - Create image object from file path

### Dialogs
- Use `dt.gui.widgets.frame` and `dt.gui.widgets.box` to build custom dialogs
- `dt.gui.gui` for access to the main GUI

## VLM API Integration

The script calls a local OpenAI-compatible endpoint. Expected request format:

```lua
-- Example request structure for VLM
local request = {
  model = "model-name",
  messages = {
    {
      role = "user",
      content = {
        { type = "text", text = prompt },
        { type = "image_url", image_url = { url = "data:image/jpeg;base64," .. encoded_image } }
      }
    }
  },
  max_tokens = 300,
  temperature = 0.3
}
```

The VLM should return JSON with title and description fields.

## File Structure

```
dt_vlm_descriptions/
  lua/
    dt_vlm_descriptions.lua    # Main plugin script
```

## Installation

1. Clone or copy the script to your darktable lua directory:
   - Linux/macOS: `~/.config/darktable/lua/`
   - Windows: `%LOCALAPPDATA%\darktable\lua\`
2. Enable in `luarc`:
   ```
   require "dt_vlm_descriptions"
   ```

## Debugging

Run darktable with Lua debugging:
```bash
darktable -d lua
```

## Git Commit Conventions

- Author: check current git user via `git config user.name`
- Follow [Conventional Commits](https://github.com/conventional-commits/conventionalcommits.org/blob/master/content/v1.0.0/index.md) with multi-paragraph bodies (summary, blank line, explanation, blank line, attribution)
- If AI-assisted, add the attribution line at the end using the format `Assisted-by: <AGENT_NAME>:<MODEL_VERSION>` (see [Linux Kernel AI Attribution](https://github.com/torvalds/linux/blob/master/Documentation/process/coding-assistants.rst))

## References

- [Lua Scripts Manual](https://docs.darktable.org/lua/stable/lua.scripts.manual/)
- [Lua Scripts API Manual](https://docs.darktable.org/lua/stable/lua.scripts.api.manual/)
- [Lua API Manual](https://docs.darktable.org/lua/stable/lua.api.manual/)
- [darktable Lua Documentation](https://darktable.org.github.io/dtdocs/lua/)
- [Example Scripts](https://github.com/darktable-org/lua-scripts/tree/master/examples)
