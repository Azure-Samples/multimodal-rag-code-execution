
# Ensure Chocolatey is installed
If (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
} Else {
    Write-Host "Chocolatey is already installed."
}

# Install Git for Windows (includes Git Bash)
If (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git for Windows..."
    choco install git -y
} Else {
    Write-Host "Git for Windows is already installed."
}

# Install Docker Desktop
If (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Docker Desktop..."
    choco install docker-desktop -y
} Else {
    Write-Host "Docker Desktop is already installed."
}

# Install Azure CLI
If (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Azure CLI..."
    choco install azure-cli -y
} Else {
    Write-Host "Azure CLI is already installed."
}

# Install jq
If (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "Installing jq..."
    choco install jq -y
} Else {
    Write-Host "jq is already installed."
}

# Install Visual Studio Code
If (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Visual Studio Code..."
    choco install vscode -y
} Else {
    Write-Host "Visual Studio Code is already installed."
}

# Check if Bicep is installed
$bicepInstalled = $false
try {
    $bicepVersion = az bicep version
    if ($bicepVersion -ne $null) {
        $bicepInstalled = $true
    }
} catch {
    Write-Host "Bicep is not installed."
}

# Install Bicep if it's not installed
if (-not $bicepInstalled) {
    Write-Host "Installing Bicep..."
    az bicep install
    choco install bicep -y
} else {
    Write-Host "Bicep is already installed."
}

=======
# Ensure Chocolatey is installed
If (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
} Else {
    Write-Host "Chocolatey is already installed."
}

# Install Git for Windows (includes Git Bash)
If (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git for Windows..."
    choco install git -y
} Else {
    Write-Host "Git for Windows is already installed."
}

# Install Docker Desktop
If (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Docker Desktop..."
    choco install docker-desktop -y
} Else {
    Write-Host "Docker Desktop is already installed."
}

# Install Azure CLI
If (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Azure CLI..."
    choco install azure-cli -y
} Else {
    Write-Host "Azure CLI is already installed."
}

# Install jq
If (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "Installing jq..."
    choco install jq -y
} Else {
    Write-Host "jq is already installed."
}

# Install Visual Studio Code
If (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Visual Studio Code..."
    choco install vscode -y
} Else {
    Write-Host "Visual Studio Code is already installed."
}

# Check if Bicep is installed
$bicepInstalled = $false
try {
    $bicepVersion = az bicep version
    if ($bicepVersion -ne $null) {
        $bicepInstalled = $true
    }
} catch {
    Write-Host "Bicep is not installed."
}

# Install Bicep if it's not installed
if (-not $bicepInstalled) {
    Write-Host "Installing Bicep..."
    az bicep install
    choco install bicep -y
} else {
    Write-Host "Bicep is already installed."
}
