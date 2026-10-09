$env:AWS_PROFILE = "new-account"
$region = "ap-southeast-2"
$base   = "$PSScriptRoot\lambda"
$build  = "$PSScriptRoot\.build"

Add-Type -Assembly System.IO.Compression
Add-Type -Assembly System.IO.Compression.FileSystem

function New-LambdaZip {
  param([string]$SourceDir, [string]$ZipPath)
  if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
  $stream  = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
  $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
  $files   = Get-ChildItem -Path $SourceDir -Recurse -File
  foreach ($file in $files) {
    $entryName  = $file.FullName.Substring($SourceDir.Length + 1).Replace('\','/')
    $entry      = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Fastest)
    $entryStream = $entry.Open()
    $fileStream  = [System.IO.File]::OpenRead($file.FullName)
    $fileStream.CopyTo($entryStream)
    $fileStream.Close()
    $entryStream.Close()
  }
  $archive.Dispose()
  $stream.Close()
}

$lambdas = [ordered]@{
  "dbInit"            = "biterush-dbInit"
  "getRestaurants"    = "biterush-getRestaurants"
  "getRestaurantById" = "biterush-getRestaurantById"
  "customerLogin"     = "biterush-customerLogin"
  "customerRegister"  = "biterush-customerRegister"
  "login"             = "biterush-login"
  "register"          = "biterush-register"
  "placeOrder"        = "biterush-placeOrder"
  "getOrders"         = "biterush-getOrders"
  "updateOrder"       = "biterush-updateOrder"
  "deleteRestaurant"  = "biterush-deleteRestaurant"
  "updateRestaurant"  = "biterush-updateRestaurant"
}

$i = 1
foreach ($dir in $lambdas.Keys) {
  $fnName  = $lambdas[$dir]
  $zipPath = "$build\$dir-deploy.zip"
  $srcPath = "$base\$dir"

  Write-Host "[$i/$($lambdas.Count)] Zipping + deploying $fnName ..."
  New-LambdaZip -SourceDir $srcPath -ZipPath $zipPath

  aws lambda update-function-code `
    --function-name $fnName `
    --zip-file "fileb://$zipPath" `
    --region $region `
    --query "FunctionName" --output text
  $i++
}

Write-Host "`nAll deployed. Invoking dbInit to create DB + tables..."
Start-Sleep -Seconds 5

aws lambda invoke `
  --function-name biterush-dbInit `
  --region $region `
  --output json "$build\dbinit_result.json"

$result = Get-Content "$build\dbinit_result.json" | ConvertFrom-Json
if ($result.statusCode -eq 200) {
  Write-Host "dbInit SUCCESS: $($result.body)"
} else {
  Write-Host "dbInit response: $(Get-Content "$build\dbinit_result.json")"
}

Write-Host "`nTesting /restaurants endpoint..."
Start-Sleep -Seconds 3
try {
  $r = Invoke-RestMethod -Uri "https://6g2t0aqu9k.execute-api.ap-southeast-2.amazonaws.com/restaurants" -Method GET
  Write-Host "BACKEND OK: $(($r | ConvertTo-Json -Depth 2))"
} catch {
  Write-Host "FAILED: $($_.Exception.Message)"
}

Write-Host "`nTesting /login endpoint..."
try {
  $body = '{"email":"test@test.com","password":"test"}'
  $r2 = Invoke-RestMethod -Uri "https://6g2t0aqu9k.execute-api.ap-southeast-2.amazonaws.com/login" -Method POST -Body $body -ContentType "application/json"
  Write-Host "LOGIN endpoint OK"
} catch {
  $err = $_.ErrorDetails.Message
  if ($err -match "No account|Incorrect") {
    Write-Host "LOGIN endpoint OK (got expected auth error: $err)"
  } else {
    Write-Host "LOGIN FAILED: $err"
  }
}
