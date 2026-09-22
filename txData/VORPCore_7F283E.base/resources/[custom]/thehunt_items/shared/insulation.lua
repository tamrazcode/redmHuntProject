-- One category-wide rule for every variant. Accessories deliberately have no entry.
HuntInsulation = {
    Hat = { level = 1, warmth = 1 }, Mask = { level = 1, warmth = 0.5 },
    NeckWear = { level = 1, warmth = 1 }, Shirt = { level = 2, warmth = 3 },
    Vest = { level = 2, warmth = 2 }, Coat = { level = 4, warmth = 7 },
    CoatClosed = { level = 4, warmth = 8 }, Poncho = { level = 3, warmth = 5 },
    Cloak = { level = 3, warmth = 5 }, Pant = { level = 3, warmth = 4 },
    Skirt = { level = 2, warmth = 2 }, Dress = { level = 2, warmth = 4 },
    Boots = { level = 3, warmth = 2 }, Spats = { level = 1, warmth = 0.5 },
    Chap = { level = 2, warmth = 1.5 }, Glove = { level = 2, warmth = 1 },
    Gauntlets = { level = 1, warmth = 0.5 }
}
HuntInsulationLabels = { 'Плохое утепление', 'Среднее утепление', 'Высокое утепление', 'Лучшее утепление' }

function HuntGetInsulationLabel(slot)
    local rule = HuntInsulation[slot]
    return rule and HuntInsulationLabels[rule.level] or nil
end
