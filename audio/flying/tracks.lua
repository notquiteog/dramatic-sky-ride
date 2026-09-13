-- Flying Music catalog for Dramatic Sky Ride.
--
-- Audio files should be OGG Vorbis assets. For polished looping, follow the
-- convention used by Gen1Recomp music replacement mods: one intro file played
-- once, followed by a dedicated loop file repeated by the engine.
--
-- Example with a seamless intro + loop pair:
-- return {
--   {
--     key = "emerald_surf",
--     label = "Emerald Surf",
--     intro = "assets/flying/emerald_surf_intro.ogg",
--     loop = "assets/flying/emerald_surf_loop.ogg",
--   },
-- }
--
-- A single already-seamless file is also supported:
--   {
--     key = "custom_skies",
--     label = "Custom Skies",
--     file = "assets/flying/custom_skies.ogg",
--   }
--
-- Keep copyrighted commercial tracks out of public release archives unless
-- redistribution is authorized. The catalog can still be used for local builds.

return {
}
