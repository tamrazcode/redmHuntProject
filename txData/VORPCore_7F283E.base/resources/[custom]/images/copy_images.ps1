[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$src = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$dstList = @(
    "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images",
    "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images",
    "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images"
)

foreach ($dst in $dstList) {
    if (!(Test-Path $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }
}

$files = Get-ChildItem -Path $src -Filter "*.png"
foreach ($f in $files) {
    $target = ""
    $n = $f.Name
    if ($n -like "*Бутылка с водой*") { $target = "bottle_water.png" }
    elseif ($n -like "*Пустая бутылка*") { $target = "bottle_empty.png" }
    elseif ($n -like "*Яблоко*") { $target = "apple.png" }
    elseif ($n -like "*Манго*") { $target = "mango.png" }
    elseif ($n -like "*Груша*") { $target = "pear.png" }
    elseif ($n -like "*Древесина*") { $target = "wood_log.png" }
    elseif ($n -like "*Доска*") { $target = "wood_plank.png" }
    elseif ($n -like "*Камень*") { $target = "stone.png" }
    elseif ($n -like "*Железная руда*") { $target = "iron_ore.png" }
    elseif ($n -like "*Железный слиток*") { $target = "iron_ingot.png" }
    elseif ($n -like "*Стекло*") { $target = "glass.png" }
    elseif ($n -like "*Ключ*") { $target = "house_key.png" }
    elseif ($n -like "*Сырая курица*") { $target = "meat_bird_raw.png" }
    elseif ($n -like "*Жареная курица*") { $target = "meat_bird_cooked.png" }
    elseif ($n -like "*Сырая крольчатина*") { $target = "meat_rabbit_raw.png" }
    elseif ($n -like "*Жареная крольчатина*") { $target = "meat_rabbit_cooked.png" }
    elseif ($n -like "*Свиной окорок*") { $target = "meat_pork_raw.png" }
    elseif ($n -like "*Жареный окорок*") { $target = "meat_pork_cooked.png" }
    elseif ($n -like "*Сырая говядина*") { $target = "meat_beef_raw.png" }
    elseif ($n -like "*Жареная говядина*") { $target = "meat_beef_cooked.png" }
    elseif ($n -like "*Сырая оленина*") { $target = "meat_deer_raw.png" }
    elseif ($n -like "*Жареная оленина*") { $target = "meat_deer_cooked.png" }
    elseif ($n -like "*Сырая медвежатина*") { $target = "meat_bear_raw.png" }
    elseif ($n -like "*Жареная медвежатина*") { $target = "meat_bear_cooked.png" }
    elseif ($n -like "*Бинт*") { $target = "bandage.png" }
    elseif ($n -like "*Ветка*") { $target = "twigs.png" }
    elseif ($n -like "*Костёр*") { $target = "campfire.png" }
    elseif ($n -like "*Костер*") { $target = "campfire.png" }
    elseif ($n -like "*Лист лопуха*") { $target = "burdock_leaf.png" }
    elseif ($n -like "*Повязка с лопухом*") { $target = "bandage_burdock.png" }
    elseif ($n -like "*Фон блокнота*") { $target = "notebook_bg.png" }
    elseif ($n -like "*Фон листка*") { $target = "torn_page_bg.png" }
    elseif ($n -like "*Блокнот*" -and $n -notlike "*Лист*") {
        # Processed with proper cropping and orientations via process_notebook.ps1
        continue
    }
    elseif ($n -like "*Вырванная страница*") {
        # Processed with proper cropping and orientations via process_page.ps1
        continue
    }
    elseif ($n -like "*Ткань*") { $target = "cloth.png" }

    if ($target -ne "") {
        foreach ($dst in $dstList) {
            $out = Join-Path $dst $target
            Copy-Item -Path $f.FullName -Destination $out -Force
        }
        Write-Host "COPIED: $($f.Name) -> $target"
    } else {
        Write-Host "NOT MATCHED: $($f.Name)"
    }
}
