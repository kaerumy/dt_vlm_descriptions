# TODO - dt_vlm_descriptions

## Description field should be multiline ~~DONE~~

Replaced `dt.new_widget("entry")` with `dt.new_widget("text_view")` (editable) in both the panel (`dt_vlm_descriptions.lua:386`) and dialog (`dt_vlm_dialog.lua:83`). Description layout changed from horizontal box to vertical box to accommodate multi-line text.

## Move plugin dialog via drag and drop ~~DONE~~

Added `panel_position` enum preference with 4 options: Right Center, Right Bottom, Left Center, Left Bottom. Panel position is read from preference at registration time. (No drag-and-drop API available in darktable Lua.)

## Max tokens preference default ~~DONE~~

Default is 4096 with range 50-8192. Value persists correctly via `dt.preferences.register`/`dt.preferences.read` with no overwriting `preferences.write` calls.

## Geolocation-aware VLM prompts

- Check image for latitude and longitude metadata from the image file
- If both latitude and longitude are available, use them to lookup a place name from the OSM Nominatim API
- Once geolocation and Nominatim lookup are working, include the location name in the VLM prompt

## RAW file support ~~DONE~~

- Added `RAW_EXTENSIONS` table with 20+ RAW formats (NEF, CR2, ARW, DNG, ORF, RAF, PEF, etc.)
- Modified `resize_image()` to detect RAW files via `image_obj.is_raw` or file extension
- For RAW files, uses `dt.new_format("jpeg")` with `write_image()` to export processed JPEG via darktable engine
- Non-RAW files continue using ImageMagick `convert` for backward compatibility
- Updated call chain (`call_vlm` -> `build_vlm_request` -> `encode_image_resized` -> `resize_image`) to pass `image_obj` through

## Grouped photos (RAW + JPEG) support ~~DONE~~

- Added `resolve_image_path(image_path, image_obj)` in `lib/dt_vlm.lua`
- Detects grouped images via `#image_obj:get_group_members() > 1`
- When grouped, iterates through members and prefers the non-RAW (JPEG) file for VLM analysis
- Falls back to original path if no JPEG found in group or image is not grouped
- Applied in both `action_suggest` and panel button callback
- Added `save_to_group(img, title, description)` helper function
- Save button (panel and action) now saves to all group members when image is in a group

## Datetime metadata in VLM prompts

- Check image for datetime metadata (EXIF DateTimeOriginal, DateTimeDigitized, etc.)
- If available, include the capture date/time in the VLM prompt (e.g., "This photo was taken on March 15, 2024")
- Helps the VLM provide more context-aware descriptions (season, time of day, etc.)

## Filmroll metadata in VLM prompts

- Check if the image's filmroll has associated text/metadata
- If filmroll metadata exists, include it as additional context in the VLM prompt
- Could provide contextual clues like trip names, event names, or folder descriptions
