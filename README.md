# ProfPadenRoutes

WoW Forever, Interface 16001. Version 0.20.17-rc1 (release candidate).

Requires [ProfPaden](https://github.com/paden1991/ProfPaden) installed separately.

## Installation

Select Forever in WowUp, choose **Install from URL**, and enter `https://github.com/paden1991/ProfPadenRoutes`. The installable release asset ends in `-forever.zip` and contains one correctly named addon folder. Do not use GitHub's automatic source-code archive as an installable package.

## Current package

ProfPaden retains profession leveling, material/source information, shopping and navigation. BetterFishing and NodeSight are no longer embedded; install NodeSight separately if wanted. It owns its settings and keybindings. Maps use textures already installed in WoW beneath ProfPaden's existing overlays.

The GatherMate-derived numeric base is retained. Routes includes the existing compiled 43-map elevation data and numeric terrain hints. Raw research ZIPs, original heightmap images/F32 exports, copied map backgrounds and other addon bundles are excluded. These conversions do not change the underlying source rights; see [attribution](THIRD_PARTY.md).

## Validation

`python tools/build_release.py` verifies every runtime file against the reviewed SHA-256 manifest, packages one addon folder, and checks the TOC and ZIP. Use a matching `v<version>` tag to publish via GitHub Actions; manual dispatch accepts an existing reviewed tag.

Lua regressions cover gathering, guides, source data, tracking, walking and terrain. The Forever simulator loads the package without the removed companions. Its native map texture assets show checkerboards in both ProfPaden and Blizzard's map; real-client map artwork and optional NodeSight coexistence still require live acceptance. This is not a live-game certification.
