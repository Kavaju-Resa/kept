application = defines["application"]
background_art = defines["background"]
volume_icon = defines["volume_icon"]

format = "UDZO"
filesystem = "HFS+"
compression_level = 9
size = None

files = [(application, "Kept.app")]
symlinks = {"Applications": "/Applications"}

icon = volume_icon
background = background_art
window_rect = ((120, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100.0
scroll_position = (0.0, 0.0)
show_icon_preview = True
show_item_info = False
label_pos = "bottom"
text_size = 14.0
icon_size = 128.0
icon_locations = {
    "Kept.app": (180, 200),
    "Applications": (480, 200),
}
