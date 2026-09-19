# DensGuildMap — Forever beta prototype

An independent guild location addon inspired by GuildMap. No GuildMap source or artwork is included.

*This project was vibe coded with codex, I am a software engineer and reviewed the commits created myself thoroughly*

## Install and share

Extract `dist/DensGuildMap-0.1.0-beta.zip` into the Forever beta client's `Interface/AddOns` folder. The resulting path must be `Interface/AddOns/DensGuildMap/DensGuildMap.toc`. Restart the client and enable the addon. Each participating guildmate needs this addon; it does not communicate with GuildMap.

Your installed beta was 1.60.1.69913 when this prototype was built. Interface 16001 is provisional until confirmed with `/dgm status` in game. This is not yet a verified Forever-compatible release.

## Features

- Settings > AddOns > DensGuildMap provides location-sharing and map-dot checkboxes. Changes save automatically; `/dgm settings` opens the page.
- Class-colored dots on the world map and minimap with name and level tooltips.
- Guild-only messages every five seconds; accepts locations only from online guild roster members.
- Removes locations after 45 seconds without an update.
- `/dgm off` stops sharing and asks recipients to remove your dot; `/dgm on` resumes.
- `/dgm hide` and `/dgm show` control your map dots independently of sharing.
- `/dgm status` reports the client build, API availability, peer count and latest caught error.

Sharing starts enabled. Only current map coordinates, class and level are transmitted; positions are held in memory, not saved to disk. No transmissions are attempted in combat. Combat, unavailable positions, disconnects or client restrictions can therefore cause dots to expire. A dot does not imply the same layer or phase. Health alerts, layer detection and advanced filters are not implemented.

## Beta acceptance test

1. Install on two characters in the same guild. Enable Lua errors with `/console scriptErrors 1`, then restart the client.
2. Run `/dgm status` on both. Confirm the interface number and no Lua errors.
3. Stand outdoors in the same zone. Within 10 seconds each should see the other on the world map and, nearby, the minimap.
4. Move, change zones, zoom the maps and rotate the minimap. Confirm dots follow correctly.
5. Run `/dgm off`: the other player's dot for you should disappear. Turn sharing on again.
6. Hide/show pins, enter combat, log out, and leave the guild. Confirm stale dots expire within 45–50 seconds and guild changes clear old data.

The bundled mapping library has not been validated against Forever's new maps or API restrictions. The local tests validate our message parser and Lua syntax, not the game engine or library compatibility. Send any Lua error and `/dgm status` output to the addon maintainer before distributing as a stable release.

## Libraries

HereBeDragons 2.0 and Pins 2.0: https://github.com/Nevcairiel/HereBeDragons (upstream TOC declares BSD). LibStub and CallbackHandler-1.0: bundled from the installed Titan/Ace libraries; original headers retained. These libraries remain under their upstream licenses.
