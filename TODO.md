# TODO - dt_vlm_descriptions

## Description field should be multiline

Currently using `dt.new_widget("entry")` for the description field. Replace with `dt.new_widget("textview")` to support multi-line descriptions.

## Move plugin dialog via drag and drop

The panel is currently hardcoded to `DT_UI_CONTAINER_PANEL_PANEL_RIGHT_BOTTOM`. Allow users to reposition the panel via drag and drop or a preference setting.

## Max tokens preference default

`vlm_max_tokens` defaults to 300 and resets on each darktable load. Change default to 4096 and ensure the value persists correctly across sessions.
