# agentic-kit statusline — pipeline-aware status bar for Claude Code (Windows).
# Shows active agent + pipeline stage (line 1), context/cost/lines (line 2).
$ErrorActionPreference = 'SilentlyContinue'

$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput())
$raw = $reader.ReadToEnd()
$reader.Close()
$data = $raw | ConvertFrom-Json

# --- JSON fields ---
$model = $data.model.display_name
if (-not $model) { $model = "?" }
$agentName = $data.agent.name
$projectDir = $data.workspace.project_dir
if (-not $projectDir) { $projectDir = $data.workspace.current_dir }
$pct = 0
if ($null -ne $data.context_window.used_percentage) {
    $pct = [math]::Floor([double]$data.context_window.used_percentage)
}
$cost = 0.0
if ($null -ne $data.cost.total_cost_usd) {
    $cost = [double]$data.cost.total_cost_usd
}
$linesAdded = 0
if ($null -ne $data.cost.total_lines_added) {
    $linesAdded = [int]$data.cost.total_lines_added
}
$linesRemoved = 0
if ($null -ne $data.cost.total_lines_removed) {
    $linesRemoved = [int]$data.cost.total_lines_removed
}

# --- Colors (ANSI) ---
$e = [char]27
$cyan    = "$e[36m"
$magenta = "$e[35m"
$green   = "$e[32m"
$yellow  = "$e[33m"
$red     = "$e[31m"
$dim     = "$e[2m"
$reset   = "$e[0m"

# --- Line 1: Agent + Pipeline Stage ---
$aktDir = Join-Path $projectDir ".akt"
$stage = ""
$featureSlug = ""
$activeAgent = $agentName

if (Test-Path $aktDir) {
    $sessionState = Join-Path $aktDir "SESSION-STATE.md"

    if (Test-Path $sessionState) {
        $content = Get-Content $sessionState -Raw
        if ($content -match '(?m)^## Active agent\s*\r?\n(.+)') {
            $sa = $Matches[1].Trim()
            if ($sa -and $sa -notmatch '^\(none') {
                if (-not $activeAgent) { $activeAgent = $sa }
            }
        }
        if ($content -match '(?m)^## Active feature\s*\r?\n(.+)') {
            $af = $Matches[1].Trim()
            if ($af -and $af -notmatch '^\(none') { $activeFeature = $af }
        }
    }

    # Find active feature folder
    $featPath = ""
    if ($activeFeature -and (Test-Path $activeFeature)) {
        $featPath = $activeFeature
    } else {
        $featuresDir = Join-Path $aktDir "features"
        if (Test-Path $featuresDir) {
            $latest = Get-ChildItem $featuresDir -Directory |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($latest) { $featPath = $latest.FullName }
        }
    }

    # Determine pipeline stage from file presence
    if ($featPath -and (Test-Path $featPath)) {
        $featureSlug = (Split-Path $featPath -Leaf) -replace '^\d{4}-\d{2}-\d{2}-',''
        $hasSpec = Test-Path (Join-Path $featPath "spec.md")
        $hasUx   = Test-Path (Join-Path $featPath "ux-design.md")
        $hasTech = Test-Path (Join-Path $featPath "tech-plan.md")

        if (-not $hasSpec)     { $stage = "SPEC" }
        elseif (-not $hasUx)   { $stage = "UX" }
        elseif (-not $hasTech) { $stage = "ARCH" }
        else                   { $stage = "BUILD/QA" }
    }

    # Format line 1
    $line1 = ""
    if ($activeAgent) {
        $line1 = "${cyan}@${activeAgent}${reset}"
    } else {
        $line1 = "${dim}(idle)${reset}"
    }
    if ($featureSlug) {
        $line1 += " ${dim}|${reset} ${magenta}${featureSlug}${reset} ${dim}[${stage}]${reset}"
    }
} else {
    # No .akt/ — simple fallback
    $line1 = "${dim}[${model}]${reset}"
    if ($agentName) { $line1 += " ${cyan}@${agentName}${reset}" }
}

# --- Line 2: Context bar + Cost + Lines ---
$barWidth = 15
$filled = [math]::Floor($pct * $barWidth / 100)
$empty = $barWidth - $filled

if     ($pct -lt 50) { $barColor = $green }
elseif ($pct -lt 80) { $barColor = $yellow }
else                  { $barColor = $red }

$filledStr = "$([char]0x2593)" * $filled
$emptyStr  = "$([char]0x2591)" * $empty
$bar = "${barColor}${filledStr}${dim}${emptyStr}${reset}"

$costFmt = '$' + $cost.ToString("F2")
$linesFmt = "${green}+${linesAdded}${reset}/${red}-${linesRemoved}${reset}"

$line2 = "${bar} ${pct}% ${dim}|${reset} ${costFmt} ${dim}|${reset} ${linesFmt}"

# --- Output ---
Write-Host $line1
Write-Host $line2
