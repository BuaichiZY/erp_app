param(
    [Parameter(Mandatory = $true)]
    [string] $CertificatePath
)

$ErrorActionPreference = 'Stop'
$openssl = 'C:\Program Files\Git\usr\bin\openssl.exe'
if (-not (Test-Path -LiteralPath $openssl)) { throw 'Git for Windows OpenSSL was not found.' }
$signingDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.signing'
$privateKey = Join-Path $signingDir 'ERP_Distribution.key'
$certificate = Join-Path $signingDir 'ERP_Distribution.pem'
$bundle = Join-Path $signingDir 'ERP_Distribution.p12'
if (-not (Test-Path -LiteralPath $privateKey)) { throw 'The local distribution private key is missing.' }
if (Test-Path -LiteralPath $bundle) { throw 'A distribution .p12 already exists; refusing to overwrite it.' }
& $openssl x509 -inform DER -in $CertificatePath -out $certificate
if ($LASTEXITCODE -ne 0) { throw 'Could not read the Apple distribution certificate.' }
Write-Host 'Create a password for the distribution .p12 when OpenSSL prompts. Keep it for the GitHub Actions secret.'
& $openssl pkcs12 -export -inkey $privateKey -in $certificate -out $bundle -name 'ERP Apple Distribution'
if ($LASTEXITCODE -ne 0) { throw 'Could not create the distribution .p12. Check that the certificate was issued for this CSR.' }
Write-Host "Created: $bundle"
