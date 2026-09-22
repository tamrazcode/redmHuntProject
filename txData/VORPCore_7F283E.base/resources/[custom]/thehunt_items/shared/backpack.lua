-- Relative adjustment in the stable gizmo attachment frame. Keep x/y/z
-- identical between the editor and the attached backpack object.
-- Both server and client read these limits. Never accept arbitrary model/bone IDs.
BackpackFit = {}
-- Numeric fallback for the RDR Spine2/Spine3 region. The client resolves
-- SKEL_Spine2 by name first and uses this only when name lookup is unavailable.
-- RDR3's Spine2 bone id.  Keep this as the native bone id used by
-- GetPedBoneCoords; attachment itself resolves the entity bone index by name.
BackpackFit.BoneId = 14412
BackpackFit.Keys = {'x','y','z','rx','ry','rz'}
BackpackFit.Limits = {
    x={-0.35, 0.35}, y={-0.35, 0.35}, z={-0.35, 0.35},
    rx={-180.0, 180.0}, ry={-180.0, 180.0}, rz={-180.0, 180.0},
}
function BackpackFit.Normalize(value, strict, unlimited)
    if type(value) ~= 'table' then
        if strict then return nil end
        value = {}
    end
    local result = {}
    for _, key in ipairs(BackpackFit.Keys) do
        local n = value[key]
        if n == nil and not strict then n = 0 end
        if type(n) ~= 'number' or n ~= n or n == math.huge or n == -math.huge then return nil end
        local range = BackpackFit.Limits[key]
        if not unlimited and strict and (n < range[1] or n > range[2]) then return nil end
        result[key] = (unlimited and n or math.max(range[1], math.min(range[2], n))) + 0.0
    end
    return result
end
