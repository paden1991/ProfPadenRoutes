# ProfPadenRoutes

Optional farming-route planner for ProfPaden.

**WoW Forever · Interface 16001 · 0.20.16-rc1**

Release candidate / beta. Live-game acceptance is still required.

Requires [ProfPaden](https://github.com/paden1991/ProfPaden), installed as a separate addon.

## WowUp release status

An installable public WowUp release is on hold while redistribution permission for the local-only dependencies is resolved. Full functionality is being preserved; no incomplete or reduced-functionality ZIP is published. The public release builder refuses to package unresolved external files.

## Installation

This is a source repository with **1 local-only dependency files omitted**. A download of this repository alone is not the complete local addon bundle. Use a matching, lawfully obtained complete `ProfPadenRoutes` folder as the dependency input:

```sh
python tools/build_local.py --local-addon "path/to/ProfPadenRoutes"
```

The script copies only manifest-listed dependency bytes, checks their SHA-256 hashes, and combines them with this source in a ZIP under `dist/`. It does not download files, modify the input, or change addon functionality. The resulting local bundle is not automatically cleared for public redistribution.

Open the addon with `/ppwalk`.

## Verification

```sh
python tools/build_local.py --verify-only
```

This checks the published runtime bytes against the reviewed source manifest. For repositories with external files, add `--local-addon` to verify the complete build. It is a source-integrity check, not live-game certification.

## Related addons

- [ProfPaden](https://github.com/paden1991/ProfPaden)
- [ProfPadenClams](https://github.com/paden1991/ProfPadenClams)
- [CounterCast](https://github.com/paden1991/CounterCast)
- [CounterCastProbe](https://github.com/paden1991/CounterCastProbe)
- [RAID](https://github.com/paden1991/RAID)

## Ownership and provenance

Public visibility does not assign a new open-source license. Existing third-party notices and applicable data licenses remain in force. Do not assume that excluded dependencies may be redistributed. No account SavedVariables, personal settings, raw research archives, credentials, or prior packaged releases are included.
