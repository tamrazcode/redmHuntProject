Add-Type -AssemblyName System.Drawing
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$srcDir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$file = Get-ChildItem -LiteralPath $srcDir -Filter "*.png" | Where-Object { $_.Length -eq 3307362 } | Select-Object -First 1

if (-not $file) {
    # Fallback to any file whose name length matches or contains notebook
    $file = Get-ChildItem -LiteralPath $srcDir -Filter "*.png" | Where-Object { $_.Name.Length -eq 11 -and $_.Name -like "*.png" -and $_.Name -notlike "*Фон*" } | Select-Object -First 1
}

if (-not $file) {
    Write-Error "Source file for notebook not found in $srcDir"
    exit 1
}

Write-Host "Processing source: $($file.FullName) ($($file.Length) bytes)"
$srcImg = [System.Drawing.Bitmap]::FromFile($file.FullName)

# 1. Compute non-transparent bounding box
$minX = $srcImg.Width; $minY = $srcImg.Height; $maxX = 0; $maxY = 0
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

$margin = [Math]::Max(3, [int]([Math]::Min($w, $h) * 0.03))
$cropX = [Math]::Max(0, $minX - $margin)
$cropY = [Math]::Max(0, $minY - $margin)
$cropW = [Math]::Min($srcImg.Width - $cropX, $w + ($margin * 2))
$cropH = [Math]::Min($srcImg.Height - $cropY, $h + ($margin * 2))

Write-Host "Cropped box: $cropW x $cropH (from $minX, $minY)"

# 2. Vertical 1x2 image (height 320, width ~217)
$scaleV = 320.0 / [double]$cropH
$targetWV = [int]($cropW * $scaleV)
$targetHV = 320

$bmpV = New-Object System.Drawing.Bitmap($targetWV, $targetHV, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gV = [System.Drawing.Graphics]::FromImage($bmpV)
$gV.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gV.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gV.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$destRectV = New-Object System.Drawing.Rectangle(0, 0, $targetWV, $targetHV)
$gV.DrawImage($srcImg, $destRectV, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$gV.Dispose()

# 3. Horizontal 2x1 image (width 320, height ~217, rotated 90 deg clockwise)
$targetWH = 320
$targetHH = $targetWV
$bmpH = New-Object System.Drawing.Bitmap($targetWH, $targetHH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gH = [System.Drawing.Graphics]::FromImage($bmpH)
$gH.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gH.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gH.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# Draw vertical into temporary, then rotate
$tempV = New-Object System.Drawing.Bitmap($bmpV)
$tempV.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
$destRectH = New-Object System.Drawing.Rectangle(0, 0, $targetWH, $targetHH)
$gH.DrawImage($tempV, $destRectH, 0, 0, $tempV.Width, $tempV.Height, [System.Drawing.GraphicsUnit]::Pixel)
$tempV.Dispose()
$gH.Dispose()

# 4. Square 96x96 for vorp_inventory
$bmpSquare = New-Object System.Drawing.Bitmap(96, 96, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gSq = [System.Drawing.Graphics]::FromImage($bmpSquare)
$gSq.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gSq.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gSq.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# Fit vertical within 96x96 with 4px padding (height 88)
$scaleSq = 88.0 / [double]$targetHV
$sqW = [int]($targetWV * $scaleSq)
$sqH = 88
$sqX = [int]((96 - $sqW) / 2)
$sqY = 4
$gSq.DrawImage($bmpV, (New-Object System.Drawing.Rectangle($sqX, $sqY, $sqW, $sqH)), 0, 0, $targetWV, $targetHV, [System.Drawing.GraphicsUnit]::Pixel)
$gSq.Dispose()

# 5. Save destinations
$destinations = @(
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\notebook.png"; Bitmap = $bmpV },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\notebook_h.png"; Bitmap = $bmpH },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\notebook.png"; Bitmap = $bmpV },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\notebook_h.png"; Bitmap = $bmpH },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images\notebook.png"; Bitmap = $bmpV },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images\notebook_h.png"; Bitmap = $bmpH },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[VORP]\vorp_inventory\html\img\items\notebook.png"; Bitmap = $bmpSquare }
)

foreach ($dst in $destinations) {
    $parent = [System.IO.Path]::GetDirectoryName($dst.Path)
    if (!(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $dst.Bitmap.Save($dst.Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved: $($dst.Path) ($($dst.Bitmap.Width)x$($dst.Bitmap.Height))"
}

$bmpV.Dispose()
$bmpH.Dispose()
$bmpSquare.Dispose()
$srcImg.Dispose()
Write-Host "SUCCESS: Notebook replacement complete!"
