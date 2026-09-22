Config = {}

-- ==============================================================================
-- 1. СТАТИЧЕСКИЕ И ДИНАМИЧЕСКИЕ IMAP / IPL (Эпоха 1907 / Достроенные здания / Декор)
-- Полный реестр всех 367 включений и 98 удалений мусора для завершенной карты RDR2
-- ==============================================================================

Config.Imaps = {
    -- Включаемые IMAP (Все достроенные здания, целые стены, рельсы, вывески, свет, лагеря)
    Enable = {
        -661560211, -1933617196, -892659042, -1588793465, 1186533019, -156313117,
        56708243, 1136898294, 30201771, -1475403379, 696143352, 897455211,
        1285430299, 1573766063, -554932707, 1097534152, 903666582, 637874199,
        -1521525254, -761186147, 924412185, -1158072415, 135886022, 2077623691,
        -555736180, -693812694, -1386614896, 2080640229, -805522215, 499044444,
        -196117122, -1022518533, 691955519, -142900294, -657241692, -1112373128,
        1353861354, -956131204, 578474998, -1860722801, 931647489, 1467774743,
        411742897, 349494711, 2087181890, 1757739778, -2029237844, -2000794023,
        -531137142, 5422464, -218940381, 1236917971, -918785150, -61896664,
        -648893593, 1534006738, -376056363, 519091847, -1225606266, -1874720370,
        -1936937394, 810684093, 321594819, -385999832, -1366431554, -2144587490,
        1149195254, 58066174, 1944013855, -880373663, -70021332, -677977650,
        702350293, 1426715569, 26815048, -1229109520, 1641449717, 1258244391,
        -501793326, 1490756544, -753454183, -1854368742, 466168676, 411846009,
        -393583941, -636161219, -518004776, -562289114, -1331012521, -743781837,
        2114706334, -338553155, -1636879249, -1106668087, 2028590076, 131323483,
        -130638369, 2137790641, 1934919499, -515396642, 619024057, -614421509,
        604920544, 1382135686, -1968130469, -276259505, 1003623269, 1638937672,
        739805687, 795060201, -395621323, -198004806, -924329535, -723094901,
        1929454697, 1649902358, 1864768904, 938290967, -1253110600, 1861460906,
        -262959893, 1271713904, 1423681694, 1293624693, -1305406402, 1983816160,
        -602816690, 636278554, -285245562, 1031662866, -1041976064, 1221694281,
        1036815507, 775893260, -329355129, 2117211184, -1042390616, -1667265438,
        -898081380, -1267247536, 350100475, -274080837, -787042507, -1696865897,
        -1387511711, 1901132483, -1617847332, -574996782, 1169511062, -1266106154,
        -1377975054, 886997475, 1936501508, 610256856, 1804593020, -1905652203,
        2470511, -1005727867, 1929440211, -590227673, -279703229, 706203603,
        -1226654727, -313259746, -367168072, 1991621063, 1145227353, 1527084472,
        1946327170, 976641588, -593457329, 1262164851, 536919806, -724913398,
        -37875204, 258104717, 1274804496, 1597665303, -2133417899, -943891161,
        -1809571159, -1625703283, 1517736440, -1509154451, -693132475, -1369880946,
        539566709, -1081335485, -445068262, 1299817544, 66523468, 124787444,
        1598834669, 966418260, 1947806010, 1749008611, -630275010, 458453080,
        281153830, 42081460, -90108678, -2122914678, 1471226731, 765141292,
        1305415261, 173790065, 135028740, 1372565859, 1111220101, -688011628,
        188985281, -886310806, 1335714585, 834697453, 1253364275, -1310914542,
        -1023331176, -276524767, -166639526, 2107657444, 1812712970, 787163418,
        -661825463, 1603294144, -1036501021, 869642051, -184821200, 1700234797,
        -1377139506, -1276109918, -1386423483, -1405375965, 45121961, 943998860,
        1056170594, -873881483, 881979872, 1157695860, 1859948183, -1688366042,
        149553684, 1017355491, -920505696, 1628286919, -704461521, -1725465949,
        -1490034522, 1136457806, 1871261290, 1659037747, 165972019, -483649675,
        -1512794226, 146172383, 1417317522, 1284188544, -1986089134, 913995529,
        -1737485501, 1713084298, 928528900, -2071756699, 2094371528, 192248329,
        483041556, 207032563, -1984361543, -487373767, 227706189, -1403908542,
        -1792518688, 82084523, -2116397290, 1524580507, 1289178060, -947895270,
        -1892843345, 366542865, 241205019, -946313953, -889100155, -559257162,
        979670262, -1452136643, -744260705, 1060557512, -362403544, -592147003,
        352816221, 1128622296, 979982112, 1756640181, 1557076971, 1913538153,
        1978008114, 295117400, 728046625, 124419381, -1906713208, -1631536545,
        -843384101, 1470738186, -1632348233, 1503442953, 31909846, -1227807056,
        1049849921, 1252084553, -995906750, -2112989134, 722810050, -1710969071,
        1499112197, 929504930, 37622013, 808313916, 276427301, 539464064,
        -1501864740, -1070814495, 1713296185, 1903066940, -792399058, 2123794495,
        -1928361302, -315113250, 1283988553, 416759610, 840395410, 1916362667,
        292362182, -433293752, -1235304557, 508853087, -248246131, 48202231,
        1532041436, 1993833091, -985843618, 134065217, -1888436787, -450377159,
        1344880374, -24447296, 885025861, 789267456, 1615859164, -820186598,
        -1497301564, 1380057301, 1234648758, 1802272784, -195226224, 970924250,
        127732144, 414622870, 1373125779,
        GetHashKey("MP006_A3SUPP_MOONSHINE01"), GetHashKey("MP006_A3SUPP_MOONSHINE01_PLUG"),
        GetHashKey("MP006_A2SUPP_MOONSHINE02"), GetHashKey("MP006_A2SUPP_MOONSHINE02_PLUG"),
        GetHashKey("MP006_A4SUPP_MOONSHINE03"), GetHashKey("MP006_A4SUPP_MOONSHINE03_PLUG"),
        GetHashKey("MP006_A1SUPP_MOONSHINE04"), GetHashKey("MP006_A1SUPP_MOONSHINE04_PLUG"),
        GetHashKey("MP006_A4SUPP_MOONSHINE05"), GetHashKey("MP006_A4SUPP_MOONSHINE05_PLUG")
    },

    -- Отключаемые IMAP (Заколоченные доски, строительный мусор, леса, баррикады, ямы)
    Disable = {
        -928815382, 774477221, -391187090, -1902184438, 1886602884, 740012805,
        1236921921, 1963724330, -1871745961, 2125514970, 267578156, 611701601,
        901412334, 703356498, -650822431, 2006257967, -2008632686, -1615103170,
        -692583342, -669282002, -1355464862, -1141450523, -252820785, 258899919,
        -767883927, -535715562, 2030594491, -790660125, 33260939, 780653384,
        180676027, -270212770, -211623797, 862349416, 699225334, -706105482,
        176369335, 637627640, 44077654, 839872819, -1656895602, -583969090,
        -364121869, -1073832871, -1786558629, -1548753996, -1784133719, -1667461262,
        203845253, -1658679165, 258733332, 79028136, 634752926, 984271748,
        43335376, 1444950942, 910783469, 727408145, 429636242, -19364596,
        2131035495, -316448350, -496874464, -794515291, 275588949, -52330434,
        -2131457946, 1819926822, 1529593482, -668911501, -1012618146, 2111816145,
        -722030448, -974480336, 197447134, 1256771838, 1205945639, 1532774697,
        -114633341, -90646166, 1681117196, -803019223, 449426161, -999913940,
        -30541382, -960328988, 247969883, -1798259416, -2093605706, -1675593451,
        -2082201137, 1343343014, 739412171, -5339556, 1258244391, 1649548630,
        1173561253, 1641449717
    }
}

-- ==============================================================================
-- 2. ИНТЕРЬЕРЫ И НАБОРЫ СУЩНОСТЕЙ (Interior Entity Sets)
-- Полноценная меблировка, открытые двери, наполнение полок товарами, свет
-- ==============================================================================

Config.Interiors = {
    -- --------------------------------------------------------------------------
    -- ВАЛЕНТАЙН (Valentine)
    -- --------------------------------------------------------------------------
    {
        id = 12290,
        name = "Valentine Bank",
        coords = vector3(-308.2, 773.5, 118.7),
        sets = {
            "val_bank_front_windows",
            "val_bank_int_curtainsopen",
            "val_bank_int_vaults_dynamite"
        }
    },
    {
        id = 21250,
        name = "Valentine Smithfields Saloon",
        coords = vector3(-228.6, 804.8, 119.0),
        sets = {
            "front_windows",
            "val_saloon_br03_bed",
            "6_chair_poker_set"
        }
    },
    {
        id = 7170,
        name = "Valentine Sheriff Office",
        coords = vector3(-277.2, 805.0, 119.3),
        sets = {
            "val_jail_int_walla",
            "val_jail_int_wallb"
        }
    },
    {
        id = 45826,
        name = "Valentine General Store",
        coords = vector3(-323.0, 803.9, 117.9),
        sets = {
            "val_genstore_night_light",
            "_p_apple01x_dressing", "_p_apple01x_group",
            "_p_bread06x_dressing", "_p_bread06x_group",
            "_p_carrots_01x_dressing", "_p_carrots_01x_group",
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_corn02x_dressing", "_p_corn02x_group",
            "_p_int_fishing01_dressing",
            "_p_package01x_dressing", "_p_package01x_group",
            "_p_pear_02x_dressing", "_p_pear_02x_group",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_p_tin_soap01x_dressing", "_p_tin_soap01x_group",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_canBeans01x_group", "_s_canBeans01_dressing",
            "_s_canCorn01x_dressing", "_s_canCorn01x_group",
            "_s_candyBag01x_red_group",
            "_s_canPeaches01x_dressing", "_s_canPeaches01x_group",
            "_s_cheeseWedge1x_group",
            "_s_chocolateBar02x_dressing", "_s_chocolateBar02x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_cricketTin01x_dressing", "_s_cricketTin01x_group",
            "_s_gunOil01x_dressing", "_s_gunOil01x_group",
            "_s_inv_baitHerb01x_dressing", "_s_inv_baitherb01x_group",
            "_s_inv_baitMeat01x_dressing", "_s_inv_baitmeat01x_group",
            "_s_inv_gin01x_dressing", "_s_inv_gin01x_group",
            "_s_inv_horsePills01x_dressing", "_s_inv_horsePills01x_group",
            "_s_inv_pocketwatch04x_dressing", "_s_inv_pocketWatch04x_group",
            "_s_inv_rum01x_dressing", "_s_inv_rum01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_oatcakes01x_dressing", "_s_oatcakes01x_group",
            "_s_offal01x_dressing", "_s_offal01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group",
            "_s_wormCan01x_dressing", "_s_wormcan01x_group"
        }
    },
    {
        id = 63746,
        name = "Valentine Gun Store",
        coords = vector3(-281.8, 779.6, 119.5),
        sets = {
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_highvlcty_pstAmmo01x_group",
            "_s_inv_pistolAmmo01x_group",
            "_s_inv_pistol_sign_dressing",
            "_s_inv_repeater_sign_dressing",
            "_s_inv_repeatHV_rifleammo01x_group",
            "_s_inv_repeat_rifleammo01x_group",
            "_s_inv_revolverAmmo01x_group",
            "_s_inv_revolver_sign_dressing",
            "_s_inv_rifleAmmo01x_group",
            "_s_inv_rifle_sign_dressing",
            "_s_inv_shotgunAmmo01x_group",
            "_s_inv_shotgun_sign_dressing",
            "_s_inv_slug_shotgunAmmo01x_group",
            "_s_inv_varmint_rifleammo01x_group"
        }
    },

    -- --------------------------------------------------------------------------
    -- БИЧЕРС-ХОУП (Beecher's Hope - Особняк и ранчо Джона Марстона)
    -- --------------------------------------------------------------------------
    {
        id = 50690,
        name = "Beechers Hope Main House",
        coords = vector3(-1658.0, -1445.0, 83.5),
        sets = {
            "bee_01_masterBR_bed01",
            "Beechers_decorated_after_Abigail3",
            "IntGrp_livingrm_furniture_basic",
            "bee_01_house_fireplace_on",
            "BEECHERS_PIANO_STOOL",
            "bee_01_house_chair",
            "Beechers_fully_decorated_finale",
            "Beechers_after_Marston8_Abigail2.2"
        }
    },

    -- --------------------------------------------------------------------------
    -- РОУДС (Rhodes)
    -- --------------------------------------------------------------------------
    {
        id = 258,
        name = "Rhodes General Store",
        coords = vector3(1329.0, -1294.0, 77.0),
        sets = {
            "_FIN2_EXT_P19_FRAMES_ON",
            "_p_apple01x_dressing", "_p_apple01x_group",
            "_p_bread06x_dressing", "_p_bread06x_group",
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_corn02x_dressing", "_p_corn02x_group",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_s_beardTonic01x_dressing", "_s_beardTonic01x_group",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_brandy01x_group",
            "_s_candyBag01x_red_group",
            "_s_canPeas01x_dressing", "_s_canPeas01x_group",
            "_s_canPineapple01x_dressing", "_s_canPineapple01x_group",
            "_s_canStrawberries01x_dressing", "_s_canStrawberries01x_group",
            "_s_cheeseWedge1x_dressing", "_s_cheeseWedge1x_group",
            "_s_chocolateBar02x_dressing", "_s_chocolateBar02x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_cornedBeef01x_dressing", "_s_cornedBeef01x_group",
            "_s_inv_horsePills01x_dressing", "_s_inv_horsePills01x_group",
            "_s_inv_rum01x_dressing", "_s_inv_rum01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_oatcakes01x_dressing", "_s_oatcakes01x_group",
            "_s_peach01x_dressing", "_s_peach01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group"
        }
    },
    {
        id = 8962,
        name = "Rhodes Gun Store",
        coords = vector3(1331.0, -1376.0, 80.0),
        sets = {
            "p_fireplacelogs02x",
            "rhoGunsmith_FireON",
            "RHO_GUN_REGISTER",
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_highvlcty_pstAmmo01x_group",
            "_s_inv_highvlcty_revAmmo01x_group",
            "_s_inv_highvlcty_rifleAmmo01x_group",
            "_s_inv_pistolAmmo01x_group",
            "_s_inv_pistol_sign_dressing",
            "_s_inv_repeater_sign_dressing",
            "_s_inv_repeatHV_rifleammo01x_group",
            "_s_inv_repeat_rifleammo01x_group",
            "_s_inv_revolverAmmo01x_group",
            "_s_inv_revolver_sign_dressing",
            "_s_inv_rifleAmmo01x_group",
            "_s_inv_rifle_sign_dressing",
            "_s_inv_shotgunAmmo01x_group",
            "_s_inv_shotgun_sign_dressing",
            "_s_inv_slug_shotgunAmmo01x_group",
            "_s_inv_varmint_rifleammo01x_group"
        }
    },
    {
        id = 29442,
        name = "Rhodes Bank",
        coords = vector3(1294.0, -1303.0, 77.0),
        sets = {
            "rhobank_int_walla"
        }
    },
    {
        id = 69122,
        name = "Trelawny Caravan",
        coords = vector3(1423.0, -1451.0, 77.0),
        sets = {
            "rho_slum_player_trelawny01_stage_01"
        }
    },

    -- --------------------------------------------------------------------------
    -- СЕН-ДЕНИ (Saint Denis)
    -- --------------------------------------------------------------------------
    {
        id = 42754,
        name = "Saint Denis Bank",
        coords = vector3(2628.0, -1299.0, 52.0),
        sets = {
            "new_com_bank_before",
            "new_com_bank_int_des",
            "new_com_bank_vaults_without_rayfire"
        }
    },
    {
        id = 2050,
        name = "Saint Denis Gun Store",
        coords = vector3(2847.0, -1211.0, 47.0),
        sets = {
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_highvlcty_pstAmmo01x_group",
            "_s_inv_highvlcty_revAmmo01x_group",
            "_s_inv_highvlcty_rifleAmmo01x_group",
            "_s_inv_pistolAmmo01x_dressing",
            "_s_inv_pistolAmmo01x_group",
            "_s_inv_revolverAmmo01x_dressing",
            "_s_inv_revolverAmmo01x_group",
            "_s_inv_rifleAmmo01x_dressing",
            "_s_inv_rifleAmmo01x_group",
            "_s_inv_shotgunAmmo01x_dressing",
            "_s_inv_shotgunAmmo01x_group",
            "_s_inv_slug_shotgunAmmo01x_group",
            "_s_inv_varmint_rifleammo01x_group"
        }
    },
    {
        id = 3074,
        name = "Saint Denis General Store",
        coords = vector3(2823.0, -1319.0, 46.0),
        sets = {
            "_p_bread06x_dressing", "_p_bread06x_group",
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_brandy01x_group",
            "_s_candyBag01x_red_group",
            "_s_cheeseWedge1x_dressing", "_s_cheeseWedge1x_group",
            "_s_chocolateBar02x_dressing", "_s_chocolateBar02x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_inv_gin01x_dressing", "_s_inv_gin01x_group",
            "_s_inv_rum01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group"
        }
    },
    {
        id = 34562,
        name = "Saint Denis Doctor",
        coords = vector3(2725.0, -1231.0, 50.0),
        sets = {
            "SD_doc_curtain01",
            "_s_candyBag01x_red_group",
            "_s_chocolateBar02x_dressing", "_s_chocolateBar02x_group",
            "_s_inv_CocaineGum01x_dressing", "_s_inv_CocaineGum01x_group",
            "_s_inv_medicine01x_dressing", "_s_inv_medicine01x_group",
            "_s_inv_medicine_fty_dressing", "_s_inv_medicine_fty_group",
            "_s_inv_supertonic01x_dressing", "_s_inv_supertonic01x_group",
            "_s_inv_tonic01x_dressing", "_s_inv_tonic01x_group"
        }
    },
    {
        id = 26626,
        name = "Saint Denis Art Galerie",
        coords = vector3(2572.0, -1286.0, 52.0),
        sets = {
            "new_art_photos_pre_RC_Mason",
            "new_forMyArt_paintings"
        }
    },
    {
        id = 49154,
        name = "Angelo Bronte Villa",
        coords = vector3(2644.0, -1257.0, 52.0),
        sets = {
            "bronte_shutters_open",
            "bronte_glass_unbreakable"
        }
    },
    {
        id = 51202,
        name = "Riverboat Poker Salon",
        coords = vector3(2900.0, -1450.0, 42.0),
        sets = {
            "korrigan_props_poker"
        }
    },

    -- --------------------------------------------------------------------------
    -- БЛЭКУОТЕР (Blackwater)
    -- --------------------------------------------------------------------------
    {
        id = 61442,
        name = "Blackwater General Store",
        coords = vector3(-785.0, -1322.0, 43.8),
        sets = {
            "_p_apple01x_dressing",
            "_p_carrots_01x_dressing", "_p_carrots_01x_group",
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_int_fishing01_dressing",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_p_tin_soap01x_dressing", "_p_tin_soap01x_group",
            "_s_beardTonic01x_dressing", "_s_beardTonic01x_group",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_brandy01x_group",
            "_s_canApricots01x_dressing", "_s_canApricots01x_group",
            "_s_candyBag01x_red_group",
            "_s_canKidney01x_dressing", "_s_cankidney01x_group",
            "_s_canPeas01x_dressing", "_s_canPeas01x_group",
            "_s_cheeseWedge1x_group",
            "_s_chocolateBar02x_dressing", "_s_chocolateBar02x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_cornedBeef01x_dressing", "_s_cornedBeef01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_cricketTin01x_dressing", "_s_cricketTin01x_group",
            "_s_gunOil01x_dressing", "_s_gunOil01x_group",
            "_s_inv_baitHerb01x_dressing", "_s_inv_baitherb01x_group",
            "_s_inv_baitMeat01x_dressing", "_s_inv_baitmeat01x_group",
            "_s_inv_gin01x_dressing", "_s_inv_gin01x_group",
            "_s_inv_horsePills01x_dressing", "_s_inv_horsePills01x_group",
            "_s_inv_rum01x_dressing", "_s_inv_rum01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_oatcakes01x_dressing", "_s_oatcakes01x_group",
            "_s_peach01x_dressing", "_s_peach01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group",
            "_s_wormCan01x_dressing", "_s_wormcan01x_group"
        }
    },

    -- --------------------------------------------------------------------------
    -- СТРОБЕРРИ (Strawberry)
    -- --------------------------------------------------------------------------
    {
        id = 21506,
        name = "Strawberry General Store",
        coords = vector3(-1802.0, -363.0, 162.0),
        sets = {
            "_p_apple01x_dressing", "_p_apple01x_group",
            "_p_carrots_01x_dressing", "_p_carrots_01x_group",
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_int_fishing01_dressing",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_p_tin_soap01x_dressing", "_p_tin_soap01x_group",
            "_saltedmeats_dressing",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_canBeans01x_dressing", "_s_canBeans01x_group",
            "_s_canCorn01x_dressing", "_s_canCorn01x_group",
            "_s_canPeaches01x_dressing", "_s_canPeaches01x_group",
            "_s_canPeas01x_dressing", "_s_canPeas01x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_cricketTin01x_dressing", "_s_cricketTin01x_group",
            "_s_inv_baitHerb01x_dressing", "_s_inv_baitherb01x_group",
            "_s_inv_baitMeat01x_dressing", "_s_inv_baitmeat01x_group",
            "_s_inv_gin01x_dressing", "_s_inv_gin01x_group",
            "_s_inv_horsePills01x_dressing", "_s_inv_horsePills01x_group",
            "_s_inv_pocketwatch04x_dressing", "_s_inv_pocketWatch04x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_oatcakes01x_dressing", "_s_oatcakes01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group",
            "_s_wormCan01x_dressing", "_s_wormcan01x_group"
        }
    },

    -- --------------------------------------------------------------------------
    -- ТАМБЛВИД И АРМАДИЛЛО (Tumbleweed & Armadillo)
    -- --------------------------------------------------------------------------
    {
        id = 514,
        name = "Tumbleweed General Store",
        coords = vector3(-5519.0, -2975.0, -1.0),
        sets = {
            "_p_apple01x_dressing", "_p_apple01x_group",
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_corn02x_dressing", "_p_corn02x_group",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_p_tin_soap01x_dressing", "_p_tin_soap01x_group",
            "_saltedmeats_dressing",
            "_s_canCorn01x_dressing", "_s_canCorn01x_group",
            "_s_canPeas01x_dressing", "_s_canPeas01x_group",
            "_s_canStrawberries01x_dressing", "_s_canStrawberries01x_group",
            "_s_coffeeTin01x_dressing", "_s_coffeeTin01x_group",
            "_s_gunOil01x_dressing", "_s_gunOil01x_group",
            "_s_inv_baitHerb01x_dressing", "_s_inv_baitherb01x_group",
            "_s_inv_baitMeat01x_dressing", "_s_inv_baitmeat01x_group",
            "_s_inv_gin01x_dressing", "_s_inv_gin01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_oatcakes01x_dressing", "_s_oatcakes01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group"
        }
    },
    {
        id = 11778,
        name = "Tumbleweed Gun Store",
        coords = vector3(-5509.0, -2965.0, -1.0),
        sets = {
            "tum_gunsmith_int_rentSign",
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_highvlcty_pstAmmo01x_group",
            "_s_inv_highvlcty_revAmmo01x_group",
            "_s_inv_highvlcty_rifleAmmo01x_group",
            "_s_inv_pistolAmmo01x_group",
            "_s_inv_pistol_sign_dressing",
            "_s_inv_repeater_sign_dressing",
            "_s_inv_repeatHV_rifleammo01x_group",
            "_s_inv_repeatXS_rifleammo01x_group",
            "_s_inv_repeat_rifleammo01x_group",
            "_s_inv_revolverAmmo01x_group",
            "_s_inv_revolver_sign_dressing",
            "_s_inv_rifleAmmo01x_group",
            "_s_inv_rifle_sign_dressing",
            "_s_inv_shotgunAmmo01x_group",
            "_s_inv_shotgun_sign_dressing",
            "_s_inv_slug_shotgunAmmo01x_group",
            "_s_inv_varmint_rifleammo01x_group",
            "_s_inv_xpres_pstAmmo01x_group",
            "_s_inv_xpres_revAmmo01x_group",
            "_s_inv_xpres_rifleAmmo01x_group"
        }
    },
    {
        id = 3842,
        name = "Armadillo General Store",
        coords = vector3(-3686.0, -2622.0, -13.0),
        sets = {
            "_p_cigar02x_dressing", "_p_cigar02x_group",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_baitHerb01x_dressing", "_s_inv_baitherb01x_group",
            "_s_inv_baitMeat01x_dressing", "_s_inv_baitmeat01x_group",
            "_s_inv_pistolAmmo01x_dressing", "_s_inv_pistolAmmo01x_group",
            "_s_inv_revolverAmmo01x_dressing", "_s_inv_revolverAmmo01x_group",
            "_s_inv_rifleAmmo01x_dressing", "_s_inv_rifleAmmo01x_group",
            "_s_inv_shotgunAmmo01x_dressing", "_s_inv_shotgunAmmo01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group"
        }
    },

    -- --------------------------------------------------------------------------
    -- АННЕСБЕРГ И СТАНЦИЯ УОЛЛЕС (Annesburg & Wallace Station)
    -- --------------------------------------------------------------------------
    {
        id = 2818,
        name = "Annesburg Gun Store",
        coords = vector3(2945.0, 1318.0, 44.0),
        sets = {
            "ann_gunsmith_int_rent",
            "_sign_pistolAmmo_dressing",
            "_sign_revolverAmmo_dressing",
            "_sign_rifleAmmo_dressing",
            "_sign_shotgunAmmo_dressing",
            "_s_inv_arrowammo01x_dressing",
            "_s_inv_highvlcty_pstAmmo01x_group",
            "_s_inv_highvlcty_revAmmo01x_group",
            "_s_inv_highvlcty_rifleAmmo01x_group",
            "_s_inv_pistolAmmo01x_group",
            "_s_inv_repeatHV_rifleammo01x_group",
            "_s_inv_repeat_rifleammo01x_dressing",
            "_s_inv_repeat_rifleammo01x_group",
            "_s_inv_revolverAmmo01x_group",
            "_s_inv_rifleAmmo01x_group",
            "_s_inv_shotgunAmmo01x_group",
            "_s_inv_slug_shotgunAmmo01x_group",
            "_s_inv_varmint_rifleammo01x_group"
        }
    },
    {
        id = 65282,
        name = "Wallace Station General Store",
        coords = vector3(-1147.0, 396.0, 94.0),
        sets = {
            "_p_cigarettebox01x_dressing", "_p_cigarettebox01x_group",
            "_p_tin_pomade01x_dressing", "_p_tin_pomade01x_group",
            "_saltedmeats_dressing",
            "_s_biscuits01x_dressing", "_s_biscuits01x_group",
            "_s_crackers01x_dressing", "_s_crackers01x_group",
            "_s_gunOil01x_dressing", "_s_gunOil01x_group",
            "_s_inv_CocaineGum01x_dressing", "_s_inv_CocaineGum01x_group",
            "_s_inv_tabacco01x_dressing", "_s_inv_tabacco01x_group",
            "_s_inv_whiskey01x_dressing", "_s_inv_whiskey01x_group",
            "_s_saltedbeef01x_group", "_s_saltedbeef02x_group"
        }
    },

    -- --------------------------------------------------------------------------
    -- УСАДЬБЫ, РАНЧО И ОСОБНЯКИ МИРА
    -- --------------------------------------------------------------------------
    {
        id = 72706,
        name = "Braithwaite Mansion",
        coords = vector3(1015.0, -1645.0, 46.0),
        sets = {
            "bra_mansion_WindowsStatic",
            "bra_int_bedroom_clean"
        }
    },
    {
        id = 14338,
        name = "Aberdeen Pig Farm",
        coords = vector3(1682.0, 442.0, 109.0),
        sets = {
            "abe_farmhouse_chest",
            "clean_abe",
            "abe_SP_armoir",
            "ABE_WORKROOM",
            "p_lamphanging04x",
            "p_washbasinset01x"
        }
    },
    {
        id = 45314,
        name = "Emerald Ranch Saloon",
        coords = vector3(1279.0, 372.0, 90.0),
        sets = {
            "eme_saloon_intgroup_curtains",
            "eme_saloon_intgroup_furniture"
        }
    },
    {
        id = 28418,
        name = "Carmody Dell",
        coords = vector3(528.0, 680.0, 116.0),
        sets = {
            "_car_house_int_before_ransack",
            "_car_house_int_day"
        }
    },
    {
        id = 39938,
        name = "Geddes Ranch Worker Quarters",
        coords = vector3(-2585.0, 442.0, 147.0),
        sets = {
            "pro_int_shaving",
            "pro_worker_bedmade",
            "pro_worker_food",
            "pro_worker_jack_bed_ambient"
        }
    },
    {
        id = 24834,
        name = "Shady Belle Mansion",
        coords = vector3(1826.0, -1862.0, 42.0),
        sets = {
            "shb_arthurpickup_bookforage",
            "shb_arthurpickup_bookhunting",
            "shb_p_ammo01",
            "shb_p_ammo02",
            "shb_p_ammo03",
            "shb_p_industry_outro",
            "shb_p_mansion_01",
            "shb_p_mansion_fasttravel",
            "shb_p_mansion_pulp_eden",
            "shb_p_mansion_pulp_inferno",
            "shb_upg_arthur_chest",
            "shb_upg_arthur_rug",
            "shb_upg_arthur_table",
            "shb_upg_john_rug",
            "shb_upg_skull_gator",
            "shb_upg_skull_ram"
        }
    },
    {
        id = 72450,
        name = "Willards Rest Cabin",
        coords = vector3(2725.0, 2197.0, 109.0),
        sets = {
            "rocky_int_clean"
        }
    },
    {
        id = 2,
        name = "Chez Porter Main Cabin",
        coords = vector3(-489.0, 2217.0, 240.0),
        sets = {
            "che_cabin_int_roof_intact",
            "che_maincabin_occupied"
        }
    },
    {
        id = 9986,
        name = "Downes Home",
        coords = vector3(-46.0, 185.0, 105.0),
        sets = {
            "IntGroup_Downes_before_move",
            "IntGroup_Downes_pulp_novel"
        }
    }
}

-- ==============================================================================
-- 3. ПОДЗЕМНЫЕ ХИЖИНЫ САМОГОНЩИКОВ (Moonshine Shacks)
-- ==============================================================================

Config.MoonshineInteriors = {
    {
        name = "Heartlands Moonshine Shack",
        interior = 142850,
        coords = vector3(178.6, -781.5, 42.0),
        sets = {
            "bar_standard", "expansion", "deco_floral", "band_expansion", "band_ambient"
        }
    },
    {
        name = "Tall Trees Moonshine Shack",
        interior = 142082,
        coords = vector3(-1967.5, -1659.8, 114.5),
        sets = {
            "bar_standard", "expansion", "deco_floral", "band_expansion", "band_ambient"
        }
    },
    {
        name = "Bayou Nwa Moonshine Shack",
        interior = 143106,
        coords = vector3(1580.4, -685.2, 67.8),
        sets = {
            "bar_standard", "expansion", "deco_floral", "band_expansion", "band_ambient"
        }
    },
    {
        name = "Hennigan's Stead Moonshine Shack",
        interior = 143362,
        coords = vector3(-1182.2, -2020.9, 44.5),
        sets = {
            "bar_standard", "expansion", "deco_floral", "band_expansion", "band_ambient"
        }
    },
    {
        name = "Grizzlies Moonshine Shack",
        interior = 142594,
        coords = vector3(-1107.5, 1494.5, 314.5),
        sets = {
            "bar_standard", "expansion", "deco_floral", "band_expansion", "band_ambient"
        }
    }
}