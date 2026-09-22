Add-Type -AssemblyName System.Drawing
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$srcDir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\images"
$fPage = Get-ChildItem -LiteralPath $srcDir | Where-Object { $_.Length -eq 2319442 } | Select-Object -First 1
$fBook = Get-ChildItem -LiteralPath $srcDir | Where-Object { $_.Length -eq 2342353 } | Select-Object -First 1

function Measure-Sheet($img) {
    $minX = $img.Width; $minY = $img.Height; $maxX = 0; $maxY = 0
    for ($y = 0; $y -lt $img.Height; $y += 2) {
        for ($x = 0; $x -lt $img.Width; $x += 2) {
            $px = $img.GetPixel($x, $y)
            if ($px.A -gt 25) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    $w = $maxX - $minX + 1
    $h = $maxY - $minY + 1
    $leftPct = [math]::Round(($minX / $img.Width) * 100, 2)
    $rightPct = [math]::Round((($img.Width - $maxX) / $img.Width) * 100, 2)
    $topPct = [math]::Round(($minY / $img.Height) * 100, 2)
    $botPct = [math]::Round((($img.Height - $maxY) / $img.Height) * 100, 2)
    return "$($img.Width)x$($img.Height): Content box X=$minX, Y=$minY, W=$w, H=$h | Margins: Top=$topPct%, Bottom=$botPct%, Left=$leftPct%, Right=$rightPct%"
}

$imgPage = [System.Drawing.Bitmap]::FromFile($fPage.FullName)
$imgBook = [System.Drawing.Bitmap]::FromFile($fBook.FullName)

Write-Host "Page BG: $(Measure-Sheet $imgPage)"
Write-Host "Book BG: $(Measure-Sheet $imgBook)"

$imgPage.Dispose()
$imgBook.Dispose()
