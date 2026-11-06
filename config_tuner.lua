-- config_tuner.lua — the tuner (/tuner, warmup tuning). Moved from
-- spz-tunners/config.lua when it was merged into spz-vehicles.
-- Read as Config.Tuner.<option>.

Config.Tuner = {
    -- Menu position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
    MenuPosition = 'top-left',

    -- Command
    EnableCommand = true,
    Command = 'tuner',           -- /tuner (also aliases /tune, /customs)
    AllowAnywhere = true,        -- true: /tuner anywhere; false: shop locations only

    -- Camera: orbit / focus on the part being tuned (engine, wheels, spoiler...)
    EnableDynamicCamera = true,

    -- Pricing
    FreeTuning = true,           -- true: free; false: charge DefaultModPrice per mod
    DefaultModPrice = 500,

    -- Auto apply: ←/→ keeps the option on the car straight away (no Enter
    -- needed) and autosaves. false = the old preview-then-Enter behaviour.
    AutoApply = true,

    -- Write the preset to the vehicle's statebag (and spz-vehicles' saved look)
    SaveToVehicleState = true,

    -- Tuner shops (used when AllowAnywhere = false)
    Shops = {
        { name = "Los Santos Customs (Bennys)", coords = vector3(-211.5, -1324.0, 30.9), heading = 140.0, radius = 5.0 },
        { name = "Harmony Customs",             coords = vector3(1175.0, 2640.0, 37.7),  heading = 0.0,   radius = 5.0 },
        { name = "Paleto Bay Customs",          coords = vector3(110.0, 6626.0, 31.8),   heading = 45.0,  radius = 5.0 },
    },
}
