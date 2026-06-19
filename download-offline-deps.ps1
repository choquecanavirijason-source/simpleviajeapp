$base = "C:\offline-repo"
New-Item -ItemType Directory -Force -Path $base | Out-Null

$google = "https://dl.google.com/android/maven2"
$central = "https://repo1.maven.org/maven2"

# group/path | artifact | version | repo
$deps = @(
    @("com/android/tools/analytics-library", "crash", "31.7.3", $google),
    @("org/jetbrains/kotlin", "kotlin-gradle-plugin-idea", "2.1.0", $central),
    @("org/jetbrains/kotlin", "kotlin-klib-commonizer-api", "2.1.0", $central),
    @("org/jetbrains/kotlin", "kotlin-build-statistics", "2.1.0", $central),
    @("org/jetbrains/kotlin", "kotlin-gradle-plugin-api", "2.1.0", $central),
    @("org/jetbrains/kotlin", "kotlin-gradle-plugin-model", "2.1.0", $central),
    @("org/jetbrains/kotlin", "kotlin-compiler-runner", "2.1.0", $central),
    @("javax/inject", "javax.inject", "1", $central),
    @("org/bouncycastle", "bcprov-jdk18on", "1.77", $central),
    @("org/apache/commons", "commons-compress", "1.21", $central),
    @("com/google/jimfs", "jimfs", "1.1", $central)
)

foreach ($d in $deps) {
    $group = $d[0]; $art = $d[1]; $ver = $d[2]; $repo = $d[3]
    $folder = Join-Path $base ($group.Replace("/", "\") + "\$art\$ver")
    New-Item -ItemType Directory -Force -Path $folder | Out-Null

    foreach ($ext in @("pom", "jar")) {
        $url = "$repo/$group/$art/$ver/$art-$ver.$ext"
        $out = Join-Path $folder "$art-$ver.$ext"
        Write-Host "Descargando $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
            Write-Host "  OK -> $out" -ForegroundColor Green
        } catch {
            Write-Host "  FALLO: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`nListo. Archivos en C:\offline-repo" -ForegroundColor Cyan
