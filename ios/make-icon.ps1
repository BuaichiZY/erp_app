Add-Type -AssemblyName System.Drawing
$target = Join-Path $PSScriptRoot 'ERP/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
$bitmap = [System.Drawing.Bitmap]::new(1024, 1024)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bounds = [System.Drawing.Rectangle]::new(0, 0, 1024, 1024)
$gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new($bounds, [System.Drawing.ColorTranslator]::FromHtml('#FF5FA2'), [System.Drawing.ColorTranslator]::FromHtml('#8B5CF6'), 45)
$graphics.FillRectangle($gradient, $bounds)
$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$path.StartFigure()
$points = @(
    @(54,72,51,69,34,57,34,46),
    @(34,46,34,34,48,32,54,42),
    @(54,42,60,32,74,34,74,46),
    @(74,46,74,57,57,69,54,72)
)
foreach ($p in $points) {
    $path.AddBezier([float]($p[0]*1024/108),[float]($p[1]*1024/108),[float]($p[2]*1024/108),[float]($p[3]*1024/108),[float]($p[4]*1024/108),[float]($p[5]*1024/108),[float]($p[6]*1024/108),[float]($p[7]*1024/108))
}
$path.CloseFigure()
$graphics.FillPath([System.Drawing.Brushes]::White, $path)
$bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$path.Dispose(); $gradient.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
