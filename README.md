# Upstream sources

Boblo.lua is an unmodified copy of https://github.com/bobloscript/scripts/blob/main/opensource_egg

Oxide.lua is an unmodified copy of https://github.com/LSSOPS/OpenSource/blob/main/OxideHub_Steal_An_Egg.lua

Author credits in the original files are preserved. These are copies, not a combined rewrite. Both depend on external UI libraries and executor capabilities. Runtime compatibility has not been verified.

The original copies above are retained for reference.

BobloIntegrated.lua and OxideIntegrated.lua preserve the upstream feature implementations but replace their external UI-library initialization with PanelControls.lua. PlayerMarkers.client.lua mounts both sets of controls in the same panel as the existing player markers and map. Upstream author credits remain in the files.

PanelControls.lua supplies tabs, sections, toggle state, callbacks, dropdowns, multi-select lists, numeric inputs for sliders, keybindings, status rows, dialogs, notifications and configuration persistence. Upstream theme calls use this panel's styling. No original UI library is downloaded by the integrated versions.

Compilation and isolated UI state/config/cleanup checks pass. Actual game-module access and executor compatibility remain unverified.
