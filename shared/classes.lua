SPZ = SPZ or {}

SPZ.VehicleClass = {
  C = 0,   -- Street  — stock-bodied, entry level
  B = 1,   -- Sport   — sport cars, higher performance
  A = 2,   -- Pro     — high-performance, near supercar
  S = 3,   -- Elite   — supercars and exotics
}

SPZ.ClassMeta = {
  [0] = {
    id          = 0,
    label       = "Class C",
    name        = "Street",
    color       = "#639922",
    min_license = 0,
    race_laps   = { min = 3, max = 5 },
    points_win  = 25,
  },
  [1] = {
    id          = 1,
    label       = "Class B",
    name        = "Sport",
    color       = "#185FA5",
    min_license = 1,
    race_laps   = { min = 4, max = 6 },
    points_win  = 35,
  },
  [2] = {
    id          = 2,
    label       = "Class A",
    name        = "Pro",
    color       = "#BA7517",
    min_license = 2,
    race_laps   = { min = 5, max = 8 },
    points_win  = 50,
  },
  [3] = {
    id          = 3,
    label       = "Class S",
    name        = "Elite",
    color       = "#993C1D",
    min_license = 3,
    race_laps   = { min = 5, max = 10 },
    points_win  = 75,
  },
}
