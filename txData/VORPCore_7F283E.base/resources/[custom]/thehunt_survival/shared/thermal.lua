Thermal = {}
function Thermal.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function Thermal.Approach(current, target, dt, tau)
    return current + (target - current) * (1 - math.exp(-dt / tau))
end
function Thermal.Target(air, warmth, wet)
    warmth = Thermal.Clamp(warmth, 0, Config.MaxWarmth)
    wet = Thermal.Clamp(wet, 0, 1)
    local felt = air + warmth * (1 - wet * Config.WetWarmthLoss) - wet * Config.WetCooling
    if felt < Config.ComfortLow then return math.max(-1.25, (felt - Config.ComfortLow) / Config.ColdSpan), felt end
    if felt > Config.ComfortHigh then return math.min(1.25, (felt - Config.ComfortHigh) / Config.HeatSpan), felt end
    return 0.0, felt
end
