# ================================================================
# PORTABLE UNCENSORED AI - AUTOMATED USB SETUP SCRIPT
# ================================================================
# Multi-Model Edition: Choose one or more AI models to install!
# Supports preset models + custom HuggingFace GGUF downloads.
# ================================================================

$ErrorActionPreference = "Continue"
$USB_Drive = (Get-Item $MyInvocation.MyCommand.Path).Directory.Parent.FullName.TrimEnd('\')

# -----------------------------------------------------------------
# PRE-FLIGHT: Ollama needs 64-bit Windows 10/11 (PowerShell 5+)
# -----------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -lt 5 -or [Environment]::OSVersion.Version.Major -lt 10 -or -Not [Environment]::Is64BitOperatingSystem) {
    Write-Host "ERROR: This installer needs 64-bit Windows 10 or 11." -ForegroundColor Red
    Write-Host "       Windows 7/8 and 32-bit systems are not supported by the Ollama engine." -ForegroundColor Red
    exit 1
}

# The portable engine uses its own port so it never collides with a
# system-wide Ollama install (which would steal the model import).
$PortableOllamaHost = "127.0.0.1:11435"

# Keep the PC awake while downloading/importing (reset when this process exits)
try {
    Add-Type -Namespace PortableAI -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
    [PortableAI.Power]::SetThreadExecutionState([uint32]"0x80000001") | Out-Null
} catch {}

# -----------------------------------------------------------------
# MODEL CATALOG (shared JSON config)
# -----------------------------------------------------------------
$modelsConfigPath = "$USB_Drive\Shared\config\models.json"
if (-Not (Test-Path $modelsConfigPath)) {
    Write-Host "ERROR: Missing shared model config at $modelsConfigPath" -ForegroundColor Red
    exit 1
}

try {
    $modelsJson = Get-Content -Raw -Path $modelsConfigPath | ConvertFrom-Json
    $ModelCatalog = @()
    foreach ($m in $modelsJson.desktop_models) {
        $ModelCatalog += @{
            Num      = [int]$m.num
            Name     = [string]$m.name
            File     = [string]$m.file
            URL      = [string]$m.url
            Size     = [string]$m.size
            MinBytes = [long]$m.min_bytes
            Local    = [string]$m.local
            Label    = [string]$m.label
            Badge    = [string]$m.badge
            Prompt   = [string]$m.prompt
        }
    }
} catch {
    Write-Host "ERROR: Failed to parse shared model config: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------
# HELPER: Check USB free space (returns GB)
# -----------------------------------------------------------------
function Get-USBFreeSpaceGB {
    try {
        $driveLetter = (Get-Item $USB_Drive).PSDrive.Name
        $drive = Get-PSDrive $driveLetter -ErrorAction SilentlyContinue
        if ($drive) {
            return [math]::Round($drive.Free / 1GB, 1)
        }
    } catch {}
    return -1
}

# -----------------------------------------------------------------
# HELPER: Verify downloaded file size
# -----------------------------------------------------------------
function Test-DownloadedFile {
    param([string]$Path, [long]$MinSize)
    if (-Not (Test-Path $Path)) { return $false }
    $fileSize = (Get-Item $Path).Length
    return $fileSize -gt $MinSize
}

# -----------------------------------------------------------------
# HELPER: File system of the USB drive (FAT32 cannot hold files > 4 GB)
# -----------------------------------------------------------------
function Get-USBFileSystem {
    try {
        return ([System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($USB_Drive))).DriveFormat
    } catch {}
    return ""
}

# -----------------------------------------------------------------
# HELPER: Download with resume + retry. Returns $true on success.
# -----------------------------------------------------------------
function Invoke-Download {
    param([string]$Url, [string]$Dest, [long]$MinSize, [int]$Attempts = 3)
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "      Retry attempt $attempt of $Attempts (resuming)..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
        }
        # -C - resumes a partial file instead of restarting from zero
        curl.exe -L --fail --ssl-no-revoke --connect-timeout 30 --progress-bar -C - $Url -o $Dest
        $rc = $LASTEXITCODE

        if (Test-DownloadedFile -Path $Dest -MinSize $MinSize) { return $true }

        if ($rc -eq 23) {
            Write-Host "      ERROR: Cannot write to the drive (disk full, write-protected or FAT32 4 GB limit)." -ForegroundColor Red
            return $false
        }
        if ($rc -eq 33) {
            # Server refused to resume: restart clean
            Remove-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
        }
        Write-Host "      Download interrupted (curl exit $rc)." -ForegroundColor Red
    }
    return $false
}

# -----------------------------------------------------------------
# HELPER: Write a Modelfile as UTF-8 *without* BOM (Ollama rejects BOM)
# -----------------------------------------------------------------
function Write-Modelfile {
    param([string]$Path, $Model)
    $prompt = ([string]$Model.Prompt) -replace '"""', '"'
    $content = "FROM ./$($Model.File)`nPARAMETER temperature 0.7`nPARAMETER top_p 0.9`nSYSTEM `"`"`"$prompt`"`"`"`n"
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# -----------------------------------------------------------------
# ENGINE MODEL STORE
# Models are imported WITHOUT copying: the .gguf is moved (an instant
# rename on the same drive) into the engine's blob store and registered
# through the API. This halves the space used and skips the slow copy.
# -----------------------------------------------------------------
$OllamaDataDir = "$USB_Drive\Shared\models\ollama_data"
$OllamaBlobsDir = "$OllamaDataDir\blobs"

function Test-ModelImported {
    param([string]$Local)
    # Ollama 0.40+ stores manifests in manifests-v2\ollama.com, older builds in manifests\registry.ollama.ai
    return (Test-Path "$OllamaDataDir\manifests-v2\ollama.com\library\$Local\latest") -or
           (Test-Path "$OllamaDataDir\manifests\registry.ollama.ai\library\$Local\latest")
}

# SHA256 of a file with a progress line (Get-FileHash shows nothing for minutes)
function Get-FileSha256 {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] (8MB)
        $total = $stream.Length
        $done = 0L
        $lastPct = -1
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $sha.TransformBlock($buffer, 0, $read, $null, 0) | Out-Null
            $done += $read
            $pct = [int](100 * $done / [math]::Max($total, 1))
            if ($pct -ne $lastPct) {
                Write-Host -NoNewline "`r      Checking model file... $pct% "
                $lastPct = $pct
            }
        }
        $sha.TransformFinalBlock($buffer, 0, 0) | Out-Null
        Write-Host ""
        return ([System.BitConverter]::ToString($sha.Hash) -replace '-', '').ToLower()
    } finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

# If a previous run was closed between "move into engine" and "register",
# put the .gguf back where it was so nothing has to be downloaded again.
function Restore-InterruptedImport {
    param($Model)
    $gguf = "$USB_Drive\Shared\models\$($Model.File)"
    $marker = "$gguf.importing"
    if (-Not (Test-Path $marker)) { return }
    $digest = (Get-Content -Raw $marker).Trim()
    $blob = "$OllamaBlobsDir\sha256-$digest"
    if (-Not (Test-Path $gguf) -and (Test-Path $blob) -and -Not (Test-ModelImported $Model.Local)) {
        Move-Item -LiteralPath $blob -Destination $gguf -Force -ErrorAction SilentlyContinue
        Write-Host "      Recovered $($Model.File) from an interrupted import." -ForegroundColor DarkGray
    }
    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
}

# Registers one model in the running engine. Returns $true on success.
function Import-ModelNoCopy {
    param($Model)
    $gguf = "$USB_Drive\Shared\models\$($Model.File)"
    $marker = "$gguf.importing"

    $digest = Get-FileSha256 -Path $gguf
    $blob = "$OllamaBlobsDir\sha256-$digest"
    New-Item -ItemType Directory -Force -Path $OllamaBlobsDir | Out-Null

    $moved = $false
    if (-Not (Test-Path $blob)) {
        Set-Content -LiteralPath $marker -Value $digest -Encoding ASCII
        Move-Item -LiteralPath $gguf -Destination $blob -Force -ErrorAction Stop
        $moved = $true
    }

    $files = @{}
    $files[$Model.File] = "sha256:$digest"
    $body = @{
        model      = $Model.Local
        files      = $files
        system     = [string]$Model.Prompt
        parameters = @{ temperature = 0.7; top_p = 0.9 }
        stream     = $false
    } | ConvertTo-Json -Depth 4

    try {
        $r = Invoke-RestMethod -Uri "http://$PortableOllamaHost/api/create" -Method Post `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json; charset=utf-8" -TimeoutSec 1800
        if ($r.status -ne "success") { throw "engine answered: $($r.status)" }
    } catch {
        Write-Host "      ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($moved) { Move-Item -LiteralPath $blob -Destination $gguf -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
        return $false
    }

    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    # Same model already in the store under another name: the .gguf is a duplicate
    if (-Not $moved) { Remove-Item -LiteralPath $gguf -Force -ErrorAction SilentlyContinue }
    return $true
}

# ================================================================
# START
# ================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PORTABLE AI USB - Multi-Model Setup                    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Show USB free space
$freeGB = Get-USBFreeSpaceGB
if ($freeGB -gt 0) {
    Write-Host "  USB Free Space: $freeGB GB" -ForegroundColor DarkGray
    Write-Host ""
}

# =================================================================
# STEP 1: MODEL SELECTION MENU
# =================================================================
Write-Host "[1/7] Choose your AI model(s):" -ForegroundColor Yellow
Write-Host ""

foreach ($m in $ModelCatalog) {
    $numStr   = "  [$($m.Num)]"
    $nameStr  = " $($m.Name)"
    $sizeStr  = " (~$($m.Size) GB)"

    if ($m.Label -eq "UNCENSORED") {
        $labelStr   = " [UNCENSORED]"
        $labelColor = "Red"
    } else {
        $labelStr   = " [STANDARD]"
        $labelColor = "DarkCyan"
    }

    $badgeStr = ""
    if ($m.Badge) { $badgeStr = " - $($m.Badge)" }

    Write-Host $numStr  -ForegroundColor Yellow    -NoNewline
    Write-Host $nameStr -ForegroundColor White     -NoNewline
    Write-Host $sizeStr -ForegroundColor DarkGray  -NoNewline
    Write-Host $labelStr -ForegroundColor $labelColor -NoNewline
    Write-Host $badgeStr -ForegroundColor Magenta
}

Write-Host ""
Write-Host "  [C] CUSTOM - Enter your own HuggingFace GGUF URL" -ForegroundColor Green
Write-Host ""
Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Enter number(s) separated by commas  (e.g. 1,3)" -ForegroundColor Gray
Write-Host "  Type 'all' for every preset model" -ForegroundColor Gray
Write-Host "  Type 'c' to add a custom model" -ForegroundColor Gray
Write-Host "  Mix them!  (e.g. 1,3,c)" -ForegroundColor Gray
Write-Host ""

$UserChoice = Read-Host "  Your choice"

if ([string]::IsNullOrWhiteSpace($UserChoice)) {
    Write-Host ""
    Write-Host "  No input! Defaulting to [1] Gemma 2 2B (recommended)..." -ForegroundColor Yellow
    $UserChoice = "1"
}

# -----------------------------------------------------------------
# Parse the user's selection
# -----------------------------------------------------------------
$SelectedModels = @()
$HasCustom = $false

# Check for 'all'
if ($UserChoice.Trim().ToLower() -eq "all") {
    $SelectedModels = @($ModelCatalog)
} else {
    $tokens = $UserChoice -split ","
    foreach ($token in $tokens) {
        $t = $token.Trim().ToLower()
        if ($t -eq "c" -or $t -eq "custom") {
            $HasCustom = $true
        } elseif ($t -match '^\d+$') {
            $num = [int]$t
            $found = $ModelCatalog | Where-Object { $_.Num -eq $num }
            if ($found) {
                # Avoid duplicates
                $alreadyAdded = $SelectedModels | Where-Object { $_.Num -eq $num }
                if (-Not $alreadyAdded) {
                    $SelectedModels += $found
                }
            } else {
                Write-Host "  Invalid number '$num' - skipping (valid: 1-$($ModelCatalog.Count))" -ForegroundColor Red
            }
        } else {
            Write-Host "  Unrecognized input '$t' - skipping" -ForegroundColor Red
        }
    }
}

# -----------------------------------------------------------------
# Handle custom model input
# -----------------------------------------------------------------
if ($HasCustom) {
    Write-Host ""
    Write-Host "  ---- Custom Model Setup ----" -ForegroundColor Green
    Write-Host "  Paste a direct link to a .gguf file from HuggingFace." -ForegroundColor Gray
    Write-Host "  Example: https://huggingface.co/user/model-GGUF/resolve/main/model-Q4_K_M.gguf" -ForegroundColor DarkGray
    Write-Host ""

    $customURL = Read-Host "  GGUF URL"

    if ([string]::IsNullOrWhiteSpace($customURL)) {
        Write-Host "  No URL entered - skipping custom model." -ForegroundColor Red
    } elseif ($customURL -notmatch "\.gguf") {
        Write-Host "  WARNING: URL does not end in .gguf - this may not be a valid model file." -ForegroundColor Red
        $proceed = Read-Host "  Try anyway? (yes/no)"
        if ($proceed.Trim().ToLower() -ne "yes" -and $proceed.Trim().ToLower() -ne "y") {
            Write-Host "  Skipping custom model." -ForegroundColor Yellow
            $customURL = $null
        }
    }

    if ($customURL) {
        # Extract filename from URL
        $customFile = $customURL.Split("/")[-1].Split("?")[0]
        if (-Not $customFile.EndsWith(".gguf")) { $customFile = "$customFile.gguf" }

        $customLocalName = Read-Host "  Give it a short name (e.g. mymodel-local)"
        if ([string]::IsNullOrWhiteSpace($customLocalName)) {
            $customLocalName = "custom-local"
        }
        # Sanitize: lowercase, replace spaces with dashes
        $customLocalName = $customLocalName.Trim().ToLower() -replace '\s+', '-'
        if ($customLocalName -notmatch '-local$') { $customLocalName = "$customLocalName-local" }

        $customPrompt = Read-Host "  System prompt (press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($customPrompt)) {
            $customPrompt = "You are a helpful AI assistant."
        }

        $customModel = @{
            Num      = 99
            Name     = "Custom: $customFile"
            File     = $customFile
            URL      = $customURL.Trim()
            Size     = "?"
            MinBytes = 100000000   # At least 100 MB to be considered valid
            Local    = $customLocalName
            Label    = "CUSTOM"
            Badge    = ""
            Prompt   = $customPrompt
        }

        $SelectedModels += $customModel
        Write-Host "  Custom model added!" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------
# Validate we have at least one model
# -----------------------------------------------------------------
if ($SelectedModels.Count -eq 0) {
    Write-Host ""
    Write-Host "  ERROR: No models selected!" -ForegroundColor Red
    Write-Host "  Please run the installer again and pick at least one model." -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit 1
}

# -----------------------------------------------------------------
# FAT32 check: files larger than 4 GB cannot be stored at all
# -----------------------------------------------------------------
$fileSystem = Get-USBFileSystem
if ($fileSystem -eq "FAT32" -or $fileSystem -eq "FAT") {
    $tooBig = @($SelectedModels | Where-Object { $_.Size -ne "?" -and [double]$_.Size -ge 4.0 })
    if ($tooBig.Count -gt 0) {
        Write-Host ""
        Write-Host "  =============================================" -ForegroundColor Red
        Write-Host "  This drive is formatted as $($fileSystem): it cannot store files bigger than 4 GB." -ForegroundColor Red
        foreach ($m in $tooBig) {
            Write-Host "    - Skipping $($m.Name) (~$($m.Size) GB)" -ForegroundColor Red
        }
        Write-Host "  To use these models, back up the drive and format it as exFAT or NTFS." -ForegroundColor Yellow
        Write-Host "  =============================================" -ForegroundColor Red
        $SelectedModels = @($SelectedModels | Where-Object { $tooBig -notcontains $_ })
        if ($SelectedModels.Count -eq 0) {
            Write-Host ""
            Write-Host "  No selected model fits on a $fileSystem drive. Pick model 1 or 6, or reformat." -ForegroundColor Red
            exit 1
        }
    }
}

# -----------------------------------------------------------------
# Space check: models are stored once; the engine needs ~5 GB while
# it is being unpacked (zip + extracted files).
# -----------------------------------------------------------------
$totalSizeGB = 0
foreach ($m in $SelectedModels) {
    if ($m.Size -ne "?" -and -Not (Test-ModelImported $m.Local)) { $totalSizeGB += [double]$m.Size }
}
$neededGB = [math]::Ceiling($totalSizeGB + 5)

if ($SelectedModels.Count -ge 3 -or $UserChoice.Trim().ToLower() -eq "all" -or ($freeGB -gt 0 -and $freeGB -lt $neededGB)) {
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Red
    Write-Host "  WARNING: You selected $($SelectedModels.Count) model(s)!" -ForegroundColor Red
    Write-Host "  Estimated download: ~$totalSizeGB GB" -ForegroundColor Red
    Write-Host "  Drive needs up to ~$neededGB GB free (models + AI engine)." -ForegroundColor Red

    if ($freeGB -gt 0 -and $freeGB -lt $neededGB) {
        Write-Host ""
        Write-Host "  You only have $freeGB GB free - this may NOT fit!" -ForegroundColor Yellow
    }

    Write-Host "  =============================================" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "  Continue? (yes/no)"
    if ($confirm.Trim().ToLower() -ne "yes" -and $confirm.Trim().ToLower() -ne "y") {
        Write-Host "  Cancelled. Run the installer again to choose fewer models." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        exit 1
    }
}

# -----------------------------------------------------------------
# Show selection summary
# -----------------------------------------------------------------
Write-Host ""
Write-Host "  Selected $($SelectedModels.Count) model(s):" -ForegroundColor Green
foreach ($m in $SelectedModels) {
    $sizeInfo = if ($m.Size -ne "?") { " (~$($m.Size) GB)" } else { "" }
    Write-Host "    + $($m.Name)$sizeInfo" -ForegroundColor White
}
Write-Host ""

# =================================================================
# STEP 2: Create folder structure
# =================================================================
Write-Host "[2/7] Verifying USB folder structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$USB_Drive\Shared\models" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\Shared\bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\Shared\vendor" | Out-Null
Write-Host "      Done." -ForegroundColor Green

# =================================================================
# STEP 3: Download optional UI vendor assets for offline mode
# =================================================================
Write-Host ""
Write-Host "[3/7] Downloading UI assets (offline markdown/pdf/fonts)..." -ForegroundColor Yellow

$vendorDir = "$USB_Drive\Shared\vendor"
$vendorScript = "$USB_Drive\Shared\scripts\download-ui-assets.ps1"
if (Test-Path $vendorScript) {
    powershell -ExecutionPolicy Bypass -File $vendorScript -VendorDir $vendorDir
} else {
    Write-Host "      WARNING: Shared vendor bootstrap script not found. Skipping." -ForegroundColor Yellow
}

# =================================================================
# STEP 4: Download selected AI models
# =================================================================
Write-Host ""
Write-Host "[4/7] Downloading AI Model(s)..." -ForegroundColor Yellow

$downloadErrors = @()
$modelIndex = 0

foreach ($m in $SelectedModels) {
    $modelIndex++
    $dest = "$USB_Drive\Shared\models\$($m.File)"
    $sizeInfo = if ($m.Size -ne "?") { "(~$($m.Size) GB)" } else { "" }

    Write-Host ""
    Write-Host "  ($modelIndex/$($SelectedModels.Count)) $($m.Name) $sizeInfo" -ForegroundColor Yellow

    # Already inside the engine: the .gguf was moved there, nothing to download
    if (Test-ModelImported $m.Local) {
        Write-Host "      Already installed in the AI engine! Skipping..." -ForegroundColor Green
        continue
    }
    Restore-InterruptedImport -Model $m

    # Check if already downloaded
    if (Test-DownloadedFile -Path $dest -MinSize $m.MinBytes) {
        Write-Host "      Already downloaded! Skipping..." -ForegroundColor Green
        continue
    }

    # Also check for legacy Dolphin Q5_K_M if downloading Dolphin Q4_K_M
    if ($m.Local -eq "dolphin-local") {
        $legacyFile = "$USB_Drive\Shared\models\dolphin-2.9-llama3-8b-Q5_K_M.gguf"
        if (Test-DownloadedFile -Path $legacyFile -MinSize 4000000000) {
            Write-Host "      Found existing Dolphin Q5_K_M - using that instead!" -ForegroundColor Green
            $m.File = "dolphin-2.9-llama3-8b-Q5_K_M.gguf"
            continue
        }
    }

    Write-Host "      Downloading... This may take a while. Do NOT close this window!" -ForegroundColor Magenta

    if (Test-Path $dest) {
        Write-Host "      Found a partial download - resuming where it stopped." -ForegroundColor DarkGray
    }

    $success = Invoke-Download -Url $m.URL -Dest $dest -MinSize $m.MinBytes
    if (-Not $success -and (Test-Path $dest)) {
        $actualSize = [math]::Round((Get-Item $dest).Length / 1GB, 2)
        Write-Host "      File is incomplete ($actualSize GB). Re-run install.bat to resume." -ForegroundColor Red
    }

    if ($success) {
        Write-Host "      Download complete!" -ForegroundColor Green
    } else {
        $downloadErrors += $m.Name
        Write-Host "      ERROR: Download failed for $($m.Name)!" -ForegroundColor Red
        Write-Host "      You can manually download it from:" -ForegroundColor DarkGray
        Write-Host "      $($m.URL)" -ForegroundColor DarkGray
        Write-Host "      Place the file in: $USB_Drive\Shared\models\" -ForegroundColor DarkGray
    }
}

# =================================================================
# STEP 5: Create Modelfile configuration for each model
# =================================================================
Write-Host ""
Write-Host "[5/7] Creating AI model configurations..." -ForegroundColor Yellow

foreach ($m in $SelectedModels) {
    $modelfilePath = "$USB_Drive\Shared\models\Modelfile-$($m.Local)"
    Write-Modelfile -Path $modelfilePath -Model $m
    Write-Host "      Config: $($m.Name) -> $($m.Local)" -ForegroundColor Green
}

# Also create a legacy "Modelfile" pointing to the first selected model (backward compat)
$firstModel = $SelectedModels[0]
Write-Modelfile -Path "$USB_Drive\Shared\models\Modelfile" -Model $firstModel

# Save installed models list for reference
$installedList = $SelectedModels | ForEach-Object { "$($_.Local)|$($_.Name)|$($_.Label)" }
Set-Content -Path "$USB_Drive\Shared\models\installed-models.txt" -Value ($installedList -join "`n") -Force -Encoding UTF8
Write-Host "      Saved model list to installed-models.txt" -ForegroundColor DarkGray

# =================================================================
# STEP 6: Download Ollama (the AI engine)
# =================================================================
Write-Host ""
Write-Host "[6/7] Downloading Ollama AI Engine (Windows)..." -ForegroundColor Yellow
$BinDir     = "$USB_Drive\Shared\bin"
$OllamaURL  = "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"
$OllamaDest = "$BinDir\ollama-windows-amd64.zip"
$TempOllamaDir = "$BinDir\temp_ollama"
$OllamaExe = "$BinDir\ollama-windows.exe"
# Ollama looks for its runtime in <exe folder>\lib\ollama: the folder layout
# of the zip must be kept (cuda_v12 / cuda_v13 / vulkan share DLL names).
$OllamaLibDir   = "$BinDir\lib\ollama"
$LlamaServerExe = "$OllamaLibDir\llama-server.exe"

function Test-OllamaRuntime {
    return (Test-Path $OllamaExe) -and (Test-Path $LlamaServerExe) -and (Test-Path "$OllamaLibDir\ggml-base.dll")
}

# Runs "ollama -v" to catch a corrupted binary (e.g. "Go runtime crash")
function Test-OllamaBinary {
    try {
        $p = Start-Process -FilePath $OllamaExe -ArgumentList "-v" -WindowStyle Hidden -PassThru
        if (-Not $p.WaitForExit(30000)) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            return $false
        }
        return $p.ExitCode -eq 0
    } catch {
        return $false
    }
}

# Older installers flattened every file of the zip into Shared\bin. Those
# stray DLLs sit next to the exe and get loaded first, mixing versions.
function Remove-OldWindowsRuntime {
    Get-ChildItem -Path $BinDir -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -eq ".dll" -or $_.Name -like "llama-*.exe" -or $_.Name -like "*_LICENSE" -or
        $_.Name -eq "ollama.exe" -or $_.Name -eq "ollama-windows.exe"
    } | Remove-Item -Force -ErrorAction SilentlyContinue
    Remove-Item "$BinDir\lib" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item $TempOllamaDir -Force -Recurse -ErrorAction SilentlyContinue
}

if (Test-OllamaRuntime) {
    Write-Host "      Ollama already installed! Skipping..." -ForegroundColor Green
} else {
    if (Test-Path $OllamaExe) {
        Write-Host "      Existing Ollama install is incomplete or outdated. Re-installing full runtime..." -ForegroundColor Yellow
    }
    Stop-Process -Name "ollama-windows" -Force -ErrorAction SilentlyContinue
    Remove-OldWindowsRuntime

    Write-Host "      The engine is a ~1.6 GB download. Do NOT close this window!" -ForegroundColor Magenta
    if (-Not (Invoke-Download -Url $OllamaURL -Dest $OllamaDest -MinSize 200000000)) {
        Write-Host "      ERROR: Ollama download failed!" -ForegroundColor Red
        $downloadErrors += "Ollama Engine / download"
    } else {
        Write-Host "      Extracting Ollama (can take a few minutes on a USB drive)..." -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Force -Path $TempOllamaDir | Out-Null
            # tar.exe ships with Windows 10+ and is far faster than Expand-Archive
            $tarExe = "$env:SystemRoot\System32\tar.exe"
            if (Test-Path $tarExe) {
                # -m: don't restore file dates (fails on exFAT/FAT32 USB drives).
                # A non-zero exit is only a warning here: the checks below decide.
                & $tarExe -xmf $OllamaDest -C $TempOllamaDir
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "      tar.exe reported warnings (exit $LASTEXITCODE) - verifying files..." -ForegroundColor DarkGray
                }
            } else {
                Expand-Archive -Path $OllamaDest -DestinationPath $TempOllamaDir -Force -ErrorAction Stop
            }

            if (-Not (Test-Path "$TempOllamaDir\ollama.exe")) { throw "ollama.exe missing from the archive" }
            Move-Item -Path "$TempOllamaDir\ollama.exe" -Destination $OllamaExe -Force -ErrorAction Stop
            Move-Item -Path "$TempOllamaDir\lib" -Destination "$BinDir\lib" -Force -ErrorAction Stop

            if (-Not (Test-OllamaRuntime)) { throw "runtime files missing after extraction" }
            if (-Not (Test-OllamaBinary)) { throw "ollama-windows.exe does not start (file corrupted - the drive may be faulty)" }

            Remove-Item $TempOllamaDir -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item $OllamaDest -Force -ErrorAction SilentlyContinue
            Write-Host "      Ollama Setup Complete!" -ForegroundColor Green
        } catch {
            Write-Host "      ERROR: Failed to install Ollama: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "      Re-run install.bat to try again." -ForegroundColor DarkGray
            # Remove the half-installed runtime and the (possibly corrupt) zip
            Remove-OldWindowsRuntime
            Remove-Item $OllamaDest -Force -ErrorAction SilentlyContinue
            $downloadErrors += "Ollama Engine / extraction"
        }
    }
}



# =================================================================
# STEP 7: IMPORT ALL SELECTED MODELS INTO OLLAMA ENGINE
# =================================================================
Write-Host ""
Write-Host "[7/7] Importing AI models into the Ollama engine..." -ForegroundColor Yellow

if (-Not (Test-OllamaRuntime)) {
    Write-Host "      ERROR: Ollama not found! Cannot import models." -ForegroundColor Red
    Write-Host "      Please re-run the installer to download Ollama." -ForegroundColor Red
    $downloadErrors += "Ollama Engine / model import"
} else {
    $env:OLLAMA_MODELS = $OllamaDataDir
    $env:OLLAMA_HOST = $PortableOllamaHost
    # Never let the engine delete a model blob that is not registered yet
    $env:OLLAMA_NOPRUNE = "1"
    New-Item -ItemType Directory -Force -Path $env:OLLAMA_MODELS | Out-Null
    $logDir = "$USB_Drive\Shared\logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $ServerLog = "$logDir\ollama-install.log"
    Set-Location "$USB_Drive\Shared\models"

    # Kill any dangling portable engine left over from a previous run.
    # A system-wide Ollama is left alone: we use our own port.
    Stop-Process -Name "ollama-windows" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $modelsToImport = @()
    foreach ($m in $SelectedModels) {
        $ggufPath = "$USB_Drive\Shared\models\$($m.File)"
        if (Test-ModelImported $m.Local) {
            Write-Host "      $($m.Name) is already imported. Skipping..." -ForegroundColor Green
        } elseif (-Not (Test-DownloadedFile -Path $ggufPath -MinSize $m.MinBytes)) {
            Write-Host "      Skipping $($m.Name) - GGUF file missing or incomplete (download may have failed)" -ForegroundColor Red
            $downloadErrors += "$($m.Name) / model file missing"
        } else {
            $modelsToImport += $m
        }
    }

    if ($modelsToImport.Count -gt 0) {
        Write-Host "      Starting Ollama temporarily to perform import..." -ForegroundColor DarkGray
        $ServerProcess = Start-Process -FilePath $OllamaExe -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError $ServerLog

        Write-Host "      Waiting for Ollama to be ready..." -ForegroundColor DarkGray
        $ready = $false
        for ($i = 1; $i -le 120; $i++) {
            if ($ServerProcess.HasExited) { break }
            try {
                $response = Invoke-RestMethod -Uri "http://$PortableOllamaHost/api/tags" -TimeoutSec 2
                if ($null -ne $response.models) {
                    $ready = $true
                    Write-Host "      Ollama is ready (took ${i}s)." -ForegroundColor Green
                    break
                }
            } catch {}
            Start-Sleep -Seconds 1
        }

        if (-Not $ready) {
            Write-Host "      ERROR: Ollama engine did not start. Skipping import." -ForegroundColor Red
            if (Test-Path $ServerLog) {
                Write-Host "      Last lines of $ServerLog :" -ForegroundColor DarkGray
                Get-Content $ServerLog -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
            }
            $downloadErrors += "Ollama Engine / startup failed"
        }

        if ($ready) {
            foreach ($m in $modelsToImport) {
                Write-Host ""
                Write-Host "      Importing $($m.Name) as '$($m.Local)'..." -ForegroundColor Yellow
                Write-Host "      The file is checked once, then moved into the engine (no copy)." -ForegroundColor DarkGray

                if (Import-ModelNoCopy -Model $m) {
                    Write-Host "      $($m.Name) imported successfully!" -ForegroundColor Green
                } else {
                    Write-Host "      ERROR: Failed to import $($m.Name)" -ForegroundColor Red
                    Write-Host "      Engine log: $ServerLog" -ForegroundColor DarkGray
                    $downloadErrors += "$($m.Name) / import"
                }
            }
        }

        Write-Host "      Stopping temporary Ollama server..." -ForegroundColor DarkGray
        # /T also stops the llama-server runner started by the engine
        if ($ServerProcess -and -Not $ServerProcess.HasExited) {
            taskkill.exe /F /T /PID $ServerProcess.Id 2>$null | Out-Null
        }
        Stop-Process -Name "ollama-windows" -Force -ErrorAction SilentlyContinue
    } elseif ($downloadErrors.Count -eq 0) {
        Write-Host "      Nothing to import - all selected models are ready." -ForegroundColor Green
    } else {
        Write-Host "      ERROR: No models to import!" -ForegroundColor Red
        $downloadErrors += "Model import / no usable model file"
    }
}



# =================================================================
# FINAL SUMMARY
# =================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan

if ($downloadErrors.Count -gt 0) {
    Write-Host "   SETUP NOT COMPLETE                                     " -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  The following had issues:" -ForegroundColor Red
    foreach ($err in $downloadErrors) {
        Write-Host "    ! $err" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Do not start Fast Chat yet: no usable model is guaranteed." -ForegroundColor Yellow
    Write-Host "  Re-run install.bat to retry failed downloads; completed files are skipped." -ForegroundColor Yellow
} else {
    Write-Host "   SETUP COMPLETE! YOUR PORTABLE AI IS READY!             " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
}

Write-Host ""
if ($downloadErrors.Count -eq 0) {
Write-Host "  Installed models:" -ForegroundColor White
foreach ($m in $SelectedModels) {
    if ($m.Label -eq "UNCENSORED") {
        $tag = "[UNCENSORED]"
        $tagColor = "Red"
    } elseif ($m.Label -eq "CUSTOM") {
        $tag = "[CUSTOM]"
        $tagColor = "Green"
    } else {
        $tag = "[STANDARD]"
        $tagColor = "DarkCyan"
    }
    Write-Host "    - $($m.Name) " -ForegroundColor Gray -NoNewline
    Write-Host $tag -ForegroundColor $tagColor
}

Write-Host ""
Write-Host "  To start your AI: Double-click  Windows\start-fast-chat.bat" -ForegroundColor White
Write-Host "  On a Mac/Linux:   Run  start-fast-chat.sh from their folders" -ForegroundColor White
}
Write-Host ""
Write-Host "Press any key to close this installer..." -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
if ($downloadErrors.Count -gt 0) { exit 1 }
exit 0
