Config = {}

Config.Debug = false

Config.DevMenu = {
    command = "jarvisshozahuynya",
    title = "Magic Cards",
    giveAmount = 1,
}

Config.Spells = {
    spark = {
        item = "magic_spark_scroll",
        label = "Таро — Терновый пленник",
        description = "На карте изображён человек, окутанный терновым кустом. Заклинание опутывает цель живой природной силой терновника.",
        cooldownMs = 8000,
        consumeItem = true,
        notify = "Вы поднимаете карту «Терновый пленник»...",
        failBusy = "Вы уже творите заклинание.",
        failCooldown = "Сила карты ещё не готова.",

        -- Page of the minor arcana. Suit is picked each time you draw.
        -- These props are authored for PH_L_Hand at identity (the in-game card grip).
        card = {
            image = "card.png",
            props = {
                "mp005_s_cardT_PaC", -- page of cups
                "mp005_s_cardT_PaP", -- page of pentacles
                "mp005_s_cardT_PaS", -- page of swords
                "mp005_s_cardT_PaW", -- page of wands
            },
            bones = { "PH_L_Hand", "skel_l_hand", "SKEL_L_Hand" },
            pos = { x = 0.0, y = 0.0, z = 0.0 },
            rot = { x = 0.0, y = 0.0, z = 0.0 },
        },

        ritual = {
            seeMs = 500,
            burnMs = 1500,
        },

        thorns = {
            range = 20.0,
            radius = 4.0,
            durationMs = 30000,
            growMs = 350,
            maxHeightDiff = 2.5,
            bushes = {
                "p_tumbleweed01x",
                "p_tumbleweed02x",
                "p_tumbleweed03x",
                "rdr_bush_dry_thin_aa_sim",
                "rdr_bush_brush_dead_aa_sim",
            },
            bind = {
                dict = "mech_loco_m@generic@handcuffed@unarmed@idle",
                clip = "idle",
                flag = 1,
                fallback = {
                    dict = "mech_loco@generic@handcuffed",
                    clip = "idle",
                    flag = 1,
                },
            },
        },

        -- Card-template hand pose (same family as the page props). Upper body only.
        hold = {
            dict = "mech_inventory@item@_templates@card@w6-5_h10-7@unarmed@base",
            clip = "base",
            clips = { "base", "hold", "idle" },
            flag = 25,
            fallback = {
                dict = "mech_inspection@generic@lh@base",
                clip = "hold",
                flag = 25,
            },
        },
        notifyCancel = "Вы убираете карту...",
        failAim = "Сюда нельзя.",
        cancelHint = "ЛКМ — каст  |  ПКМ — убрать карту",
    },

    necro = {
        item = "magic_necro_scroll",
        label = "Таро — Некромант",
        description = "На карте изображён злой мужик и скелеты. Заклинание поднимает труп, который служит пять минут.",
        cooldownMs = 12000,
        consumeItem = true,
        notify = "Вы поднимаете карту «Некромант»...",
        failBusy = "Вы уже творите заклинание.",
        failCooldown = "Сила карты ещё не готова.",
        failNoCorpse = "Здесь нет трупа.",
        failNoTarget = "Некого атаковать.",
        failControl = "Этот труп не поддаётся.",
        failServant = "Пока слуга жив, карту нельзя использовать.",
        notifyRaised = "Труп поднимается.",
        notifyFollow = "Слуга идёт за вами.",
        notifyAttack = "Слуга бросается на цель.",
        notifyExpired = "Слуга снова падает замертво.",
        notifyDied = "Ваш подопечный умер.",
        notifyRelease = "Вы отпускаете слугу.",
        notifyChoice = "G — следовать  |  E — атаковать  |  F — отпустить",
        cancelHint = "ЛКМ — поднять труп  |  ПКМ — убрать карту",
        notifyCancel = "Вы убираете карту...",
        failAim = "Сюда нельзя.",

        card = {
            image = "necro.png",
            props = {
                "mp005_s_cardT_KiS",
                "mp005_s_cardT_KnS",
                "mp005_s_cardT_PaS",
            },
            bones = { "PH_L_Hand", "skel_l_hand", "SKEL_L_Hand" },
            pos = { x = 0.0, y = 0.0, z = 0.0 },
            rot = { x = 0.0, y = 0.0, z = 0.0 },
        },

        ritual = {
            seeMs = 400,
            burnMs = 1500,
        },

        hold = {
            dict = "mech_inventory@item@_templates@card@w6-5_h10-7@unarmed@base",
            clip = "base",
            clips = { "base", "hold", "idle" },
            flag = 25,
            fallback = {
                dict = "mech_inspection@generic@lh@base",
                clip = "hold",
                flag = 25,
            },
        },

        necro = {
            range = 12.0,
            aimRadius = 1.8,
            lifeMs = 300000,
            health = 280,
            followOffset = 1.8,
            followSpeed = 2.6,
            point = {
                dict = "ai_gestures@gen_male@standing@speaker",
                clip = "neutral_point_l_v1",
                flag = 25,
            },
            followEmote = "KIT_EMOTE_ACTION_BECKON_1",
            attackEmote = "KIT_EMOTE_ACTION_POINT_1",
            releaseEmote = "KIT_EMOTE_GREET_WAVENEAR_1",
            followAnim = {
                dict = "ai_gestures@gen_male@standing@speaker",
                clip = "neutral_come_here_l_v1",
                flag = 25,
                durationMs = 1600,
            },
            getup = {
                {
                    dict = "ai_getup@directional@transition@prone_to_seated@drunk",
                    clip = "back",
                    duration = 3000,
                },
                {
                    dict = "ai_getup@directional@moving@from_seated@drunk",
                    clip = "getup_l_0",
                    duration = 2800,
                },
            },
        },
    },

    raven = {
        item = "magic_voron_scroll",
        label = "Таро — Вороний глаз",
        description = "На карте изображены глаз и ворона. Ненадолго смотришь на окрестности глазами призванного ворона. Тело заклинателя в это время беззащитно.",
        cooldownMs = 15000,
        consumeItem = true,
        notify = "Вы поднимаете карту «Вороний глаз»...",
        failBusy = "Вы уже творите заклинание.",
        failCooldown = "Сила карты ещё не готова.",
        failMounted = "Сначала спешьтесь.",
        failBird = "Ворон не откликнулся.",
        notifySummon = "Взгляд переходит к ворону.",
        notifyReturn = "Вы снова в своём теле.",
        notifyLost = "Ворон рассеялся.",
        notifyWeak = "Связь слабеет.",
        failPlace = "Ворону негде взлететь.",
        failTakeoff = "Ворон не смог подняться.",
        card = {
            image = "voron.png",
            props = {
                "mp005_s_cardT_PaC",
                "mp005_s_cardT_PaP",
                "mp005_s_cardT_PaS",
                "mp005_s_cardT_PaW",
            },
            bones = { "PH_L_Hand", "skel_l_hand", "SKEL_L_Hand" },
            pos = { x = 0.0, y = 0.0, z = 0.0 },
            rot = { x = 0.0, y = 0.0, z = 0.0 },
        },
        ritual = {
            seeMs = 500,
            burnMs = 1500,
        },
        hold = {
            dict = "mech_inventory@item@_templates@card@w6-5_h10-7@unarmed@base",
            clip = "base",
            clips = { "base", "hold", "idle" },
            flag = 25,
            fallback = {
                dict = "mech_inspection@generic@lh@base",
                clip = "hold",
                flag = 25,
            },
        },
        raven = {
            model = "a_c_raven_01",
            modelHash = 0xDDB5012B,
            lifeMs = 60000,
            spawnAhead = 2.5,
            warnDistance = 180.0,
            maxDistance = 220.0,
            maxHeight = 30.0,
            minClearance = 1.5,
            flightEveryMs = 200,
            leadDistance = 10.0,
            travelMbr = 1.0,
            fov = 75.0,
            modelTimeoutMs = 5000,
            takeoffTimeoutMs = 4000,
            camOffset = { x = 0.0, y = 0.30, z = 0.10 },
        },
        notifyCancel = "Вы убираете карту...",
        cancelHint = "ЛКМ — призвать ворона  |  ПКМ — убрать карту",
    },

    oath = {
        item = "magic_obet_scroll",
        label = "Таро — Кровавый обет",
        description = "На карте изображён кровавый обет. Пожертвуй частью здоровья, чтобы вернуть союзника из нока. Оставайся рядом до завершения обета.",
        cooldownMs = 90000,
        consumeItem = true,
        notify = "Вы поднимаете карту «Кровавый обет»...",
        failBusy = "Вы уже творите заклинание.",
        failCooldown = "Сила карты ещё не готова.",
        failTarget = "Рядом нет того, кого можно поднять из нока.",
        failBlood = "Недостаточно крови для возвращения.",
        failHealth = "Недостаточно здоровья для обета.",
        failRange = "Обет прервался: вы отошли слишком далеко.",
        failHurt = "Обет прервался.",
        failCancel = "Вы прервали обет.",
        notifyRaised = "Кровь принята. Союзник возвращается.",
        card = {
            image = "obet.png",
            props = {
                "mp005_s_cardT_PaC",
                "mp005_s_cardT_PaP",
                "mp005_s_cardT_PaS",
                "mp005_s_cardT_PaW",
            },
            bones = { "PH_L_Hand", "skel_l_hand", "SKEL_L_Hand" },
            pos = { x = 0.0, y = 0.0, z = 0.0 },
            rot = { x = 0.0, y = 0.0, z = 0.0 },
        },
        ritual = {
            seeMs = 500,
            burnMs = 1500,
        },
        hold = {
            dict = "mech_inventory@item@_templates@card@w6-5_h10-7@unarmed@base",
            clip = "base",
            clips = { "base", "hold", "idle" },
            flag = 25,
            fallback = {
                dict = "mech_inspection@generic@lh@base",
                clip = "hold",
                flag = 25,
            },
        },
        oath = {
            selectRange = 2.5,
            breakRange = 3.0,
            durationMs = 20000,
            transferRatio = 0.30,
            reserveRatio = 0.20,
            aliveFloor = 15,
            cancelCooldownMs = 2000,
            reach = {
                kneelDict = "amb_misc@world_human_grave_mourning@kneel@male_b@base",
                kneelClip = "base",
                dict = "amb_misc@world_human_pray_rosary@base",
                clip = "base",
                flag = 49,
            },
        },
        notifyCancel = "Вы убираете карту...",
        cancelHint = "ЛКМ — обет  |  ПКМ — убрать карту",
    },
}
