# Agent Notes

Main scene is `res://scenes/iso_world.tscn` (2.5D isometric multi-zone world).

Autoloads: `RoomStateManager` (Summer set_synced/get_synced + ENet fallback), `ZoneCatalog`, `CCAssetFetcher`.

Zones: 1 Phoneme Village (lv 1-5, graphemes), 2 Syllable Woods (lv 6-12, CVC/digraphs), 3 Orthography Citadel (lv 13+, affixes/irregulars).

Monster combat modes: speed blending, audio shielding, kinesthetic forging. Combat is assessment; fuse/stream loops, never punishes.

Do not extend `SummerGame` unless the class exists in the running engine. RoomStateManager already binds to `Summer` / `set_synced` when present.
