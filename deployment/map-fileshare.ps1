param (
    [string]$RG,
    [string]$DRIVE = "Z"
)
# Force script to be run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You need to run this script as an administrator"
    Start-Sleep -s 5
    exit
}

# Get storage account name and key via Azure CLI
$STORAGE_ACCOUNT_NAME = az storage account list --resource-group $RG --query "[?!(contains(name, 'ml') || contains(name, 'script'))].name" -o tsv
Write-Host "Using Azure Storage Account: $STORAGE_ACCOUNT_NAME"
$STORAGE_ACCOUNT_KEY = az storage account keys list --resource-group $RG --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv
$STORAGE_ACCOUNT_ENDPOINT = az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RG --query "primaryEndpoints.file" -o tsv
# Edit $STORAGE_ACCOUNT_NAME to use '\' instead of '/' and replace https:// with '\\'
$STORAGE_ACCOUNT_ENDPOINT = $STORAGE_ACCOUNT_ENDPOINT -replace "/", "\"
$STORAGE_ACCOUNT_ENDPOINT = $STORAGE_ACCOUNT_ENDPOINT -replace "https:", ""

$MOUNT_URL = "$STORAGE_ACCOUNT_ENDPOINT$STORAGE_ACCOUNT_NAME"
Write-Host "Mounting Azure File Share from $MOUNT_URL to $DRIVE..."

New-PSDrive -Name $DRIVE -PSProvider FileSystem -Root "$MOUNT_URL" -Credential $(New-Object System.Management.Automation.PSCredential ($STORAGE_ACCOUNT_NAME, (ConvertTo-SecureString $STORAGE_ACCOUNT_KEY -AsPlainText -Force)))