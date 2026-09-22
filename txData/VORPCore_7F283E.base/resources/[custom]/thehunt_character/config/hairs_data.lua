-- =================================================================
-- HUNT: Hard RP — Hair & Beard Customization Registry
-- Complete VORP Hair & Beard Catalog
-- =================================================================

HairsData = {}

-- 1. Hair Color Palette Swatches
HairsData.ColorSwatches = {
    -- Order exactly matches *_BLONDE, *_BROWN ... entries in shared/hairs.lua.
    { id = 1, name = "Блонд", hex = "#b99462" },
    { id = 2, name = "Каштановый", hex = "#5b3826" },
    { id = 3, name = "Очень тёмно-каштановый", hex = "#1c1512" },
    { id = 4, name = "Тёмный блонд", hex = "#806447" },
    { id = 5, name = "Тёмно-рыжий", hex = "#71351f" },
    { id = 6, name = "Тёмно-седой", hex = "#4e4a47" },
    { id = 7, name = "Рыжий", hex = "#a94b24" },
    { id = 8, name = "Седой", hex = "#8d8d8b" },
    { id = 9, name = "Угольно-чёрный", hex = "#111111" },
    { id = 10, name = "Светлый блонд", hex = "#d4bd8d" },
    { id = 11, name = "Светло-каштановый", hex = "#8a6043" },
    { id = 12, name = "Светло-рыжий", hex = "#c56832" },
    { id = 13, name = "Светло-седой", hex = "#b1b1ae" },
    { id = 14, name = "Средне-каштановый", hex = "#70462e" },
    { id = 15, name = "Соль с перцем", hex = "#6f6d69" },
    { id = 16, name = "Клубничный блонд", hex = "#c48658" },
    { id = 17, name = "Белая седина", hex = "#d5d2ca" }
}

HairsData.MaleHairs = {
    { id = 0, name = "Налысо", hash = -1, tints = {} }
}
HairsData.FemaleHairs = {
    { id = 0, name = "Налысо", hash = -1, tints = {} }
}
HairsData.MaleBeards = {
    { id = 0, name = "Гладко выбрит", hash = -1, tints = {} }
}

if HairComponents then
    if HairComponents.Male and HairComponents.Male.hair then
        for styleIdx, styleList in ipairs(HairComponents.Male.hair) do
            local baseItem = styleList[1]
            if baseItem then
                local tintList = {}
                for tIdx, tItem in ipairs(styleList) do
                    table.insert(tintList, tItem.hash)
                end
                table.insert(HairsData.MaleHairs, {
                    id = styleIdx,
                    name = string.format("Прическа %d", styleIdx),
                    hash = baseItem.hash,
                    tints = tintList
                })
            end
        end
    end

    if HairComponents.Female and HairComponents.Female.hair then
        for styleIdx, styleList in ipairs(HairComponents.Female.hair) do
            local baseItem = styleList[1]
            if baseItem then
                local tintList = {}
                for tIdx, tItem in ipairs(styleList) do
                    table.insert(tintList, tItem.hash)
                end
                table.insert(HairsData.FemaleHairs, {
                    id = styleIdx,
                    name = string.format("Прическа %d", styleIdx),
                    hash = baseItem.hash,
                    tints = tintList
                })
            end
        end
    end

    if HairComponents.Male and HairComponents.Male.beard then
        for styleIdx, styleList in ipairs(HairComponents.Male.beard) do
            local baseItem = styleList[1]
            if baseItem then
                local tintList = {}
                for tIdx, tItem in ipairs(styleList) do
                    table.insert(tintList, tItem.hash)
                end
                table.insert(HairsData.MaleBeards, {
                    id = styleIdx,
                    name = string.format("Борода %d", styleIdx),
                    hash = baseItem.hash,
                    tints = tintList
                })
            end
        end
    end
end
