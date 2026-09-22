Add-Type -AssemblyName System.Drawing

$srcDir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$dstInv = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images"
$dstAdmin = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images"

if (!(Test-Path $dstAdmin)) {
    New-Item -ItemType Directory -Path $dstAdmin -Force
}

$sizeMap = @{
    449352 = "bottle_water.png"
    421508 = "bottle_empty.png"
    721128 = "apple.png"
    617728 = "mango.png"
    466241 = "pear.png"
    525488 = "wood_log.png"
    437288 = "wood_plank.png"
    675264 = "stone.png"
    724201 = "iron_ore.png"
    552318 = "iron_ingot.png"
    642478 = "glass.png"
    283069 = "house_key.png"
    425002 = "meat_bird_raw.png"
    433937 = "meat_bird_cooked.png"
    510012 = "meat_rabbit_raw.png"
    586716 = "meat_rabbit_cooked.png"
    545297 = "meat_pork_raw.png"
    477189 = "meat_pork_cooked.png"
    639234 = "meat_beef_raw.png"
    623833 = "meat_beef_cooked.png"
    519706 = "meat_deer_raw.png"
    463573 = "meat_deer_cooked.png"
    639278 = "meat_bear_raw.png"
    600764 = "meat_bear_cooked.png"
}

# Items that are vertical in inventory (1x2, 1x3, 2x3) but were drawn horizontally
$rotateItems = @(
    "wood_plank.png",
    "wood_log.png",
    "iron_ingot.png",
    "glass.png",
    "meat_pork_raw.png",
    "meat_pork_cooked.png",
    "meat_beef_raw.png",
    "meat_beef_cooked.png",
    "meat_deer_raw.png",
    "meat_deer_cooked.png"
)

function Crop-And-Save($srcPath, $targetName) {
    $srcImg = [System.Drawing.Bitmap]::FromFile($srcPath)
    
    # Check if rotation needed
    if ($rotateItems -contains $targetName) {
        $srcImg.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
    }

    # Find non-transparent bounds
    $minX = $srcImg.Width
    $minY = $srcImg.Height
    $maxX = 0
    $maxY = 0

    for ($y = 0; $y -lt $srcImg.Height; $y += 2) {
        for ($x = 0; $x -lt $srcImg.Width; $x += 2) {
            $px = $srcImg.GetPixel($x, $y)
            if ($px.A -gt 15) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    $w = $maxX - $minX + 1
    $h = $maxY - $minY + 1

    if ($w -le 0 -or $h -le 0) {
        $srcImg.Dispose()
        return
    }

    # Add 4% margin
    $margin = [Math]::Max(4, [int]([Math]::Min($w, $h) * 0.04))
    $cropX = [Math]::Max(0, $minX - $margin)
    $cropY = [Math]::Max(0, $minY - $margin)
    $cropW = [Math]::Min($srcImg.Width - $cropX, $w + ($margin * 2))
    $cropH = [Math]::Min($srcImg.Height - $cropY, $h + ($margin * 2))

    $rect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
    $cropped = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($cropped)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($srcImg, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    # Save to both destinations
    $outInv = [System.IO.Path]::Combine($dstInv, $targetName)
    $outAdmin = [System.IO.Path]::Combine($dstAdmin, $targetName)

    $cropped.Save($outInv, [System.Drawing.Imaging.ImageFormat]::Png)
    $cropped.Save($outAdmin, [System.Drawing.Imaging.ImageFormat]::Png)

    Write-Output "Processed $targetName -> ${cropW}x${cropH}"

    $cropped.Dispose()
    $srcImg.Dispose()
}

$files = [System.IO.Directory]::GetFiles($srcDir, "*.png")
foreach ($f in $files) {
    $len = [int]((New-Object System.IO.FileInfo($f)).Length)
    if ($sizeMap.ContainsKey($len)) {
        $targetName = $sizeMap[$len]
        Crop-And-Save $f $targetName
    }
}
