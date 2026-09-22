Add-Type -AssemblyName System.Drawing
$b1 = [System.Drawing.Bitmap]::FromFile('c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_crafting\html\images\bandage_burdock.png')
$b2 = [System.Drawing.Bitmap]::FromFile('c:\Users\borch\Desktop\RedM_Server\txData\VORPCore_7F283E.base\resources\[custom]\thehunt_inventory\html\images\bandage_burdock.png')
Write-Output "Crafting: $($b1.Width) x $($b1.Height)"
Write-Output "Inventory: $($b2.Width) x $($b2.Height)"
$b1.Dispose()
$b2.Dispose()
