# spz-vehicles

> Vehicle registry, classes, spawning, upgrades, customization · `v2.0.0`

## Overview

`spz-vehicles` is the authority on what a player may drive. It holds the master vehicle
table and class definitions, spawns cars for free roam and for race grids, validates and
persists upgrades, and stores per-vehicle cosmetic setups. It also builds the vehicle pool
that `spz-poll` votes on.

## Structure

| Side | File | Purpose |
|---|---|---|
| Shared | `shared/classes.lua` | Class definitions and metadata |
| Shared | `shared/upgrades.lua` | Upgrade tiers and slots |
| Shared | `shared/events.lua` | Event name constants |
| Server | `config.lua` | Resource configuration |
| Server | `data/vehicles.lua` | Master vehicle table |
| Server | `server/main.lua` | Entry point, export registration |
| Server | `server/registry.lua` | Registry and class lookup |
| Server | `server/spawn.lua` | Spawn authority |
| Server | `server/upgrades.lua` | Upgrade persistence and validation |
| Server | `server/customization.lua` | Cosmetic persistence |
| Server | `server/freeroam_spawn.lua` | Free-roam spawning |
| Server | `server/race_spawn.lua` | Race grid spawning |
| Server | `server/poll_pool.lua` | Vote pool generation |
| Client | `client/main.lua` | Vehicle state tracking |
| Client | `client/spawn.lua` | Spawn flow |
| Client | `client/despawn.lua` | Despawn and cleanup |
| Client | `client/upgrades.lua` | Apply upgrades |
| Client | `client/customization.lua` | Apply cosmetics |
| Client | `client/commands.lua` | Player and debug commands |

## Exports

| Group | Exports |
|---|---|
| Registry | `GetVehicleRegistry` · `GetVehicleData` · `IsRegistered` · `GetClassMeta` · `GetClassVehicles` · `GetRaceClasses` |
| Spawning | `SpawnVehicle` · `FreeroamSpawn` · `SpawnRaceVehicle` · `DespawnVehicle` · `GetPlayerVehicle` · `GetFreeroamVehicles` |
| Poll pool | `GetPollPool` · `GetAllPollOptions` |
| Customization | `LoadCustomization` · `ResetCustomization` |
| Unlocks | `UnlockRaceVehicle` |

## Commands

`/savecustom` · `/resetcustom`

## Dependencies

`ox_lib` · `spz-core` · `spz-identity` · `oxmysql`

---

Part of [SPiceZ-Core](../README.md) · GPL-3.0
