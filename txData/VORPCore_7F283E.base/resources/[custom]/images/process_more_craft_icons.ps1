Add-Type -AssemblyName System.Drawing

$srcDir = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"

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

$itemsToProcess = @{
    556693 = "burdock_leaf_h.png" # Лист лопуха.png
    223118 = "twigs_h.png"        # Ветка.png
}

foreach ($f in [System.IO.Directory]::GetFiles($srcDir, "*.png")) {
    $info = New-Object System.IO.FileInfo($f)
    if ($itemsToProcess.ContainsKey($info.Length)) {
        $targetName = $itemsToProcess[$info.Length]
        $img = [System.Drawing.Bitmap]::FromFile($f)
        $cropped = Crop-Bitmap($img)
        
        $craftPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\$targetName"
        $invPath = "c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\$targetName"

        $cropped.Save($craftPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $cropped.Save($invPath, [System.Drawing.Imaging.ImageFormat]::Png)

        Write-Output "SAVED $targetName ($($cropped.Width)x$($cropped.Height)) to crafting and inventory"

        $cropped.Dispose()
        $img.Dispose()
    }
}
