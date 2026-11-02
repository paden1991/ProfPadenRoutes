# ProfPadenRoutes

WoW Forever, Interface 16001. Version 0.20.18-rc1 (release candidate).

Requires [ProfPaden](https://github.com/paden1991/ProfPaden) installed separately.

## Installation

Select Forever in WowUp, choose **Install from URL**, and enter `https://github.com/paden1991/ProfPadenRoutes`. The installable release asset ends in `-forever.zip` and contains one correctly named addon folder. Do not use GitHub's automatic source-code archive as an installable package.

## Current package

ProfPaden retains profession leveling, material/source information, shopping and navigation. BetterFishing and NodeSight are no longer embedded; install NodeSight separately if wanted. It owns its settings and keybindings. Maps use textures already installed in WoW beneath ProfPaden's existing overlays.

GatherMate coordinates are not bundled. For extra mining/herbalism coverage, install and enable the **Forever versions of [GatherMate2](https://www.wowace.com/projects/gathermate2) and [GatherMate2_Data](https://www.wowace.com/projects/gathermate2_data)**, then reload the UI. ProfPaden automatically loads the installed data addon outside combat and imports matching records into session memory. No manual GatherMate import is required. GatherMate2 alone supplies your collected records. Both are declared in OptionalDeps; WoW and WowUp do not automatically install dependencies from this declaration. Missing, disabled or incompatible dependencies leave the built-in atlas available. ProfPaden never changes GatherMate settings, saved databases or import options.

Routes includes the existing compiled 43-map elevation data and numeric terrain hints. Raw research ZIPs, original heightmap images/F32 exports, copied map backgrounds and other addon bundles are excluded. These conversions do not change the underlying source rights; see [attribution](THIRD_PARTY.md).

## Validation

`python tools/build_release.py` verifies every runtime file against the reviewed SHA-256 manifest, packages one addon folder, and checks the TOC and ZIP. Use a matching `v<version>` tag to publish via GitHub Actions; manual dispatch accepts an existing reviewed tag.

Lua regressions cover gathering, guides, source data, tracking, walking and terrain. The Forever simulator loads the package without the removed companions. Its native map texture assets show checkerboards in both ProfPaden and Blizzard's map; real-client map artwork and optional NodeSight coexistence still require live acceptance. This is not a live-game certification.

The external-import replacement passed 117 offline checks and startup in UIForever with all six addons enabled and no Lua errors. Missing GatherMate leaves the existing Copper Ore atlas accessible. The importer was separately checked against every retained position in the locally installed Forever dataset (22,728 records / 39 maps). Actual in-game import timing remains a live acceptance check.
