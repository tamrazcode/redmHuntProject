$src = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$dst1 = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images"
$dst2 = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images"

if (!(Test-Path -LiteralPath $dst1)) { New-Item -ItemType Directory -Path $dst1 -Force | Out-Null }
if (!(Test-Path -LiteralPath $dst2)) { New-Item -ItemType Directory -Path $dst2 -Force | Out-Null }

$map = @{
    "589260" = "bandage.png"
    "223118" = "twigs.png"
    "725767" = "campfire.png"
    "556693" = "burdock_leaf.png"
    "447725" = "bandage_burdock.png"
    "591808" = "cloth.png"
    "449352" = "bottle_water.png"
    "421508" = "bottle_empty.png"
    "721128" = "apple.png"
    "617728" = "mango.png"
    "466241" = "pear.png"
    "525488" = "wood_log.png"
    "437288" = "wood_plank.png"
    "675264" = "stone.png"
    "724201" = "iron_ore.png"
    "552318" = "iron_ingot.png"
    "642478" = "glass.png"
    "283069" = "house_key.png"
    "425002" = "meat_bird_raw.png"
    "433937" = "meat_bird_cooked.png"
    "510012" = "meat_rabbit_raw.png"
    "586716" = "meat_rabbit_cooked.png"
    "545297" = "meat_pork_raw.png"
    "477189" = "meat_pork_cooked.png"
    "639234" = "meat_beef_raw.png"
    "623833" = "meat_beef_cooked.png"
    "519706" = "meat_deer_raw.png"
    "463573" = "meat_deer_cooked.png"
    "639278" = "meat_bear_raw.png"
    "600764" = "meat_bear_cooked.png"
}

$files = Get-ChildItem -LiteralPath $src -Filter "*.png"
foreach ($f in $files) {
    $lenStr = $f.Length.ToString()
    if ($map.ContainsKey($lenStr)) {
        $target = $map[$lenStr]
        $out1 = Join-Path $dst1 $target
        $out2 = Join-Path $dst2 $target
        Copy-Item -LiteralPath $f.FullName -Destination $out1 -Force
        Copy-Item -LiteralPath $f.FullName -Destination $out2 -Force
        Write-Host "COPIED $($f.Length) -> $target"
    } else {
        Write-Host "UNKNOWN SIZE $($f.Length) for $($f.Name)"
    }
}
