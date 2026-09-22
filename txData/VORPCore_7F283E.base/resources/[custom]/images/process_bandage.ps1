Add-Type -AssemblyName System.Drawing

$srcDir = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$invPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\bandage_burdock.png"
$craftPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\bandage_burdock.png"
$adminPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images\bandage_burdock.png"

$targetFile = $null
foreach ($f in [System.IO.Directory]::GetFiles($srcDir, "*.png")) {
    $info = New-Object System.IO.FileInfo($f)
    if ($info.Length -eq 447725) {
        $targetFile = $f
        break
    }
}

if (-not $targetFile) {
    Write-Error "Source file 447725 not found"
    exit 1
}

function Crop-Image($img) {
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

# 1. Generate VERTICAL image (rotated 270) for thehunt_inventory
$imgInv = [System.Drawing.Bitmap]::FromFile($targetFile)
$imgInv.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone)
$croppedInv = Crop-Image($imgInv)
$croppedInv.Save($invPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "INVENTORY IMAGE (Vertical 270): $($croppedInv.Width)x$($croppedInv.Height)"
$croppedInv.Dispose()
$imgInv.Dispose()

# 2. Generate HORIZONTAL image (0 deg) for thehunt_crafting & admin
$imgCraft = [System.Drawing.Bitmap]::FromFile($targetFile)
$croppedCraft = Crop-Image($imgCraft)
$croppedCraft.Save($craftPath, [System.Drawing.Imaging.ImageFormat]::Png)
$croppedCraft.Save($adminPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "CRAFTING IMAGE (Horizontal 0): $($croppedCraft.Width)x$($croppedCraft.Height)"
$croppedCraft.Dispose()
$imgCraft.Dispose()
