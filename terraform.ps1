# Terraform script
# Execute Script in Virtual Machine
# Machine	Windows 11 Jump Box CUSTOM DEV
# Language	PowerShell
# Blocking	Yes
# Delay	10 Seconds
# Timeout	10 Minutes
# Retries	0
# Error Action	End Lab
# Define Variables
$githubRepo = "https://raw.githubusercontent.com/greg-ray-lods/cloud_99-999/main/main.tf"
$terraformPath = "C:\Users\Admin\Desktop\AzureGoat"
$terraformFile = "$terraformPath\main.tf"
$tfvarsFile = "$terraformPath\terraform.tfvars"
$AzureSubscriptionId = "@lab.CloudSubscription.Id" # Ensure this resolves to your subscription ID
$ErrorActionPreference = 'SilentlyContinue'


# Ensure Terraform Path Exists
if (-not (Test-Path -Path $terraformPath)) {
    Write-Output "Creating directory: $terraformPath"
    New-Item -ItemType Directory -Path $terraformPath -Force
}

# Download Terraform Config File
Write-Output "Downloading Terraform configuration file from $githubRepo..."
Invoke-WebRequest -Uri $githubRepo -OutFile $terraformFile -ErrorAction Stop
Write-Output "Terraform configuration file downloaded to $terraformFile."

# Display the Subscription ID
Write-Output "Azure Subscription ID: $AzureSubscriptionId"

# Create the .tfvars File Dynamically
Write-Output "Creating the Terraform variables file..."
$tfvarsContent = @"
subscription_id     = "$AzureSubscriptionId"
resource_group_name = "azuregoat_app"
location            = "East US"
windows_vm_size     = "Standard_DS1_v2"
ubuntu_vm_size      = "Standard_DS1_v2"
"@

Set-Content -Path $tfvarsFile -Value $tfvarsContent
Write-Output "Terraform variables file created at $tfvarsFile with subscription_id: $AzureSubscriptionId."

# Authenticate with Azure
Write-Output "Authenticating with Azure..."
az login -u "@lab.CloudPortalCredential(goat).Username" -p "@lab.CloudPortalCredential(goat).Password" --output none
az account set --subscription "$AzureSubscriptionId"
Write-Output "Azure authentication completed."

# Change to Terraform Directory
Write-Output "Switching to Terraform directory: $terraformPath"
Set-Location -Path $terraformPath

# Initialize Terraform
Write-Output "Initializing Terraform..."
terraform init

# Plan and Apply Terraform Configuration
Write-Output "Applying Terraform configuration..."
terraform apply -var-file="terraform.tfvars" -auto-approve
Write-Output "Terraform apply completed."
