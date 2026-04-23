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

## RAW file support

- Current `resize_image` uses ImageMagick `convert` which doesn't support RAW files
- Need to detect RAW file extensions (NEF, CR2, ARW, DNG, etc.) and use an appropriate converter (e.g., `dcraw`, `libraw`, or darktable's own export API)
- Alternatively, use darktable's `dt.image.export()` or `dt.image.processed()` to get a processed JPEG from the engine for RAW files

## Grouped photos (RAW + JPEG) support

- Darktable can group RAW and JPEG photos together (grouped photos feature)
- Need to check if the plugin works correctly when grouped photos are enabled
- May need to detect grouped images and prefer the RAW file for VLM analysis, or handle the group leader path
- Test with grouped images to ensure correct image path resolution

## Datetime metadata in VLM prompts

- Check image for datetime metadata (EXIF DateTimeOriginal, DateTimeDigitized, etc.)
- If available, include the capture date/time in the VLM prompt (e.g., "This photo was taken on March 15, 2024")
- Helps the VLM provide more context-aware descriptions (season, time of day, etc.)

## Filmroll metadata in VLM prompts

- Check if the image's filmroll has associated text/metadata
- If filmroll metadata exists, include it as additional context in the VLM prompt
- Could provide contextual clues like trip names, event names, or folder descriptions
