param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 32, 48, 64, 128, 256)

$src = [System.Drawing.Image]::FromFile($Source)
try {
    # Render each size to a PNG byte buffer (PNG-in-ICO, supported on Vista+).
    $pngs = @()
    foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($s, $s)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($src, 0, 0, $s, $s)
        $g.Dispose()

        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $pngs += , @{ Size = $s; Bytes = $ms.ToArray() }
        $ms.Dispose()
    }
}
finally {
    $src.Dispose()
}

$fs = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
try {
    # ICONDIR header
    $bw.Write([UInt16]0)            # reserved
    $bw.Write([UInt16]1)            # type: 1 = icon
    $bw.Write([UInt16]$pngs.Count)  # image count

    # Directory entries are 16 bytes each; image data follows all entries.
    $offset = 6 + (16 * $pngs.Count)
    foreach ($p in $pngs) {
        $dim = if ($p.Size -ge 256) { 0 } else { $p.Size }  # 0 means 256
        $bw.Write([Byte]$dim)       # width
        $bw.Write([Byte]$dim)       # height
        $bw.Write([Byte]0)          # color count (0 = >=256 colors)
        $bw.Write([Byte]0)          # reserved
        $bw.Write([UInt16]1)        # color planes
        $bw.Write([UInt16]32)       # bits per pixel
        $bw.Write([UInt32]$p.Bytes.Length) # size of image data
        $bw.Write([UInt32]$offset)  # offset of image data
        $offset += $p.Bytes.Length
    }
    foreach ($p in $pngs) {
        $bw.Write($p.Bytes)
    }
}
finally {
    $bw.Flush(); $bw.Dispose(); $fs.Dispose()
}

Write-Output "Created $Destination with sizes: $($sizes -join ', ')"
