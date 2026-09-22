RootsFxConfig = {
    growMs = 320,
    sinkMs = 360,
    modelTimeoutMs = 2000,
    ptfxTimeoutMs = 2000,

    -- One nature scrub under the feet (support, not the main read)
    models = {
        rootA = "rdr_bush_dry_thin_aa_sim",
        rootB = "rdr_bush_brush_dead_aa_sim",
        rootFallback = {
            "rdr_bush_dry_thin_aa_sim",
            "rdr_bush_brush_dead_aa_sim",
            "p_tumbleweed01x",
        },
    },

    rootOffsets = {
        { x = 0.00, y = 0.05 },
        { x = -0.28, y = -0.10 },
        { x = 0.28, y = -0.10 },
    },

    visibleRootHeight = 1.0,
    rootBurrow = 0.06,
    groundSit = true,
    anchorLift = 0.10,
    growOvershoot = 0.0,
    growTwistDeg = 6.0,

    sequence = {
        dirtAt = 0,
        rootsStartAt = 40,
        rootsGrowMs = 320,
        etherStartAt = 200,
        etherEndAt = 900,
        midDirtAt = 160,
    },

    wrapPreview = { enabled = false },

    ptfx = {
        dict = "core",
        dirt = "ent_dst_dirt",
        leaves = "ent_col_bush_leaves",
        plant = "ent_dst_plant_leaves",
        dirtScale = 0.28,
        midDirtScale = 0.16,
        leavesScale = 0.30,
        plantScale = 0.22,
        -- living aura: occasional leaf swirls while rooted
        auraEveryMs = 1600,
    },

    -- Living natural energy (soft vines of light — NOT neon laser cages)
    living = {
        enabled = true,
        legTurns = 2.15,         -- spiral wraps around each leg
        legRadius = 0.13,
        legRadiusPulse = 0.018,
        legSegs = 18,
        wristSegs = 12,
        wristRadius = 0.11,
        wispCount = 5,
        waveSpeed = 1.35,
        pulsePeriodMs = 1400,
        -- soft nature palette (green-gold life energy)
        vineColor = { r = 48,  g = 92,  b = 52,  a = 130 },
        flowColor = { r = 110, g = 160, b = 85,  a = 175 },
        coreColor = { r = 210, g = 235, b = 170, a = 220 },
        wispColor = { r = 180, g = 210, b = 140, a = 140 },
    },

    -- old ribbon path kept off
    ribbon = {
        enabled = false,
        usePoly = false,
        lineFallback = false,
        etherOnly = false,
    },

    bodyWrap = { enabled = false },
    sparks = { count = 0 },
    light = {
        enabled = true,
        etherOnly = false,
        atHands = true,
        atFeet = true,
        r = 140, g = 190, b = 110,
        radius = 0.70,
        intensity = 0.70,
        flicker = 0.06,
    },

    ghostHaze = {
        enabled = false,
        dict = "scr_agnesdowd_ghost",
        name = "scr_ped_ghost_haze_stage1",
        scale = 0.55,
    },

    footRing = { enabled = false },
    ropeAttach = { enabled = false },
    vines = { enabled = false },

    limits = {
        maxDrawCalls = 420,
        maxProps = 64,
        maxLights = 8,
        maxRibbonTargets = 16,
        fullDetailDist = 24.0,
        simpleDetailDist = 38.0,
        cullDist = 48.0,
        visibilityRecheckMs = 1200,
    },

    previewModels = {
        "rdr_bush_dry_thin_aa_sim",
        "rdr_bush_brush_dead_aa_sim",
        "p_tumbleweed01x",
    },
}
