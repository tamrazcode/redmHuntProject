Add-Type -AssemblyName System.Drawing
$dir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images"
$files = [System.IO.Directory]::GetFiles($dir, "*.png")

function Get-NonTransparentBounds($bitmap) {
    $minX = $bitmap.Width
    $minY = $bitmap.Height
    $maxX = 0
    $maxY = 0
    
    for ($y = 0; $y -lt $bitmap.Height; $y += 4) {
        for ($x = 0; $x -lt $bitmap.Width; $x += 4) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.A -gt 10) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    return [PSCustomObject]@{
        MinX = $minX
        MinY = $minY
        MaxX = $maxX
        MaxY = $maxY
        W = ($maxX - $minX)
        H = ($maxY - $minY)
    }
}

foreach ($f in $files) {
    $fn = [System.IO.Path]::GetFileName($f)
    if ($fn -like "bottle_no_water*" -or $fn -like "bottle_with_water*") { continue }
    $bmp = [System.Drawing.Bitmap]::FromFile($f)
    $b = Get-NonTransparentBounds $bmp
    $bmp.Dispose()
    Write-Output "$fn : content is $($b.W)x$($b.H) at offset ($($b.MinX), $($b.MinY))"
}
