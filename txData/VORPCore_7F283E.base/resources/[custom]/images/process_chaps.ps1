Add-Type -AssemblyName System.Drawing
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$clothesDir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images\clothes"
$fileChaps = Get-ChildItem -LiteralPath $clothesDir -Filter "*.png" | Where-Object { $_.Length -eq 2306105 } | Select-Object -First 1

if (-not $fileChaps) {
    $fileChaps = Get-ChildItem -LiteralPath $clothesDir -Filter "*.png" | Where-Object { $_.Name.Length -eq 9 -and $_.Name -like "*.png" } | Select-Object -First 1
}

if (-not $fileChaps) {
    Write-Error "Chaps source file not found in $clothesDir"
    exit 1
}

Write-Host "Found source: $($fileChaps.FullName) ($($fileChaps.Length) bytes)"
$srcImg = [System.Drawing.Bitmap]::FromFile($fileChaps.FullName)
Write-Host "Original dimensions: $($srcImg.Width)x$($srcImg.Height)"

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
$margin = [Math]::Max(4, [int]([Math]::Min($w, $h) * 0.025))
$cropX = [Math]::Max(0, $minX - $margin)
$cropY = [Math]::Max(0, $minY - $margin)
$cropW = [Math]::Min($srcImg.Width - $cropX, $w + ($margin * 2))
$cropH = [Math]::Min($srcImg.Height - $cropY, $h + ($margin * 2))

Write-Host "Cropped box: $cropW x $cropH (from $minX, $minY)"

$maxTarget = 320.0
$scale = [Math]::Min($maxTarget / [double]$cropW, $maxTarget / [double]$cropH)
$targetW = [int]($cropW * $scale)
$targetH = [int]($cropH * $scale)

$bmp = New-Object System.Drawing.Bitmap($targetW, $targetH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$destRect = New-Object System.Drawing.Rectangle(0, 0, $targetW, $targetH)
$g.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

$bmpSquare = New-Object System.Drawing.Bitmap(96, 96, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gSq = [System.Drawing.Graphics]::FromImage($bmpSquare)
$gSq.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gSq.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gSq.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$scaleSq = 88.0 / [double][Math]::Max($targetW, $targetH)
$sqW = [int]($targetW * $scaleSq)
$sqH = [int]($targetH * $scaleSq)
$sqX = [int]((96 - $sqW) / 2)
$sqY = [int]((96 - $sqH) / 2)
$gSq.DrawImage($bmp, (New-Object System.Drawing.Rectangle($sqX, $sqY, $sqW, $sqH)), 0, 0, $targetW, $targetH, [System.Drawing.GraphicsUnit]::Pixel)
$gSq.Dispose()

$destinations = @(
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\clothing_chap.png"; Bitmap = $bmp },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\clothing_chap.png"; Bitmap = $bmp },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_core\html\admin_menu\images\clothing_chap.png"; Bitmap = $bmp },
    @{ Path = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[VORP]\vorp_inventory\html\img\items\clothing_chap.png"; Bitmap = $bmpSquare }
)

foreach ($dst in $destinations) {
    $parent = [System.IO.Path]::GetDirectoryName($dst.Path)
    if (!(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $dst.Path) {
        Remove-Item -LiteralPath $dst.Path -Force
    }
    $dst.Bitmap.Save($dst.Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved: $($dst.Path) ($($dst.Bitmap.Width)x$($dst.Bitmap.Height))"
}

$bmp.Dispose()
$bmpSquare.Dispose()
$srcImg.Dispose()
Write-Host "SUCCESS: Chaps replacement complete!"
