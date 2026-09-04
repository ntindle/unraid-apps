$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $repoRoot 'templates\executor.xml'
$profilePath = Join-Path $repoRoot 'ca_profile.xml'
$iconPath = Join-Path $repoRoot 'images\executor.png'

function Assert-Equal {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Actual,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Expected,
        [Parameter(Mandatory)] [string] $Label
    )
    if ($Actual -cne $Expected) {
        throw "$Label mismatch. Expected '$Expected', got '$Actual'."
    }
}

function Xml-Value {
    param(
        [Parameter(Mandatory)] [xml] $Document,
        [Parameter(Mandatory)] [string] $XPath,
        [string] $Attribute
    )
    $node = $Document.SelectSingleNode($XPath)
    if ($null -eq $node) { throw "Missing XML node: $XPath" }
    if ($Attribute) { return [string]$node.GetAttribute($Attribute) }
    return [string]$node.InnerText
}

[xml]$template = Get-Content -LiteralPath $templatePath -Raw
[xml]$profile = Get-Content -LiteralPath $profilePath -Raw

if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw 'Missing images/executor.png.'
}

$iconSha = (Get-FileHash -LiteralPath $iconPath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Equal $iconSha 'b397f102f789c00365cc7910be4f1b297bef7fcacd6592b7f66f227f3388cfc8' 'Icon SHA-256'
Assert-Equal (Xml-Value $template '/Container/Repository') 'ghcr.io/usefulsoftwareco/executor-selfhost:latest' 'Repository'
Assert-Equal (Xml-Value $template '/Container/Network') 'bridge' 'Network'
Assert-Equal (Xml-Value $template '/Container/Privileged') 'false' 'Privileged'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Web UI and MCP Port"]' 'Target') '4788' 'Container port'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="App Data"]' 'Target') '/data' 'Data target'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="App Data"]' 'Default') '/mnt/user/appdata/executor' 'Data default'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Web Base URL"]' 'Target') 'EXECUTOR_WEB_BASE_URL' 'Web base variable'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Web Base URL"]' 'Required') 'true' 'Web base required flag'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Allow Local Network"]') 'false' 'Local-network default'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Allow Stdio MCP"]') 'false' 'Stdio MCP default'
Assert-Equal (Xml-Value $template '/Container/Config[@Name="Disable Anonymous Analytics"]') 'false' 'Analytics opt-out default'
Assert-Equal (Xml-Value $template '/Container/TemplateURL') 'https://raw.githubusercontent.com/ntindle/executor-unraid/main/templates/executor.xml' 'Template URL'
Assert-Equal (Xml-Value $template '/Container/Support') 'https://github.com/ntindle/executor-unraid/issues' 'Support URL'
Assert-Equal (Xml-Value $profile '/CommunityApplications/Forum') 'https://github.com/ntindle/executor-unraid/issues' 'Profile support URL'
Assert-Equal (Xml-Value $template '/Container/Beta') 'true' 'Beta marker'
Assert-Equal (Xml-Value $template '/Container/ExtraParams') '--restart=unless-stopped --log-driver json-file --log-opt max-size=10m --log-opt max-file=3' 'Extra parameters'

$profileText = Xml-Value $profile '/CommunityApplications/Profile'
if ([string]::IsNullOrWhiteSpace($profileText)) { throw 'Community Applications profile must not be empty.' }

$targets = @($template.SelectNodes('/Container/Config') | ForEach-Object { $_.GetAttribute('Target') })
$duplicateTargets = @($targets | Group-Object | Where-Object Count -gt 1)
if ($duplicateTargets.Count -gt 0) {
    throw "Duplicate Config target(s): $($duplicateTargets.Name -join ', ')"
}

$publicFiles = @(
    $templatePath,
    $profilePath,
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'CONTRIBUTING.md'),
    (Join-Path $repoRoot 'SECURITY.md'),
    (Join-Path $repoRoot 'BRANDING.md'),
    (Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md')
)
$forbidden = 'REPLACE_WITH_|YOUR_GITHUB_USERNAME|YOUR_REPO_NAME|change-me|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY'
$matches = Select-String -LiteralPath $publicFiles -Pattern $forbidden
if ($matches) {
    $matchedPaths = ($matches.Path | Select-Object -Unique) -join ', '
    throw "Public files contain a placeholder or secret-like value: $matchedPaths"
}

Write-Output 'Executor Unraid template validation passed'
