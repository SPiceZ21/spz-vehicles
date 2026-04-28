<div align="center">

<img src="https://github.com/SPiceZ21/spz-core-media-kit/raw/main/Banner/Banner%232.png" alt="SPiceZ-Core Banner" width="100%"/>

<br/>

# spz-vehicles
> Vehicle registry, spawn, upgrades, customization · `v1.3.2`

## Scripts

| Side   | File                       | Purpose                                          |
| ------ | -------------------------- | ------------------------------------------------ |
| Shared | `shared/classes.lua`       | Vehicle class definitions and constants          |
| Shared | `upgrades.lua`             | Shared upgrade tier and slot definitions         |
| Shared | `events.lua`               | Shared event name constants                      |
| Server | `@oxmysql`                 | oxmysql database library import                  |
| Server | `config.lua`               | Vehicle resource configuration                   |
| Server | `data/vehicles.lua`        | Master vehicle data table                        |
| Server | `server/main.lua`          | Entry point, event and export registration       |
| Server | `registry.lua`             | Vehicle registry and class lookup                |
| Server | `spawn.lua`                | Server-side vehicle spawn authority              |
| Server | `upgrades.lua`             | Upgrade persistence and validation               |
| Server | `customization.lua`        | Livery and cosmetic customization persistence    |
| Server | `freeroam_spawn.lua`       | Free-roam vehicle spawn handling                 |
| Server | `race_spawn.lua`           | Race vehicle spawn and grid placement            |
| Server | `poll_pool.lua`            | Generate vehicle pool for race vote polls        |
| Client | `client/main.lua`          | Client entry point, vehicle state management     |
| Client | `spawn.lua`                | Client-side vehicle spawn flow                   |
| Client | `despawn.lua`              | Vehicle despawn and cleanup                      |
| Client | `upgrades.lua`             | Apply upgrades to spawned vehicle                |
| Client | `customization.lua`        | Apply livery and cosmetic customization          |
| Client | `commands.lua`             | Debug and admin vehicle commands                 |

## Dependencies
- spz-lib
- spz-core
- spz-identity
- oxmysql

## CI
Built and released via `.github/workflows/release.yml` on push to `main`.
