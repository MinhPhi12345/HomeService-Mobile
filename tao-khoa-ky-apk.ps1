<#
  Tạo KHÓA KÝ cho file APK (chạy 1 lần duy nhất, trong thư mục HomeService-Mobile):
      powershell -ExecutionPolicy Bypass -File .\tao-khoa-ky-apk.ps1

  Vì sao cần: mọi bản APK cập nhật phải được ký bằng cùng một khóa thì điện thoại mới "cài đè" lên bản cũ.
  Nếu dùng khóa debug (mỗi máy tính một khóa khác nhau) khách sẽ phải gỡ app cũ mới cài được bản mới.

  Kết quả:
    android\app\homeservice-release.jks   – file khóa (KHÔNG commit, đã có trong .gitignore)
    android\key.properties                – mật khẩu khóa  (KHÔNG commit)
  => Hãy SAO LƯU 2 file này (USB / Google Drive riêng). Mất khóa = không phát hành bản cập nhật được nữa.
#>
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$jks = Join-Path $root "android\app\homeservice-release.jks"
$props = Join-Path $root "android\key.properties"

if (Test-Path $jks) {
  Write-Host "Đã có khóa: $jks – không tạo lại (tạo lại sẽ làm bản cập nhật không cài đè được)." -ForegroundColor Yellow
  exit 0
}

# Tìm keytool: Android Studio (JBR) → JAVA_HOME → PATH
$candidates = @(
  "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
  "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
  "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe"
)
if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME "bin\keytool.exe") }
$keytool = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $keytool) {
  $cmd = Get-Command keytool -ErrorAction SilentlyContinue
  if ($cmd) { $keytool = $cmd.Source }
}
if (-not $keytool) { throw "Không tìm thấy keytool. Cài Android Studio hoặc đặt biến JAVA_HOME rồi chạy lại." }
Write-Host "Dùng keytool: $keytool"

$secure = Read-Host "Đặt mật khẩu cho khóa (ít nhất 8 ký tự, GHI LẠI)" -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ($pass.Length -lt 8) { throw "Mật khẩu phải có ít nhất 8 ký tự." }

& $keytool -genkeypair -v -keystore $jks -storetype PKCS12 -alias homeservice -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $pass -keypass $pass -dname "CN=HomeService, OU=Nhom 15, O=HomeService, L=Ho Chi Minh, C=VN"
if ($LASTEXITCODE -ne 0) { throw "keytool lỗi (mã $LASTEXITCODE)" }

@"
storePassword=$pass
keyPassword=$pass
keyAlias=homeservice
storeFile=homeservice-release.jks
"@ | Set-Content -Path $props -Encoding ASCII

Write-Host "`nĐã tạo khóa ký APK:" -ForegroundColor Green
Write-Host "  $jks"
Write-Host "  $props"
Write-Host "Hãy sao lưu 2 file trên. Từ giờ 'flutter build apk --release' tự ký bằng khóa này." -ForegroundColor Green
