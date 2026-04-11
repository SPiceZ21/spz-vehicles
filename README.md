<div align="center">

<img src="https://github.com/SPiceZ21/spz-core-media-kit/raw/main/Banner/Banner%232.png" alt="SPiceZ-Core Banner" width="100%"/>

<br/>

# spz-vehicles

### Vehicle Registry, Spawning & Class Management

*Every car that enters a race or freeroam goes through here. The poll system reads from here. The grid spawner calls here. No vehicle exists outside this module's knowledge.*

<br/>

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-orange.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=flat-square)](https://fivem.net)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=flat-square&logo=lua)](https://lua.org)
[![Status](https://img.shields.io/badge/Status-In%20Development-green?style=flat-square)]()

</div>

---

## Overview

`spz-vehicles` manages the complete vehicle lifecycle for the SPiceZ ecosystem — from the registry that defines every raceable car, to spawning on the start grid, to cleanup on disconnect or state change.

It enforces license-tier gating for freeroam spawns, provides the poll system with weighted-random vehicle pools, and handles the specialized race spawn flow that places cars on the grid with locked doors, instant engine start, and no-collision preparation.

All stat changes are server-validated — the client never applies modifications without a server acknowledgment.

---

## Features

- **Vehicle Class Registry** — Every registerable model defined in `config/vehicles.lua` with class, label, top speed, and handling stats
- **Automated Performance** — All race-spawned vehicles receive maximum performance mods (engine, brakes, transmission, tires) by default — no manual tuning required
- **License Gating** — Freeroam spawning restricted by the player's current license tier (C/B/A/S)
- **Race Grid Spawn** — Specialized `SpawnRaceVehicle` export places the car exactly on the grid with locked doors and instant engine start
- **Visual Persistence** — Save and restore a vehicle's aesthetic (paint, neon, body mods) with `/savecustom`
- **Weighted Poll Pool** — `GetPollPool` provides balanced, weighted random vehicle selection for race voting
- **Robust Cleanup** — Automatic entity despawn on state changes (SPECTATING, QUEUED) and player disconnect

---

## Dependencies

| Resource | Version | Role |
|---|---|---|
| `spz-lib` | 1.0.0+ | Shared utilities, logger |
| `spz-core` | 1.0.0+ | Session and state management |
| `spz-identity` | 1.0.0+ | License tier validation |
| `oxmysql` | 2.0.0+ | Visual customization persistence |

---

## Installation

1. Run `vehicles.sql` in your database.
2. Ensure the resource folder is named `spz-vehicles`.
3. Add to `server.cfg`:

```cfg
ensure spz-lib
ensure spz-core
ensure spz-identity
ensure spz-vehicles
```

---

## Vehicle Registry

Vehicles are defined in `config/vehicles.lua`:

```lua
SPZ.Vehicles = {
  ["sultanrs"] = { class = 1, label = "Sultan RS",   topspeed = 180, handling = 85 },
  ["zentorno"] = { class = 3, label = "Zentorno",    topspeed = 320, handling = 78 },
  ["elegy2"]   = { class = 1, label = "Elegy RH8",   topspeed = 190, handling = 88 },
  -- ...
}
```

| Field | Description |
|---|---|
| `class` | License class required: `0`=C `1`=B `2`=A `3`=S |
| `label` | Display name shown in menus and HUD |
| `topspeed` | Reference top speed (km/h) for stat sheets |
| `handling` | Handling score 0–100 for comparative display |

---

## Exports Reference

### Registry

```lua
exports["spz-vehicles"]:GetVehicleData(model)             -- stat sheet for a model
exports["spz-vehicles"]:GetClassVehicles(classId, filters) -- all vehicles in class
exports["spz-vehicles"]:IsRegistered(model)                -- bool
```

### Spawning

```lua
-- Freeroam spawn — validates license tier before spawning
exports["spz-vehicles"]:FreeroamSpawn(source, model)

-- Race grid spawn — grid coords + locked doors + instant engine start
exports["spz-vehicles"]:SpawnRaceVehicle(source, model, coords, heading)

-- Unlock race-locked doors after countdown GO
exports["spz-vehicles"]:UnlockRaceVehicle(source)

-- Despawn and clean up the player's active vehicle entity
exports["spz-vehicles"]:DespawnVehicle(source)

-- Get the current vehicle entity handle for a player
exports["spz-vehicles"]:GetPlayerVehicle(source)
```

### Poll Pool

```lua
-- Returns N weighted-random vehicles for a race poll
exports["spz-vehicles"]:GetPollPool(classId, count)

-- Returns all race-eligible vehicles for a class
exports["spz-vehicles"]:GetAllPollOptions(classId)
```

---

## Commands

| Command | Description |
|---|---|
| `/savecustom` | Capture and persist the current vehicle's visual setup |
| `/resetcustom [model]` | Reset saved visuals for a model to factory defaults |

---

## Events

| Event | Direction | When |
|---|---|---|
| `SPZ:raceVehicleSpawned` | Client → Server | Fired after race vehicle confirmed spawned — `spz-races` awaits this |
| `SPZ:vehicleDespawned` | Server | Fired after any vehicle entity is cleaned up |

---

<div align="center">

*Part of the [SPiceZ-Core](https://github.com/SPiceZ-Core) ecosystem*

**[Docs](https://github.com/SPiceZ-Core/spz-docs) · [Discord](https://discord.gg/) · [Issues](https://github.com/SPiceZ-Core/spz-vehicles/issues)**

</div>
