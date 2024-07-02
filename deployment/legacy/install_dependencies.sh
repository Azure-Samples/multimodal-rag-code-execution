# Ensure Chocolatey is installed
if ! command -v choco &> /dev/null; then
    echo "Installing Chocolatey..."
    /bin/bash -c "$(curl -fsSL https://chocolatey.org/install.sh)"
else
    echo "Chocolatey is already installed."
fi

# Install Git for Windows (includes Git Bash)
if ! command -v git &> /dev/null; then
    echo "Installing Git for Windows..."
    choco install git -y
else
    echo "Git for Windows is already installed."
fi

# Install Docker Desktop
if ! command -v docker &> /dev/null; then
    echo "Installing Docker Desktop..."
    choco install docker-desktop -y
else
    echo "Docker Desktop is already installed."
fi

# Install Azure CLI
if ! command -v az &> /dev/null; then
    echo "Installing Azure CLI..."
    choco install azure-cli -y
else
    echo "Azure CLI is already installed."
fi

# Install jq
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    choco install jq -y
else
    echo "jq is already installed."
fi

# Install Visual Studio Code
if ! command -v code &> /dev/null; then
    echo "Installing Visual Studio Code..."
    choco install vscode -y
else
    echo "Visual Studio Code is already installed."
fi

# Check if Bicep is installed
if ! command -v az bicep &> /dev/null; then
    echo "Bicep is not installed."
    echo "Installing Bicep..."
    az bicep install
    choco install bicep -y
else
    echo "Bicep is already installed."
fi