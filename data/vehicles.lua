SPZ = SPZ or {}

SPZ.VehicleRegistry = {

  -- ── Class C — Street ──────────────────────────────────────────────
  ["sultan"] = {
    model       = "sultan",
    label       = "Karin Sultan",
    class       = 0,
    top_speed   = 155,       -- indicative km/h (display only)
    handling    = 72,        -- 0–100 display score
    accel       = 68,
    braking     = 65,
    poll_weight = 10,
    freeroam    = true,
    race        = true,
  },

  ["dominatormuscle"] = {
    model       = "dominatormuscle",
    label       = "Vapid Dominator",
    class       = 0,
    top_speed   = 160,
    handling    = 65,
    accel       = 74,
    braking     = 60,
    poll_weight = 8,
    freeroam    = true,
    race        = true,
  },

  -- ── Class B — Sport ───────────────────────────────────────────────
  ["sultanrs"] = {
    model       = "sultanrs",
    label       = "Karin Sultan RS",
    class       = 1,
    top_speed   = 195,
    handling    = 85,
    accel       = 80,
    braking     = 78,
    poll_weight = 10,
    freeroam    = true,
    race        = true,
  },

  ["jester3"] = {
    model       = "jester3",
    label       = "Dinka Jester Classic",
    class       = 1,
    top_speed   = 188,
    handling    = 82,
    accel       = 78,
    braking     = 75,
    poll_weight = 9,
    freeroam    = true,
    race        = true,
  },

  -- ── Class A — Pro ─────────────────────────────────────────────────
  ["comet6"] = {
    model       = "comet6",
    label       = "Pfister Comet S2",
    class       = 2,
    top_speed   = 245,
    handling    = 88,
    accel       = 86,
    braking     = 84,
    poll_weight = 10,
    freeroam    = true,
    race        = true,
  },

  ["italigto"] = {
    model       = "italigto",
    label       = "Grotti Itali GTO",
    class       = 2,
    top_speed   = 250,
    handling    = 85,
    accel       = 88,
    braking     = 82,
    poll_weight = 9,
    freeroam    = true,
    race        = true,
  },

  -- ── Class S — Elite ───────────────────────────────────────────────
  ["zentorno"] = {
    model       = "zentorno",
    label       = "Pegassi Zentorno",
    class       = 3,
    top_speed   = 320,
    handling    = 78,
    accel       = 92,
    braking     = 80,
    poll_weight = 8,
    freeroam    = true,
    race        = true,
  },

  ["t20"] = {
    model       = "t20",
    label       = "Progen T20",
    class       = 3,
    top_speed   = 315,
    handling    = 82,
    accel       = 90,
    braking     = 85,
    poll_weight = 10,
    freeroam    = true,
    race        = true,
  },
}
