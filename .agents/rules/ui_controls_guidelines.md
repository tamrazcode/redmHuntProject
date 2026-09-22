# HUNT: Hard RP — Правила управления и блокировки ввода в интерфейсах (UI Controls & Focus Guide)

Данное руководство является обязательным стандартом для всех кастомных NUI-интерфейсов сервера HUNT (`thehunt_doors`, `thehunt_builder`, `thehunt_scenes`, `thehunt_inventory` и др.).

---

## 1. Главные принципы взаимодействия NUI и игры

1. **Фокус на поле ввода текста (Text Input Focus)**:
   - **КОГДА ФОКУС НАХОДИТСЯ НА `<input>` ИЛИ `<textarea>`**: БЛОКИРОВАТЬ АБСОЛЮТНО ВСЁ УПРАВЛЕНИЕ ИГРОЙ.
   - Игрок печатает текст (`WASD`, `Пробел`, `E`, `Q`, `F`, `R`), и ни одна буква не должна триггерить передвижение, прыжки, удары, свист или посадку на коня в игре.
   - Реализация: JS отправляет `setInputFocusState({ hasFocus: true })` при событии `focusin` и `hasFocus: false` при `focusout`. В Lua при `isInputFocused == true` вызывается `DisableAllControlActions(pad)` без включения белого списка кнопок.

2. **Обычный режим открытого интерфейса (UI Open, No Input Focus)**:
   - Когда открыто окно (например, список предметов, просмотр карточки, выбор из списка), но фокус НЕ в поле ввода текста:
   - Разрешено базовое перемещение персонажа и голосовой чат, но строго заблокированы боевые действия и стрельба:
     - `DisableAllControlActions(pad)`
     - Разрешаются только кнопки из белого списка (`INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_SPRINT`, `INPUT_JUMP`, `INPUT_DUCK`, `INPUT_PUSH_TO_TALK`).
     - Обязательно вызывается `DisablePlayerFiring(ped, true)`.

3. **Режим 3D установки объектов и сцен (Placement Mode)**:
   - Разрешены кнопки осмотра, ходьбы и специальные функциональные клавиши:
     - Осмотр: `INPUT_LOOK_LR`, `INPUT_LOOK_UD`, `0xA987235F`, `0xD2047988`
     - Ходьба: `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_SPRINT`
     - Действия установки: `ЛКМ` (установить), `ПКМ`/`Esc` (отмена), `Q`/`E` (высота), `Колесико` (дистанция), `Space` (прилипание).
     - Заблокированы: стрельба из оружия, смена оружия, посадка на лошадей/повозки.

---

## 2. Шаблон кода блокировки управления (Lua Client)

```lua
-- Поток фильтрации управления
Citizen.CreateThread(function()
    local whitelistUI = {
        0xF1301666, 0x05CA7C52, -- Голосовой чат
        `INPUT_PUSH_TO_TALK`,
        `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`, `INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`, `INPUT_JUMP`, `INPUT_CLIMB`, `INPUT_DUCK`,
        `INPUT_HORSE_MOVE_UD`, `INPUT_HORSE_MOVE_LR`,
        `INPUT_VEH_ACCELERATE`, `INPUT_VEH_BRAKE`,
    }

    while true do
        if isInputFocused then
            -- ПОЛНАЯ БЛОКИРОВКА ВСЕГО УПРАВЛЕНИЯ ПРИ ПЕЧАТИ ТЕКСТА
            Citizen.Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)
            end
            DisablePlayerFiring(ped, true)
        elseif isUIOpen then
            -- БЕЛЫЙ СПИСОК КНОПОК ПРИ ОТКРЫТОМ ОКНЕ БЕЗ ФОКУСА ВВОДА
            Citizen.Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)
                for _, control in ipairs(whitelistUI) do
                    EnableControlAction(pad, control, true)
                end
            end
            DisablePlayerFiring(ped, true)
        else
            Citizen.Wait(150)
        end
    end
end)
```

---

## 3. Шаблон слушателей фокуса ввода (JavaScript NUI)

```javascript
// Отслеживание глобального фокуса ввода текста
document.addEventListener('focusin', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
    fetch(`https://${GetParentResourceName()}/setInputFocusState`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: true })
    }).catch(() => {});
  }
});

document.addEventListener('focusout', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
    fetch(`https://${GetParentResourceName()}/setInputFocusState`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: false })
    }).catch(() => {});
  }
});
```
