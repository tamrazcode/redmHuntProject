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

# Original raw dimensions:
$raw = [System.Drawing.Bitmap]::FromFile($targetFile)
Write-Output "RAW FILE SIZE: $($raw.Width)x$($raw.Height)"
$raw.Dispose()

# Rotate 90 right (clockwise) for Crafting
$craftPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\bandage_burdock.png"
$img90 = [System.Drawing.Bitmap]::FromFile($targetFile)
$img90.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
$crop90 = Crop-Bitmap($img90)
$crop90.Save($craftPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "CRAFTING (90 deg right): $($crop90.Width)x$($crop90.Height)"
$crop90.Dispose()
$img90.Dispose()

# Keep Inventory vertical (0 deg or 270 deg?) Let's check:
# In the previous step, Inventory had 270 deg (445x849), and Crafting had 0 deg (849x445).
# The user showed the Crafting screenshot where 0 deg looked like a vertical roll tilted left, and said:
# "тут опять перевёрнутая, нужно повернуть на 90 вправо"
# So Crafting needs 90 deg clockwise!
