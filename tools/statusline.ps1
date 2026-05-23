# agentic-kit statusline — pipeline-aware status bar for Claude Code (Windows).
# Line 1 (always): agent | feature [STAGE] | context bar | cost | lines
# Line 2 (alerts): only rendered when something needs attention
$ErrorActionPreference = 'SilentlyContinue'

$stream = [Console]::OpenStandardInput()
$reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true, 8192)
$raw = $reader.ReadToEnd()
$reader.Dispose()
if (-not $raw) { exit }
$data = $raw | ConvertFrom-Json

# --- JSON fields ---
$model = if ($data.model.display_name) { $data.model.display_name } else { "?" }
$agentName = $data.agent.name
$projectDir = if ($data.workspace.project_dir) { $data.workspace.project_dir } else { $data.workspace.current_dir }
$pct = if ($null -ne $data.context_window.used_percentage) { [math]::Floor([double]$data.context_window.used_percentage) } else { 0 }
$cost = if ($null -ne $data.cost.total_cost_usd) { [double]$data.cost.total_cost_usd } else { 0.0 }
$linesAdded = if ($null -ne $data.cost.total_lines_added) { [int]$data.cost.total_lines_added } else { 0 }
$linesRemoved = if ($null -ne $data.cost.total_lines_removed) { [int]$data.cost.total_lines_removed } else { 0 }

# --- Colors ---
$e = [char]27
$cyan    = "$e[36m"; $magenta = "$e[35m"; $green = "$e[32m"
$yellow  = "$e[33m"; $red     = "$e[31m"; $dim   = "$e[2m"
$bold    = "$e[1m";  $reset   = "$e[0m"

# --- Pipeline state ---
$aktDir = Join-Path $projectDir ".akt"
$activeAgent = $agentName
$slug = ""; $stage = ""; $featCount = 0; $featPath = ""

if (Test-Path $aktDir) {
    $sessionState = Join-Path $aktDir "SESSION-STATE.md"
    $activeFeature = ""

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

    # Count active features
    $featuresDir = Join-Path $aktDir "features"
    if (Test-Path $featuresDir) {
        $featCount = @(Get-ChildItem $featuresDir -Directory).Count
    }

    # Determine pipeline stage
    if ($featPath -and (Test-Path $featPath)) {
        $slug = (Split-Path $featPath -Leaf) -replace '^\d{4}-\d{2}-\d{2}-',''
        $hasSpec = Test-Path (Join-Path $featPath "spec.md")
        $hasUx   = Test-Path (Join-Path $featPath "ux-design.md")
        $hasTech = Test-Path (Join-Path $featPath "tech-plan.md")

        if     (-not $hasSpec) { $stage = "SPEC" }
        elseif (-not $hasUx)   { $stage = "UX" }
        elseif (-not $hasTech) { $stage = "ARCH" }
        else                   { $stage = "BUILD/QA" }
    }
}

# === LINE 1: Compact always-visible bar ===
$l1 = ""

# Agent
if ($activeAgent) { $l1 = "${cyan}@${activeAgent}${reset}" }
else              { $l1 = "${dim}[${model}]${reset}" }

# Feature + stage
if ($slug) {
    $l1 += " ${dim}|${reset} ${magenta}${slug}${reset} ${dim}[${stage}]${reset}"
}

# Context bar (8-wide)
$barWidth = 8
$filled = [math]::Floor($pct * $barWidth / 100)
$empty = $barWidth - $filled
if     ($pct -lt 50) { $barColor = $green }
elseif ($pct -lt 80) { $barColor = $yellow }
else                  { $barColor = $red }
$filledStr = "$([char]0x2593)" * $filled
$emptyStr  = "$([char]0x2591)" * $empty
$bar = "${barColor}${filledStr}${dim}${emptyStr}${reset}"

# Cost + lines
$costFmt = '$' + $cost.ToString("F2")
$linesFmt = "${green}+${linesAdded}${reset}/${red}-${linesRemoved}${reset}"

$l1 += " ${dim}|${reset} ${bar} ${pct}% ${dim}|${reset} ${costFmt} ${dim}|${reset} ${linesFmt}"
Write-Host $l1

# === LINE 2: Conditional alerts ===
if (-not (Test-Path $aktDir)) { exit }

$alerts = @()

# --- Alert: Memory stale (SESSION-STATE.md > 24h) ---
$ssPath = Join-Path $aktDir "SESSION-STATE.md"
if (Test-Path $ssPath) {
    $mtime = (Get-Item $ssPath).LastWriteTime
    $ageHours = [math]::Floor(((Get-Date) - $mtime).TotalHours)
    if ($ageHours -ge 24) {
        $ageDays = [math]::Floor($ageHours / 24)
        $alerts += "${yellow}mem:stale ${ageDays}d${reset}"
    }
}

# --- Alert: Feature stuck (handoff-log.md > 48h) ---
if ($featPath -and (Test-Path $featPath)) {
    $handoff = Join-Path $featPath "handoff-log.md"
    if (Test-Path $handoff) {
        $hoMtime = (Get-Item $handoff).LastWriteTime
        $hoAgeH = [math]::Floor(((Get-Date) - $hoMtime).TotalHours)
        if ($hoAgeH -ge 48) {
            $hoAgeD = [math]::Floor($hoAgeH / 24)
            $alerts += "${red}${slug} STUCK ${hoAgeD}d${reset}"
        }
    }
}

# --- Alert: Yaga investigation active ---
$debugDir = Join-Path $aktDir "debug"
if (Test-Path $debugDir) {
    $activeInv = Get-ChildItem $debugDir -Directory |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($activeInv) {
        $hypo     = Join-Path $activeInv.FullName "hypothesis.md"
        $instLog  = Join-Path $activeInv.FullName "instrumentation-log.md"
        $findings = Join-Path $activeInv.FullName "findings.md"

        $yagaPhase = "hypothesize"
        if ((Test-Path $hypo) -and (Get-Content $hypo | Measure-Object -Line).Lines -gt 5) {
            $yagaPhase = "instrument"
            if ((Test-Path $instLog) -and (Get-Content $instLog | Measure-Object -Line).Lines -gt 3) {
                $yagaPhase = "observe"
            }
            if ((Test-Path $findings) -and (Get-Content $findings | Measure-Object -Line).Lines -gt 3) {
                $yagaPhase = "strip"
            }
        }
        $alerts += "${cyan}yaga:${yagaPhase}${reset}"
    }
}

# --- Alert: Autoresearch ratchet status ---
$ratchetLog = Join-Path $aktDir "autoresearch/runs/ratchet.jsonl"
$rejectedLog = Join-Path $aktDir "autoresearch/runs/rejected.jsonl"
if (Test-Path $ratchetLog) {
    $accepted = (Get-Content $ratchetLog | Measure-Object -Line).Lines
    $rejected = 0
    if (Test-Path $rejectedLog) {
        $rejected = (Get-Content $rejectedLog | Measure-Object -Line).Lines
    }
    $gen = $accepted + $rejected
    $lastLine = Get-Content $ratchetLog | Select-Object -Last 1
    if ($lastLine) {
        try {
            $entry = $lastLine | ConvertFrom-Json
            $score = $entry.proposal_composite
            if ($null -ne $score) {
                $scoreFmt = ([double]$score).ToString("F2")
                $alerts += "${green}ratchet:gen${gen} `u{2191}${scoreFmt}${reset}"
            }
        } catch {}
    }
}

# --- Alert: Multiple active features ---
if ($featCount -gt 1) {
    $alerts += "${dim}${featCount} feats${reset}"
}

# Output line 2 only if alerts exist
if ($alerts.Count -gt 0) {
    $line2 = "${yellow}`u{26A0}${reset} " + ($alerts -join " ${dim}|${reset} ")
    Write-Host $line2
}
