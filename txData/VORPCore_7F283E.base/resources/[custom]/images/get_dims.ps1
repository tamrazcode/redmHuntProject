Add-Type -AssemblyName System.Drawing
$dir = "C:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images"
$files = [System.IO.Directory]::GetFiles($dir, "*.png")
foreach ($f in $files) {
    $img = [System.Drawing.Image]::FromFile($f)
    $fn = [System.IO.Path]::GetFileName($f)
    Write-Output "$fn : $($img.Width)x$($img.Height)"
    $img.Dispose()
}
