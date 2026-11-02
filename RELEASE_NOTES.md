WoW Forever / Interface 16001 — ProfPadenRoutes 0.20.17-rc1 (release candidate).

- BetterFishing and NodeSight are no longer bundled or loaded by ProfPaden. Install NodeSight separately if wanted; its settings and bindings belong to that addon.
- Gathering map backgrounds now use textures already installed in WoW, beneath the existing overlays.
- GatherMate-derived coordinates and resource mappings remain intact. Routes retains all 43 compiled height grids and terrain scoring.
- Packages contain runtime files and attribution only: no raw research archives, source heightmap PNG/F32 files, copied background maps or other addon bundles.

Install in WowUp using https://github.com/paden1991/ProfPadenRoutes (without .git). Choose the attached -forever.zip for manual installation; release.json identifies the Forever flavor.

Validation: relevant Lua suites passed, including 19 terrain checks. Simulator build 1.60.1.70450 loads both addons without the removed companions and reports no Lua errors. Native map metadata is available for 40 of 41 referenced maps there; map 233 is unavailable. Its textures show checkerboards in both ProfPaden and Blizzard's own world map. Real-client map artwork and separately installed NodeSight coexistence remain acceptance checks. This is not a stable-release certification.

Compiled data retains its source attribution and underlying terms; converting data does not create a new permission grant. See THIRD_PARTY.md. ProfPadenRoutes requires ProfPaden installed separately.
