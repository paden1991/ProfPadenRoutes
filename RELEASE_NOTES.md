WoW Forever / Interface 16001 — ProfPadenRoutes 0.20.18-rc1 (release candidate).

GatherMate coordinates are no longer bundled. ProfPaden automatically reads mining and herb records from locally installed, enabled Forever versions of GatherMate2 and GatherMate2_Data. Install both for the community database; GatherMate2 alone supplies your collected records. Reload the UI after installation. No manual data import is required for ProfPaden.

Both addons are optional dependencies, so the existing atlas, leveling, shopping and route planning remain available without them. WoW's OptionalDeps declaration does not automatically download dependencies. Personal harvest tracking uses game object IDs and continues working without GatherMate. Earlier numeric history remains stored and is used when the provider is available.

The integration is read-only and session-only: it does not modify GatherMate databases, settings or import options, and does not save imported coordinates in ProfPaden SavedVariables. Native map rendering and the separate Routes terrain data remain unchanged. BetterFishing and NodeSight remain unbundled.

Install with WowUp: https://github.com/paden1991/ProfPadenRoutes
Manual installs use the attached -forever.zip. ProfPadenRoutes requires ProfPaden separately.

Validation: 13 importer/harvest/source checks passed, including comparison of all 22,728 imported records with the installed Forever dataset. Gathering, guides, source-data, tracking, route, terrain and native-map regression suites also passed. Offline tests do not establish live-game operation. Simulator and real-client limitations are documented in README.md.

Dependencies: https://www.wowace.com/projects/gathermate2 and https://www.wowace.com/projects/gathermate2_data — choose the Forever-compatible packages.
