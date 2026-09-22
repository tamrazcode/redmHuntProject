Add-Type -AssemblyName System.Drawing

$srcDir = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$targetFile = $null
foreach ($f in [System.IO.Directory]::GetFiles($srcDir, "*.png")) {
    $info = New-Object System.IO.FileInfo($f)
    if ($info.Length -eq 447725) {
        $targetFile = $f
        break
    }
}

function Crop-Bitmap($img) {
    $minX = $img.Width
    $minY = $img.Height
    $maxX = 0
    $maxY = 0

    for ($y = 0; $y -lt $img.Height; $y += 2) {
        for ($x = 0; $x -lt $img.Width; $x += 2) {
            $px = $img.GetPixel($x, $y)
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

    $margin = [Math]::Max(3, [int]([Math]::Min($w, $h) * 0.03))
    $cropX = [Math]::Max(0, $minX - $margin)
    $cropY = [Math]::Max(0, $minY - $margin)
    $cropW = [Math]::Min($img.Width - $cropX, $w + ($margin * 2))
    $cropH = [Math]::Min($img.Height - $cropY, $h + ($margin * 2))

    $rect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
    $cropped = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($cropped)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    return $cropped
}

# 1. thehunt_inventory: Vertical 270 deg (445x849) for 1x2 grid slot
$invPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\bandage_burdock.png"
$imgInv = [System.Drawing.Bitmap]::FromFile($targetFile)
$imgInv.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone)
$cropInv = Crop-Bitmap($imgInv)
$cropInv.Save($invPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "SAVED INVENTORY (Vertical 270): $($cropInv.Width)x$($cropInv.Height)"
$cropInv.Dispose()
$imgInv.Dispose()

# 2. thehunt_crafting: Horizontal 0 deg (849x445) turned 90 deg right relative to the vertical 270
$craftPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\bandage_burdock.png"
$imgCraft = [System.Drawing.Bitmap]::FromFile($targetFile)
$cropCraft = Crop-Bitmap($imgCraft)
$cropCraft.Save($craftPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "SAVED CRAFTING (Horizontal 0): $($cropCraft.Width)x$($cropCraft.Height)"
$cropCraft.Dispose()
$imgCraft.Dispose()
