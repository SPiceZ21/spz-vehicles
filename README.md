# spz-vehicles

> Vehicle registry, classes, race spawns, upgrades and saved customisation.

![version](https://img.shields.io/badge/version-1.6.1-ff6200) ![SPiceZ-Core](https://img.shields.io/badge/SPiceZ--Core-beta-18181b)

## Overview

Knows every car the server offers and its class, spawns race and freeroam vehicles server-side, applies performance upgrades and each player's saved customisation. Race cars get a random chameleon paint.

## Features

- Car registry and class classification (incl. add-on cars)
- Server-side race spawns
- Saved customisation per player and car
- Vanity plates on every car

## Requirements

| Resource | Type |
|---|---|
| `ox_lib` | third-party |
| `spz-core` | SPiceZ module |
| `spz-identity` | SPiceZ module |
| `oxmysql` | third-party |

## Installation

Included in the [txAdmin recipe](https://github.com/SPiceZ21/spz-txrecipe). Manual install:

1. Download `spz-vehicles` from GitHub (latest release, or the repository) into your `resources` folder.
2. Add to `server.cfg`, after its requirements:

```cfg
ensure spz-vehicles
```

## Configuration

- `config.lua`

See the file for every option.

## Commands

| Command | Who | Description |
|---|---|---|
| `/resetcustom` | player | Reset it |
| `/savecustom` | player | Save the current car's customisation |
| `/reclassify` | admin | Recompute car classes |
| `/spzaddons` | admin | List add-on cars |
| `/spzaddonscan` | admin | Scan for add-on cars |
| `/vehcheck` | admin | Inspect the car you are in |

## Exports

| Export | Side |
|---|---|
| `DespawnVehicle` | server |
| `GetAddonRaceClasses` | server |
| `GetAllPollOptions` | server |
| `GetClassMeta` | server / shared |
| `GetClassification` | server |
| `GetPlayerVehicle` | server |
| `GetPollPool` | server |
| `GetRaceClasses` | server |
| `GetVehicleData` | server |
| `GetVehicleRegistry` | server |
| `IsRegistered` | server |
| `LoadCustomization` | server |
| `SpawnRaceVehicle` | server |
| `SpawnVehicle` | server |
| `UnlockRaceVehicle` | server |

```lua
exports["spz-vehicles"]:DespawnVehicle(...)
```

---

Part of **SPiceZ-Core** — [documentation](https://github.com/SPiceZ21/Docs) · [all modules](https://github.com/SPiceZ21/Docs/blob/main/modules/README.md)
