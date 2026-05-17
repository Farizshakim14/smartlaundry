Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('c:\Users\FARIZS\aplikasilaundry\assets\welcome.png')
$bmp = New-Object System.Drawing.Bitmap($img)
$color = $bmp.GetPixel(0,0)
Write-Host "$($color.R),$($color.G),$($color.B)"
