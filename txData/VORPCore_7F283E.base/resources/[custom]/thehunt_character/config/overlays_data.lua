-- =================================================================
-- HUNT: Hard RP — Overlay Texture Compositing Registry
-- Fully verified with VORP and femga/rdr3_discoveries
-- =================================================================

OverlaysData = {}

-- 1. Renderer Palettes
OverlaysData.RendererPalettes = {
    eyebrows     = joaat("METAPED_TINT_MAKEUP"),
    beardstabble = joaat("METAPED_TINT_HAIR"),
    hair         = joaat("METAPED_TINT_HAIR"),
    lipsticks    = joaat("METAPED_TINT_MAKEUP"),
    blush        = joaat("METAPED_TINT_MAKEUP"),
    shadows      = joaat("METAPED_TINT_MAKEUP"),
    eyeliners    = joaat("METAPED_TINT_MAKEUP"),
    paintedmasks = joaat("METAPED_TINT_MAKEUP"),
    grime        = joaat("METAPED_TINT_MAKEUP"),
    foundation   = joaat("METAPED_TINT_MAKEUP")
}

-- 2. Swatches for Colored Overlays & Makeup
OverlaysData.BrowSwatches = {
    { hash = 0x3F6E70FF, name = "Чёрный", hex = "#171717" },
    { hash = 0x0105607B, name = "Серый", hex = "#77736f" },
    { hash = 0x17CBCC83, name = "Красный", hex = "#8c2921" },
    { hash = 0x29F81B2A, name = "Зелёный", hex = "#52613a" },
    { hash = 0x3385C5DB, name = "Розовый", hex = "#bd777a" },
    { hash = 0x37CD36D4, name = "Тёмно-рыжий", hex = "#5b241d" },
    { hash = 0x4101ED87, name = "Средне-каштановый", hex = "#67442f" },
    { hash = 0x63838A81, name = "Медно-рыжий", hex = "#9a4a35" },
    { hash = 0x6765BC15, name = "Мягкий чёрный", hex = "#302d2b" },
    { hash = 0x8BA18876, name = "Светло-серый", hex = "#aaa59e" },
    { hash = 0x9AC34F34, name = "Блонд", hex = "#c3a466" },
    { hash = 0x9E4803A0, name = "Тёмно-фиолетовый", hex = "#49354d" },
    { hash = 0xA4041CEF, name = "Оранжево-рыжий", hex = "#bd6633" },
    { hash = 0xA4CFABD0, name = "Светло-розовый", hex = "#d4a0a2" },
    { hash = 0xAA65D8A3, name = "Тёмно-синий", hex = "#2d4058" },
    { hash = 0xB562025C, name = "Тёмно-розовый", hex = "#78444f" },
    { hash = 0xB9E7F722, name = "Светло-фиолетовый", hex = "#99819f" },
    { hash = 0xBBF43EF8, name = "Светло-каштановый", hex = "#986943" },
    { hash = 0xD1476963, name = "Фиолетовый", hex = "#654c6b" },
    { hash = 0xD799E1C2, name = "Красно-розовый", hex = "#a34f58" },
    { hash = 0xDC6BC93B, name = "Тёмно-серый", hex = "#4f4c49" },
    { hash = 0xDFB1F64C, name = "Каштановый", hex = "#533526" },
    { hash = 0xF509C745, name = "Тёмный красно-рыжий", hex = "#772e25" },
    { hash = 0xF93DB0C8, name = "Светлый красно-рыжий", hex = "#ad5748" },
    { hash = 0xFB71527B, name = "Графитовый", hex = "#363737" }
}

OverlaysData.LipstickSwatches = {
    { hash = 0x17CBCC83, name = "Классический красный", hex = "#931d1d" },
    { hash = 0xF509C745, name = "Винный", hex = "#6b1a24" },
    { hash = 0xD799E1C2, name = "Ягодный", hex = "#9a2e4b" },
    { hash = 0xB562025C, name = "Тёмно-вишнёвый", hex = "#5c1b2d" },
    { hash = 0x3385C5DB, name = "Нежно-розовый", hex = "#b86b77" },
    { hash = 0xA4CFABD0, name = "Нюд роза", hex = "#c98585" },
    { hash = 0xA4041CEF, name = "Коралловый", hex = "#b45233" },
    { hash = 0x63838A81, name = "Терракотовый", hex = "#8a3a2b" },
    { hash = 0xDFB1F64C, name = "Тёплый шоколад", hex = "#5e392b" },
    { hash = 0x4101ED87, name = "Нюд беж", hex = "#7d5843" },
    { hash = 0xD1476963, name = "Сливовый", hex = "#572b53" },
    { hash = 0x9E4803A0, name = "Тёмно-пурпурный", hex = "#3e1d3c" },
    { hash = 0x3F6E70FF, name = "Глубокий чёрный", hex = "#1a1818" }
}

OverlaysData.EyelinerSwatches = {
    { hash = 0x3F6E70FF, name = "Угольно-чёрный", hex = "#121212" },
    { hash = 0x6765BC15, name = "Мягкий чёрный", hex = "#2b2928" },
    { hash = 0xFB71527B, name = "Графитовый", hex = "#38393b" },
    { hash = 0x0105607B, name = "Серый дым", hex = "#5c5b59" },
    { hash = 0xDFB1F64C, name = "Тёмно-коричневый", hex = "#42281e" },
    { hash = 0x4101ED87, name = "Каштановый", hex = "#593a28" },
    { hash = 0xAA65D8A3, name = "Тёмно-синий", hex = "#1c2a38" },
    { hash = 0x29F81B2A, name = "Хвойный", hex = "#2d3b24" },
    { hash = 0x9E4803A0, name = "Тёмно-фиолетовый", hex = "#362038" },
    { hash = 0x17CBCC83, name = "Бордовый", hex = "#5e1d1d" }
}

OverlaysData.ShadowSwatches = {
    { hash = 0x3F6E70FF, name = "Смоки блэк", hex = "#1c1b1a" },
    { hash = 0x6765BC15, name = "Тёмный графит", hex = "#333130" },
    { hash = 0x8BA18876, name = "Серебристый", hex = "#8a857e" },
    { hash = 0x9AC34F34, name = "Золотисто-песочный", hex = "#ab8d50" },
    { hash = 0x63838A81, name = "Медный", hex = "#8c4430" },
    { hash = 0xBBF43EF8, name = "Бронзовый", hex = "#784b2c" },
    { hash = 0xDFB1F64C, name = "Шоколадный", hex = "#4f3122" },
    { hash = 0xD799E1C2, name = "Пыльная роза", hex = "#8c4550" },
    { hash = 0xD1476963, name = "Фиолетовый дым", hex = "#573b5e" },
    { hash = 0x29F81B2A, name = "Оливковый", hex = "#424d2d" }
}

OverlaysData.BlushSwatches = {
    { hash = 0xD799E1C2, name = "Нежный румянец", hex = "#a84e5b" },
    { hash = 0x17CBCC83, name = "Алый", hex = "#942525" },
    { hash = 0xB562025C, name = "Ягодный", hex = "#732c3d" },
    { hash = 0x3385C5DB, name = "Розовый персик", hex = "#b56c75" },
    { hash = 0xA4041CEF, name = "Персиковый", hex = "#a85437" },
    { hash = 0x63838A81, name = "Терракотовый", hex = "#803c2e" },
    { hash = 0xA4CFABD0, name = "Светло-розовый", hex = "#bd8287" }
}

OverlaysData.WarpaintSwatches = {
    { hash = 0x17CBCC83, name = "Кроваво-красный", hex = "#9c1414" },
    { hash = 0x3F6E70FF, name = "Угольно-чёрный", hex = "#111111" },
    { hash = 0x8BA18876, name = "Белый мел", hex = "#d9d5ce" },
    { hash = 0x9AC34F34, name = "Жёлтая охра", hex = "#ba9332" },
    { hash = 0xAA65D8A3, name = "Боевой синий", hex = "#22416b" },
    { hash = 0x29F81B2A, name = "Лесной зелёный", hex = "#345922" },
    { hash = 0xA4041CEF, name = "Оранжевая глина", hex = "#ad4e1f" },
    { hash = 0x63838A81, name = "Ржавчина", hex = "#7d2f1f" }
}

OverlaysData.GrimeSwatches = {
    { hash = 0x3F6E70FF, name = "Тёмная сажа", hex = "#1c1c1c" },
    { hash = 0x4101ED87, name = "Земля", hex = "#523824" },
    { hash = 0xDFB1F64C, name = "Тёмный грунт", hex = "#3d2516" },
    { hash = 0xBBF43EF8, name = "Сухая пыль", hex = "#7d624a" },
    { hash = 0x63838A81, name = "Ржавчина", hex = "#753924" }
}

OverlaysData.LayerSwatches = {
    eyebrows     = OverlaysData.BrowSwatches,
    beardstabble = OverlaysData.BrowSwatches,
    hair         = OverlaysData.BrowSwatches,
    lipsticks    = OverlaysData.LipstickSwatches,
    blush        = OverlaysData.BlushSwatches,
    shadows      = OverlaysData.ShadowSwatches,
    eyeliners    = OverlaysData.EyelinerSwatches,
    paintedmasks = OverlaysData.WarpaintSwatches,
    grime        = OverlaysData.GrimeSwatches,
    foundation   = OverlaysData.BrowSwatches
}

-- Array of palette color hashes for Lua validation
local OfficialOverlayPalettes = {}
for _, item in ipairs(OverlaysData.BrowSwatches) do table.insert(OfficialOverlayPalettes, item.hash) end
OverlaysData.ColorPalettes = {
    eyebrows     = OfficialOverlayPalettes,
    beardstabble = OfficialOverlayPalettes,
    hair         = OfficialOverlayPalettes,
    lipsticks    = OfficialOverlayPalettes,
    blush        = OfficialOverlayPalettes,
    shadows      = OfficialOverlayPalettes,
    eyeliners    = OfficialOverlayPalettes,
    paintedmasks = OfficialOverlayPalettes,
    grime        = OfficialOverlayPalettes,
    foundation   = OfficialOverlayPalettes
}

-- 3. Base Overlay Layers Schema
OverlaysData.Layers = {
    { name = "scars",        label = "Шрамы",             tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "ageing",       label = "Старение",          tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "freckles",     label = "Веснушки",          tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "moles",        label = "Родинки",           tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "spots",        label = "Пятна",             tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "acne",         label = "Дефекты кожи",      tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "grime",        label = "Грязь",             tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "complex",      label = "Цвет лица",         tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "disc",         label = "Неровности",        tx_color_type = 1, hasPalette = false, hasOpacity = true },
    { name = "beardstabble", label = "Щетина",             tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "blush",        label = "Румяна",            tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "shadows",      label = "Тени для век",      tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "eyeliners",    label = "Подводка для глаз", tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "lipsticks",    label = "Помада",            tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "foundation",   label = "Тональная основа",  tx_color_type = 0, hasPalette = true,  hasOpacity = true },
    { name = "paintedmasks", label = "Боевая раскраска",  tx_color_type = 0, hasPalette = true,  hasOpacity = true }
}

local function OverlayEntries(rows)
    local result = {}
    for index, row in ipairs(rows) do
        result[index] = {
            id = row[1], albedo = row[2], normal = row[3] or 0,
            ma = row[4] or 0, label = string.format("Вариант %d", index),
            var = row[5] or 0
        }
    end
    return result
end

-- 4. Complete Authoritative Overlay Info Dictionaries
OverlaysData.Info = {
    eyebrows = OverlayEntries({
        {0x07844317, 0xF81B2E66, 0x7BC4288B, 0x202674A1},
        {0x0A83CA6E, 0x8FA4286B, 0xBD811948, 0xB82C8FBB},
        {0x139A5CA3, 0x487ABE5A, 0x22A9DDF9, 0x78AA9401},
        {0x1832E474, 0x96FBB931, 0x32FA2683, 0xA1775B18},
        {0x216EF84C, 0x269CD8F8, 0x2F54C727, 0xCCBD1939},
        {0x2594304D, 0xA5A23CD1, 0x8611B42C, 0x0238302B},
        {0x33C39BC5, 0xF928E29B, 0x46C268BD, 0x4B92F13E},
        {0x443E3CBA, 0x6C83B571, 0x2B191070, 0xD551E623},
        {0x4F5052DE, 0x827EEF46, 0x70E8C702, 0xD97518F9},
        {0x5C049D35, 0x41E90506, 0x7E47D163, 0x54100288},
        {0x77A1546E, 0x43C4AE44, 0x290FC7F7, 0xD8FC26A9},
        {0x8A4B79C2, 0xAE6ED4E6, 0x89B29E5A, 0xFA0476E4},
        {0x9728137B, 0x23E65D35, 0xEE39073F, 0x218DD4C8},
        {0xA6DE8325, 0x7A93F649, 0x22B33B65, 0xEE6CCF11},
        {0xA8CCB6C4, 0x29AD8BF9, 0x34ABB09D, 0xCF206860},
        {0xB3F74D19, 0x3E2F71B1, 0xD4809D11, 0x9ABFA640},
        {0xBD38AFD9, 0x058A698E, 0x9A732F86, 0x2EF1D769},
        {0xCD0A4F7C, 0xED46998E, 0xB5B73A38, 0x15C5FB78},
        {0xD0EC86FF, 0x81B462A2, 0x894F8744, 0x51551810},
        {0xEB088A20, 0x0C6CDBDC, 0x91A2496E, 0xE639F138},
        {0xF0CA96FC, 0xAC3BCA3F, 0x667FEFF8, 0xDD8E5EFF},
        {0xF3351BD9, 0xC3286EA4, 0x8BB9158A, 0xFBBAE4D8},
        {0xF9052779, 0x8AEADE78, 0x21BB2D97, 0x75A0B928},
        {0xFE183197, 0x92B508CD, 0x6AA92A3E, 0xB4A436DB},
    }),
    scars = OverlayEntries({
        {0xC8E45B5B, 0x6245579F, 0xD53A336F}, {0x90D86B44, 0xA1538E6F, 0xDFCB1159},
        {0x23190FC3, 0x39683ECE, 0x249C1A0A}, {0x7574B47D, 0x3AB2A0BB, 0x7A70886A},
        {0x7FE8C965, 0xB81C8D16, 0x7210971B}, {0x083059FE, 0xC332710C, 0x860EE45E},
        {0x19E9FD71, 0x40895310, 0xB753C5C7}, {0x4CAF62FB, 0xD80F2F64, 0x00BBF225},
        {0xDE650668, 0x85F6BF71, 0x3DD0B0AE}, {0xC648562B, 0x6397E4D9, 0x2B59CDA1},
        {0x484BAEF8, 0xBF2946DE, 0xD3F2F2F6}, {0x190F5080, 0xCBBDB741, 0x9518FA34},
        {0x2B5DF51D, 0x0E05C415, 0x8B8C57AC}, {0xE490E784, 0x50853115, 0xDA7F2A1E},
        {0x0ED23C06, 0xAEA45D76, 0x364DAAA6}, {0x5712CCB6, 0x9318AF61, 0x98104C8C},
    }),
    ageing = OverlayEntries({
        {0x96DD8F42, 0x1BA4244B, 0xBA46CE92}, {0x6D9DC405, 0xAFE82F0C, 0x5CF8808E},
        {0x2761B792, 0x4105C6B3, 0x8607CC56}, {0x19009AD0, 0xEBC18618, 0x9087AF96},
        {0xC29F6E07, 0xF9887FA7, 0x1331C3C9}, {0xA45F3187, 0x1C30961A, 0x3CA2F3AE},
        {0x5E21250C, 0x01E35044, 0x5A965FF0}, {0x4FFE08C6, 0xA65757F2, 0xC46CC005},
        {0x2DAD4485, 0x358DEFDA, 0x55D317B4}, {0x3F70680B, 0x7073A58F, 0x33E73C5F},
        {0xD3310F8E, 0xD9E8A605, 0x22297EA5}, {0xF27A4C84, 0xE0F0971B, 0x9F0E6718},
        {0x0044E819, 0xFD844ADF, 0x315A6D56}, {0xA648348D, 0xC329F765, 0xE8CD7F20},
        {0x94F991F0, 0x8586D19B, 0xCA334396}, {0xCAACFD56, 0xD2D0BF4F, 0xE0203BDA},
        {0xB9675ACB, 0x2387AF71, 0x90A80AE1}, {0x3C2CE03C, 0xC6DCBCCA, 0x609B7EBD},
        {0xF2D64D90, 0xC6DCBCCA, 0x609B7EBD}, {0xE389AEF7, 0xDF591FF2, 0x11D92A14},
        {0x89317A44, 0xB4640D19, 0x2F56FDA5}, {0x64B3347C, 0xFF2E8F96, 0x45EE7B10},
        {0x9FFDAB10, 0x8F2950D9, 0x85BDD7E8}, {0x91D40EBD, 0x5DCD1D4E, 0xA1B5F71F},
        {0x6B94C23F, 0xF17FE41C, 0x0C480977},
    }),
    freckles = OverlayEntries({
        {0x1B794C51, 0x59B8159A}, {0x29BFE8DE, 0x03FCF67B},
        {0x0EF6B34C, 0x21E2FD82}, {0x64925E7E, 0x3FD45844},
        {0xF5F280FC, 0xE372E00E}, {0x33B0FC78, 0x288810E0},
        {0x25675FE5, 0xEB8C0B1D}, {0xD10F3736, 0x3885AC2A},
        {0x5126B75F, 0xB061C984}, {0x6B8EEC2F, 0xE1D1113E},
        {0x0A9A26F7, 0xA1EC1AEA}, {0xFDE40D8B, 0x6DBC9203},
        {0x7E338E44, 0x097D1D0A}, {0x70F273C2, 0x81A25BCE},
        {0x61C7D56D, 0x197A1335},
    }),
    moles = OverlayEntries({
        {0x821FD077, 0xDFDA0798, 0xE4E90C92}, {0xCD38E6A8, 0xE9CF623E, 0x43FAEA4B},
        {0x9F9D8B72, 0x27450B2F, 0x0808DBFB}, {0xE7179A39, 0x38638E0B, 0x99346057},
        {0xBB094249, 0x763F8624, 0x6975D6F9}, {0x03AC5362, 0xEF158115, 0xBA297751},
        {0x154FF6A9, 0xEE28E6F7, 0xB7548307}, {0x1E23084F, 0x566ACE2F, 0x361237C6},
        {0x31DBAFC0, 0x0AB0CC2B, 0xDBF55701}, {0x3AC5C194, 0xC940CC25, 0x41CB48FC},
        {0x4500D516, 0x3A1EEDB1, 0x17BC19B0}, {0x3695B840, 0x1D30222E, 0xDA5FDF7E},
        {0x286C1BED, 0x4F0B4FA8, 0x40333534}, {0x934BF1AF, 0x4540A8D7, 0x933ACF76},
        {0x84F55502, 0x47BE6D32, 0xDCF7108E}, {0xBD9A464B, 0x9DABB1B9, 0x4A3B1739},
    }),
    spots = OverlayEntries({
        {0x5BBFF5F7, 0x24968425, 0xA5D532AD}, {0x65EC0A4F, 0x326A7845, 0xC09B2354},
        {0x3F143CA0, 0x91D7E39E, 0xD607DF75}, {0x49675146, 0x2E6C3769, 0xE6A21CD5},
        {0x07504D2D, 0x39F16CE6, 0x5CB32D5C}, {0xF161214F, 0x47C60FBA, 0x19424C77},
        {0xE43286F2, 0xA7E86379, 0x7C07E0B0}, {0xDDDC7A46, 0x26D3DA64, 0x5A69A9BB},
        {0xD086DF9B, 0x7D6FF58C, 0x5A0D99C8}, {0xBA51B331, 0xCB23CA55, 0xA7720C6A},
        {0xE4CF097B, 0x51D0FBDA, 0xB01F5202}, {0xF70CADF6, 0xD0858DFC, 0x7E067837},
        {0xC07F40DC, 0x3BAF1008, 0x75030E1B}, {0xD3B1E741, 0x97091388, 0xA191AA56},
        {0xB494A903, 0x18025AE1, 0x86F51AD1}, {0xC6EE4DB6, 0xC9F3EBA4, 0xE819AD33},
    }),
    acne = OverlayEntries({
        {0x96DD8F42, 0x1BA4244B, 0xBA46CE92}
    }),
    grime = OverlayEntries({
        {0xA2F30923, 0x16CDD724, 0x136165B3, 0xF3DFA7AC},
        {0xD5B1EEA0, 0x0E599D69, 0x5C67FB68, 0x40FEC59E},
        {0x7EC740CC, 0x0FAE8DC6, 0x9E7A4B63, 0xB48BF65A},
        {0xB08F245B, 0x98358521, 0x1FAA4A84, 0x81428E8F},
        {0x1A5E77F8, 0x8D3D2563, 0x1FAA4A84, 0x81428E8F},
        {0xE81B9373, 0xAE43378D, 0x0CBEEF9B, 0x92097B22},
        {0x3CFA3D2F, 0x7499570E, 0xA27FF667, 0x24B49749},
        {0x0B865A48, 0xB80F6B12, 0x377319E3, 0x3CDC25A9},
        {0x506DE416, 0x537BA522, 0x006AF092, 0x5CCEA9F8},
        {0x1F250185, 0x51BE975D, 0x3F718027, 0x5527ACCF},
        {0xE71930B0, 0x595D09A3, 0xF4E08D43, 0x60B91CE7},
        {0xDE571F2C, 0xE7FAFDFA, 0xE6A18BBF, 0xCB315A57},
        {0x0CA6FBCB, 0x0E27372E, 0xD4894921, 0xBF339D56},
        {0x21F62669, 0x693623F0, 0xDB95176C, 0xEA27B375},
        {0xFB09D881, 0xC4A40DA0, 0xADD1DC3D, 0xFD797A87},
        {0x11530513, 0x67C6D30F, 0x26AA38C3, 0x89C2FFE3},
    }),
    complex = OverlayEntries({
        {0xF679EDE7, 0xFAAE9FF0}, {0x3FFB80ED, 0x1FDFD4A1},
        {0x31C0E478, 0xC72D0698}, {0x2457C9A6, 0x98F1C76F},
        {0x16262D43, 0xE0D03293}, {0x88F312DB, 0x2ECCC670},
        {0x785C71AE, 0xAE1C329F}, {0x6D7D5BF0, 0x23201E55},
        {0x5F2FBF55, 0x94503F97}, {0xBF38FF6A, 0x5F62F986},
        {0xF5656C26, 0x83417009}, {0x03A408A3, 0x1BCC4185},
        {0x293453C3, 0x6C556574}, {0x43150800, 0x1E486F85},
    }),
    disc = OverlayEntries({
        {0xD44A5ABA, 0x2D3AEB2F}, {0xE2CF77C4, 0xB8945AC0},
        {0xCF57D0E9, 0xB15E4E47}, {0xE0A8738A, 0x25A711DD},
        {0xABD109DC, 0xCEBED6D9}, {0xB91C2472, 0xFDD6C9AB},
        {0x894844B7, 0x7E89B165}, {0x96FAE01C, 0x458799CD},
        {0x86D3BFCE, 0x8F2F2826}, {0x5488DB39, 0xB49A0275},
        {0x7DA5A5AE, 0x8200F51D}, {0xE73778DC, 0x8D35AC90},
        {0xD83EDADF, 0x96B619CD}, {0xE380F163, 0xAB7309F7},
        {0xB4611324, 0x26FEBDD4}, {0xC6ABB7B9, 0xC162C835},
    }),
    beardstabble = OverlayEntries({
        {0x375D4807, 0xB5827817, 0x5041B648, 0x83F42340}
    }),
    foundation = OverlayEntries({
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 0},
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 1},
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 2},
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 3},
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 4},
        {0xEF5AB280, 0xD9264247, 0, 0x1535C7C9, 5},
    }),
    blush = OverlayEntries({
        {0x6DB440FA, 0x43B1AACA, 0, 0, 0},
        {0x47617455, 0x9CAD2EF0, 0, 0, 1},
        {0x114D082D, 0xA52E3B98, 0, 0, 2},
        {0xEC6F3E72, 0xB5CED4CB, 0, 0, 3},
    }),
    shadows = OverlayEntries({
        {0x47BD7289, 0x5C5C98FC, 0, 0xE20345CC, 0},
        {0x47BD7289, 0x5C5C98FC, 0, 0xE20345CC, 1},
        {0x47BD7289, 0x5C5C98FC, 0, 0xE20345CC, 2},
        {0x47BD7289, 0x5C5C98FC, 0, 0xE20345CC, 3},
    }),
    eyeliners = OverlayEntries({
        {0x29A2E58F, 0xA952BF75, 0, 0xDD55AF2A, 0},
        {0x29A2E58F, 0xA952BF75, 0, 0xDD55AF2A, 1},
        {0x29A2E58F, 0xA952BF75, 0, 0xDD55AF2A, 2},
        {0x29A2E58F, 0xA952BF75, 0, 0xDD55AF2A, 3},
    }),
    lipsticks = OverlayEntries({
        {0x887E11E0, 0x96A5E4FB, 0x1C77591C, 0x4255A5F4, 0},
        {0x887E11E0, 0x96A5E4FB, 0x1C77591C, 0x4255A5F4, 1},
        {0x887E11E0, 0x96A5E4FB, 0x1C77591C, 0x4255A5F4, 2},
        {0x887E11E0, 0x96A5E4FB, 0x1C77591C, 0x4255A5F4, 3},
    }),
    paintedmasks = OverlayEntries({
        {0x5995AA6F, 0x99BCB03F, 0, 0, 0},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 1},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 2},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 3},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 4},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 5},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 6},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 7},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 8},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 9},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 10},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 11},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 12},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 13},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 14},
        {0x5995AA6F, 0x99BCB03F, 0, 0, 15},
    }),
    hair = OverlayEntries({
        {0x39051515, 0x60A4A360, 0x8D65EFF2, 0x62759D82},
        {0x5E71DFEE, 0x71147B90, 0, 0xD8EB57BC},
        {0xDD735DEF, 0x493214E4, 0, 0x6613D121},
        {0x69622EAD, 0xA6E819C4, 0, 0xE581D851},
    }),
}
