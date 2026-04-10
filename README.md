    <img src="https://github.com/SPiceZ21/spz-core-media-kit/raw/main/Banner/Banner%232.png" alt="SPiceZ-Core Banner" width="100%">

# spz-vehicles

A comprehensive vehicle management and spawning system for the **SPiceZ-Core** racing framework. This resource handles vehicle registration, automated performance tuning, persistent visual customization, and specialized spawning for racing and freeroam.

## Features

- **Automated Performance**: Every vehicle spawns with maximum performance mods (Engine, Brakes, Transmission, etc.) by default. No exceptions.
- **Visual Persistence**: Save and restore your vehicle's aesthetic look (paint, neon, body mods) using `/savecustom`.
- **License Gating**: Freeroam spawning is restricted by player license tiers (C, B, A, S).
- **Race Grid Ready**: Specialized `SpawnRaceVehicle` for grid placement with locked doors and instant engine start.
- **Weighted Randomness**: Integrated `GetPollPool` for balanced, weighted vehicle selection in race voting.
- **Robust Cleanup**: Automatic entity despawning on state changes (Spectating/Queued) or player disconnect.

## Requirements

- `spz-lib` (Shared utilities)
- `spz-identity` (Profile and License management)
- `oxmysql` (Database persistence)

## Installation

1. Run the `vehicles.sql` file in your database.
2. Ensure the resource is named `spz-vehicles`.
3. Add `ensure spz-vehicles` to your server configuration.

## Command Reference

- `/savecustom`: Captures and saves the current vehicle's visual setup.
- `/resetcustom [model]`: Resets the saved look for a specific model to its factory defaults.

## Export Overview

### Registry
- `GetVehicleData(model)`: Get stats for a specific vehicle.
- `GetClassVehicles(classId, filters)`: Get vehicles filtered by class and eligibility.
- `IsRegistered(model)`: Check if a model exists in the registry.

### Spawning
- `FreeroamSpawn(source, model)`: Validate and spawn a freeroam vehicle.
- `SpawnRaceVehicle(source, model, coords, heading)`: Place a vehicle on a race grid.
- `UnlockRaceVehicle(source)`: Unlock a race-locked vehicle.
- `DespawnVehicle(source)`: Safely remove a player's active vehicle.

### Polls
- `GetPollPool(classId, count)`: Get N weighted-random vehicles for a poll.
- `GetAllPollOptions(classId)`: Get all race-eligible vehicles for a class.
