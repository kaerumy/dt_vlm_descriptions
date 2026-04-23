# dt_vlm_descriptions

A [darktable](https://darktable.org) Lua plugin that uses a local Vision-Language Model (VLM) to suggest **Title** and **Description** metadata for photos.

This is a proof-of-concept plugin that demonstrates how to integrate a
local VLM (e.g., Ollama, LM Studio, vLLM) with darktable's Lua API to
generate AI-powered metadata suggestions based on image content and
context film roll, geo-locatationd data and time of capture.

The plugin sends selected images to the VLM via an
OpenAI-compatible API endpoint, receives title and description
suggestions in JSON format, and allows users to review, edit, and save
the metadata back to the image's XMP sidecar or database.

It also serves as a test case on capabilities of local AI models and
[OpenCode](https://opencode.ai) to assist in writing plugins like this. 

Current development testing is done with Qwen 3.6 32B A3B Q6 K_XL on llama.cpp,
AMD Ryzen 9 5950X, 64GB RAM, Radeon RX 9700 XT 16GB VRAM and ROCm 7.2.2
on Ubuntu Linux. 


## Features

- **AI-powered suggestions** — Sends selected images to a local VLM via an OpenAI-compatible API endpoint and receives suggested title and description in JSON format
- **Editable output** — Review and edit suggestions before saving to image metadata
- **Geolocation context** — Automatically looks up place names from image GPS coordinates using the OSM Nominatim API and includes location in the prompt for more accurate descriptions
- **Datetime context** — Extracts EXIF `DateTimeOriginal` and formats it as "Month Day, Year" to help the VLM understand season and time-of-day context
- **Film roll context** — Parses film roll/folder names, strips date patterns, and extracts meaningful place/job/subject parts (e.g., `"2025-10-11-KTM Batang Kali - Serendah Tunnel"` → `"KTM Batang Kali, Serendah Tunnel"`)
- **RAW file support** — Handles 20+ RAW formats (NEF, CR2, ARW, DNG, ORF, RAF, PEF, etc.) by exporting through darktable's engine before sending to the VLM
- **Grouped photo support** — Detects RAW+JPEG groups and prefers the JPEG file for analysis; saves metadata to all group members
- **Configurable** — Adjustable model, temperature, max tokens, max image dimension, and panel position via darktable preferences

## Requirements

- **darktable** >= 7.0.0 (Lua API)
- **Lua** 5.2+ (bundled with darktable)
- **curl** — for HTTP requests to the VLM endpoint and Nominatim API
- **ImageMagick** (`convert` command) — for resizing non-RAW images before sending to the VLM
- A local VLM endpoint compatible with the OpenAI API (e.g., [Ollama](https://ollama.com), [LM Studio](https://lmstudio.ai), [vLLM](https://docs.vllm.ai/), etc.)

## Installation

1. **Clone or copy the plugin** into your darktable Lua directory:

   ```bash
   mkdir -p ~/.config/darktable/lua/dt_vlm_descriptions
   git clone https://github.com/kaerumy/dt_vlm_descriptions.git ~/.config/darktable/lua/dt_vlm_descriptions
   ```

2. **Enable the plugin** by adding the following line to your `luarc` configuration file:

   ```lua
   require "dt_vlm_descriptions"
   ```

   The `luarc` file is typically located at `~/.config/darktable/luarc`.

3. **Configure your VLM endpoint** via darktable's preferences UI (Edit > Preferences > Plugins > dt_vlm_descriptions) or by editing `luarc` directly:

   ```lua
   -- Set your VLM API endpoint
   dt.preferences.write("dt_vlm_descriptions", "vlm_endpoint", "string", "http://localhost:8000/v1/chat/completions")
   -- Set the model name
   dt.preferences.write("dt_vlm_descriptions", "vlm_model", "string", "your-model-name")
   ```

## Usage

1. Open darktable and navigate to **Lighttable** view
2. Select one or more images
3. A **"VLM Descriptions"** panel appears with **Suggest**, **Save**, and **Clear** buttons
4. Click **Suggest** to generate AI-powered title and description suggestions
5. Edit the suggestions in the panel or via the dialog
6. Click **Save** to store the title and description in the image metadata (XMP sidecar / database)
7. Click **Clear** to remove existing title and description metadata

## Preferences

| Preference | Type | Default | Description |
|---|---|---|---|
| `vlm_endpoint` | string | `http://localhost:8000/v1/chat/completions` | OpenAI-compatible VLM API endpoint URL |
| `vlm_model` | string | (empty) | Model name to use for suggestions |
| `vlm_max_tokens` | integer | 4096 | Maximum tokens in response (range: 50–8192) |
| `vlm_temperature` | float | 0.3 | Creativity level (range: 0.0–1.0) |
| `vlm_max_dim` | integer | 1024 | Maximum image dimension in pixels (range: 256–4096) |
| `panel_position` | enum | Right Center | Panel location in lighttable view |

## License

This project is licensed under the GNU General Public License v2.0 or later. See the [darktable license](http://www.gnu.org/licenses/) for details.
