-- =================================================================
-- HUNT: Hard RP — Crafting System | Shared Recipes & Categories
-- =================================================================

Crafting = {}
Crafting.Categories = {
    survival = { id = "survival", label = "Выживание", icon = "survival", order = 1 },
    tools    = { id = "tools",    label = "Инструменты", icon = "tools",    order = 2 },
    items    = { id = "items",    label = "Предметы",   icon = "items",    order = 3 },
    medical  = { id = "medical",  label = "Медицина",  icon = "medical",  order = 4 },
    material = { id = "material", label = "Материалы", icon = "material", order = 5 }
}

Crafting.Recipes = {
    -- Полевые / Базовые рецепты
    bandage = {
        id = "bandage",
        label = "Бинт",
        resultItem = "bandage",
        resultCount = 1,
        category = "medical",
        station = "field",
        craftTime = 6,
        ingredients = {
            { item = "cloth", count = 2 }
        },
        requiredRecipeItem = nil
    },
    campfire = {
        id = "campfire",
        label = "Костёр",
        resultItem = "campfire",
        resultCount = 1,
        category = "survival",
        station = "field",
        craftTime = 10,
        ingredients = {
            { item = "twigs", count = 5 }
        },
        requiredRecipeItem = nil
    },
    torch = {
        id = "torch",
        label = "Факел",
        resultItem = "torch",
        resultCount = 1,
        category = "survival",
        station = "field",
        requiredTool = "hunting_knife",
        craftTime = 8,
        ingredients = {
            { item = "wood_log", count = 1 },
            { item = "cloth", count = 2 },
            { item = "animal_fat", count = 2 }
        },
        requiredRecipeItem = nil
    },
    corn_bait = {
        id = "corn_bait",
        label = "Наживка из кукурузы",
        resultItem = "corn_bait",
        resultCount = 3,
        category = "survival",
        station = "field",
        craftTime = 6,
        ingredients = {
            { item = "corn", count = 1 }
        },
        requiredRecipeItem = nil
    },

    -- Верстак (workbench)
    bandage_burdock = {
        id = "bandage_burdock",
        label = "Повязка с лопухом",
        resultItem = "bandage_burdock",
        resultCount = 1,
        category = "medical",
        station = "workbench",
        craftTime = 8,
        ingredients = {
            { item = "cloth", count = 1 },
            { item = "burdock_leaf", count = 2 }
        },
        requiredRecipeItem = nil
    },
    waterskin = {
        id = "waterskin",
        label = "Бурдюк",
        resultItem = "waterskin",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        requiredTool = "hunting_knife",
        craftTime = 12,
        ingredients = {
            { item = "leather", count = 4 },
            { item = "needle_thread", count = 1 },
            { item = "resin", count = 1 }
        },
        requiredRecipeItem = nil
    },
    fishing_rod = {
        id = "fishing_rod",
        label = "Удочка",
        resultItem = "fishing_rod",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        requiredTool = "hunting_knife",
        craftTime = 12,
        ingredients = {
            { item = "twigs", count = 6 },
            { item = "rope", count = 3 },
            { item = "iron_ingot", count = 1 }
        },
        requiredRecipeItem = nil
    },
    voodoo_doll = {
        id = "voodoo_doll",
        label = "Кукла вуду",
        resultItem = "voodoo_doll",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        requiredTool = "hunting_knife",
        craftTime = 15,
        ingredients = {
            { item = "cloth", count = 4 },
            { item = "needle_thread", count = 1 },
            { item = "animal_bone", count = 2 },
            { item = "raven_eye", count = 1 },
            { item = "resin", count = 2 }
        },
        requiredRecipeItem = nil
    },
    gunpowder = {
        id = "gunpowder",
        label = "Порох",
        resultItem = "gunpowder",
        resultCount = 4,
        category = "material",
        station = "workbench",
        craftTime = 12,
        ingredients = {
            { item = "saltpeter", count = 3 },
            { item = "sulfur_powder", count = 2 },
            { item = "charcoal", count = 1 }
        },
        requiredRecipeItem = nil
    },
    bag = {
        id = "bag",
        label = "Мешок",
        resultItem = "bag",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        requiredTool = "hunting_knife",
        craftTime = 14,
        ingredients = {
            { item = "cloth", count = 6 },
            { item = "rope", count = 4 },
            { item = "needle_thread", count = 2 }
        },
        requiredRecipeItem = nil
    },
    pouch = {
        id = "pouch",
        label = "Мешочек",
        resultItem = "pouch",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        requiredTool = "hunting_knife",
        craftTime = 10,
        ingredients = {
            { item = "cloth", count = 3 },
            { item = "rope", count = 3 },
            { item = "needle_thread", count = 1 }
        },
        requiredRecipeItem = nil
    },
    bag_large = {
        id = "bag_large",
        label = "Большой мешок",
        resultItem = "bag_large",
        resultCount = 1,
        category = "survival",
        station = "workbench",
        craftTime = 18,
        ingredients = {
            { item = "cloth", count = 10 },
            { item = "rope", count = 5 },
            { item = "needle_thread", count = 3 }
        },
        requiredRecipeItem = nil
    },
    wood_plank = {
        id = "wood_plank",
        label = "Доска",
        resultItem = "wood_plank",
        resultCount = 1,
        category = "material",
        station = "workbench",
        requiredTool = "saw",
        craftTime = 8,
        ingredients = {
            { item = "wood_log", count = 2 }
        },
        requiredRecipeItem = nil
    },
    salt = {
        id = "salt",
        label = "Соль",
        resultItem = "salt",
        resultCount = 4,
        category = "material",
        station = "workbench",
        requiredTool = "hammer",
        craftTime = 8,
        ingredients = {
            { item = "rock_salt", count = 1 }
        },
        requiredRecipeItem = nil
    },

    -- Плавильная печь (furnace)
    iron_ingot = {
        id = "iron_ingot",
        label = "Железный слиток",
        resultItem = "iron_ingot",
        resultCount = 1,
        category = "material",
        station = "furnace",
        craftTime = 12,
        ingredients = {
            { item = "iron_ore", count = 3 },
            { item = "charcoal", count = 2 }
        },
        requiredRecipeItem = nil
    },
    silver_ingot = {
        id = "silver_ingot",
        label = "Серебряный слиток",
        resultItem = "silver_ingot",
        resultCount = 1,
        category = "material",
        station = "furnace",
        craftTime = 15,
        ingredients = {
            { item = "silver_ore", count = 3 },
            { item = "charcoal", count = 2 }
        },
        requiredRecipeItem = nil
    },
    gold_ingot = {
        id = "gold_ingot",
        label = "Золотой слиток",
        resultItem = "gold_ingot",
        resultCount = 1,
        category = "material",
        station = "furnace",
        craftTime = 20,
        ingredients = {
            { item = "gold_ore", count = 6 },
            { item = "charcoal", count = 2 }
        },
        requiredRecipeItem = nil
    },
    sulfur_powder = {
        id = "sulfur_powder",
        label = "Серный порошок",
        resultItem = "sulfur_powder",
        resultCount = 1,
        category = "material",
        station = "furnace",
        craftTime = 10,
        ingredients = {
            { item = "sulfur_ore", count = 3 },
            { item = "charcoal", count = 2 }
        },
        requiredRecipeItem = nil
    },
    flask_glass = {
        id = "flask_glass",
        label = "Колба",
        resultItem = "flask_glass",
        resultCount = 2,
        category = "items",
        station = "furnace",
        craftTime = 10,
        ingredients = {
            { item = "glass", count = 4 }
        },
        requiredRecipeItem = nil
    },
    vial = {
        id = "vial",
        label = "Пузырёк",
        resultItem = "vial",
        resultCount = 3,
        category = "items",
        station = "furnace",
        craftTime = 8,
        ingredients = {
            { item = "glass", count = 4 }
        },
        requiredRecipeItem = nil
    },

    -- Наковальня (anvil)
    saw = {
        id = "saw",
        label = "Пила",
        resultItem = "saw",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 14,
        ingredients = {
            { item = "iron_ingot", count = 4 },
            { item = "wood_log", count = 2 },
            { item = "leather", count = 1 }
        },
        requiredRecipeItem = nil
    },
    hunting_knife = {
        id = "hunting_knife",
        label = "Охотничий нож",
        resultItem = "hunting_knife",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 10,
        ingredients = {
            { item = "iron_ingot", count = 2 },
            { item = "wood_log", count = 1 },
            { item = "leather", count = 1 }
        },
        requiredRecipeItem = nil
    },
    shovel = {
        id = "shovel",
        label = "Лопата",
        resultItem = "shovel",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 12,
        ingredients = {
            { item = "iron_ingot", count = 4 },
            { item = "wood_log", count = 2 },
            { item = "leather", count = 1 }
        },
        requiredRecipeItem = nil
    },
    key_ring = {
        id = "key_ring",
        label = "Связка ключей",
        resultItem = "key_ring",
        resultCount = 1,
        category = "items",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 10,
        ingredients = {
            { item = "iron_ingot", count = 4 }
        },
        requiredRecipeItem = nil
    },
    hammer = {
        id = "hammer",
        label = "Молоток",
        resultItem = "hammer",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "saw",
        craftTime = 12,
        ingredients = {
            { item = "iron_ingot", count = 4 },
            { item = "wood_log", count = 1 }
        },
        requiredRecipeItem = nil
    },
    axe = {
        id = "axe",
        label = "Топор",
        resultItem = "axe",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 14,
        ingredients = {
            { item = "iron_ingot", count = 4 },
            { item = "wood_log", count = 1 }
        },
        requiredRecipeItem = nil
    },
    pickaxe = {
        id = "pickaxe",
        label = "Кирка",
        resultItem = "pickaxe",
        resultCount = 1,
        category = "tools",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 16,
        ingredients = {
            { item = "iron_ingot", count = 6 },
            { item = "wood_log", count = 2 }
        },
        requiredRecipeItem = nil
    },
    padlock = {
        id = "padlock",
        label = "Замок",
        resultItem = "padlock",
        resultCount = 1,
        category = "items",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 12,
        ingredients = {
            { item = "iron_ingot", count = 5 }
        },
        requiredRecipeItem = nil
    },
    horseshoe = {
        id = "horseshoe",
        label = "Подкова",
        resultItem = "horseshoe",
        resultCount = 2,
        category = "material",
        station = "anvil",
        requiredTool = "hammer",
        craftTime = 10,
        ingredients = {
            { item = "iron_ingot", count = 4 }
        },
        requiredRecipeItem = nil
    },

    -- Костёр (campfire)
    leather = {
        id = "leather",
        label = "Кожа",
        resultItem = "leather",
        resultCount = 2,
        category = "material",
        station = "campfire",
        requiredTool = "hunting_knife",
        craftTime = 10,
        ingredients = {
            { item = "pelt", count = 1 }
        },
        requiredRecipeItem = nil
    }
}

-- Получить рецепт по ID
function Crafting.GetRecipe(recipeId)
    return Crafting.Recipes[recipeId]
end

-- Получить все рецепты
function Crafting.GetAllRecipes()
    return Crafting.Recipes
end

-- Получить список категорий (с учетом станции)
function Crafting.GetCategories(station)
    if station == "med_table" then
        return {
            medical = Crafting.Categories.medical
        }
    end

    -- В полевых условиях (J) показываем все категории для подсказки "Требуется верстак"
    if station == "field" then
        return Crafting.Categories
    end

    -- Для специализированных станций (наковальня, печь, верстак, костер)
    -- возвращаем только те категории, в которых реально есть рецепты для этой станции
    local availableRecipes = Crafting.GetRecipesForStation(station)
    local cats = {}
    for _, rec in pairs(availableRecipes) do
        local catId = rec.category
        if catId and Crafting.Categories[catId] then
            cats[catId] = Crafting.Categories[catId]
        end
    end

    if next(cats) ~= nil then
        return cats
    end

    return Crafting.Categories
end

function Crafting.GetCategoriesForStation(station)
    return Crafting.GetCategories(station)
end

-- Получить рецепты, доступные для конкретной станции (field / workbench / campfire / med_table / furnace / anvil)
function Crafting.GetRecipesForStation(station)
    local filtered = {}
    for id, rec in pairs(Crafting.Recipes) do
        if station == "workbench" then
            -- На верстаке доступны только крафты верстака и базовые полевые (исключая плавильную печь, наковальню, костер и медстол)
            if rec.station == "workbench" or rec.station == "field" or not rec.station then
                filtered[id] = rec
            end
        elseif station == "campfire" then
            -- У костра доступны только крафты для костра
            if rec.station == "campfire" then
                filtered[id] = rec
            end
        elseif station == "med_table" then
            -- На медицинском столе доступны только крафты медицинского стола
            if rec.station == "med_table" then
                filtered[id] = rec
            end
        elseif station == "furnace" then
            -- В плавильной печи доступны только рецепты плавильной печи
            if rec.station == "furnace" then
                filtered[id] = rec
            end
        elseif station == "anvil" then
            -- На наковальне доступны только рецепты наковальни
            if rec.station == "anvil" then
                filtered[id] = rec
            end
        else
            -- В полевых условиях доступны только рецепты со station == 'field'
            if rec.station == "field" or not rec.station then
                filtered[id] = rec
            end
        end
    end
    return filtered
end

-- Экспорты для удобства других ресурсов
exports('GetRecipe', function(recipeId)
    return Crafting.GetRecipe(recipeId)
end)

exports('GetAllRecipes', function()
    return Crafting.GetAllRecipes()
end)

exports('GetCategories', function(station)
    return Crafting.GetCategories(station)
end)

exports('GetCategoriesForStation', function(station)
    return Crafting.GetCategoriesForStation(station)
end)

exports('GetRecipesForStation', function(station)
    return Crafting.GetRecipesForStation(station)
end)

