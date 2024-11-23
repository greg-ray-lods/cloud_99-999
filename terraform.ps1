# Variables
$TFMainURL = "https://raw.githubusercontent.com/greg-ray-lods/cloud_99-999/refs/heads/main/main.tf"
$WSLPath = "\\wsl.localhost\Ubuntu\root\AzureGoat"
$TFMainPath = "$WSLPath\main.tf"
$AzureSubscriptionId = "@lab.CloudSubscription.Id" # Subscription ID from your environment

# Step 1: Ensure required variables are set
Write-Host "Validating environment variables..." -ForegroundColor Green
if (-Not $AzureSubscriptionId) {
    Write-Host "Error: Subscription ID is not set." -ForegroundColor Red
    Exit 1
}
if (-Not (Test-Path -Path $WSLPath)) {
    Write-Host "Error: WSL path does not exist: $WSLPath" -ForegroundColor Red
    Exit 1
}

# Step 2: Download the main.tf file to the WSL location
Write-Host "Downloading Terraform configuration..." -ForegroundColor Green
try {
    Invoke-WebRequest -Uri $TFMainURL -OutFile $TFMainPath -ErrorAction Stop
    Write-Host "Terraform configuration downloaded to $TFMainPath" -ForegroundColor Green
} catch {
    Write-Host "Error downloading Terraform configuration: $_" -ForegroundColor Red
    Exit 1
}

# Step 3: Verify the main.tf file exists in WSL
if (-Not (Test-Path $TFMainPath)) {
    Write-Host "Error: main.tf file not found at $TFMainPath" -ForegroundColor Red
    Exit 1
}

# Step 4: Set permissions for main.tf in WSL
Write-Host "Setting permissions for main.tf in WSL2..." -ForegroundColor Green
try {
    wsl chmod 644 /root/AzureGoat/main.tf
    Write-Host "Permissions set successfully." -ForegroundColor Green
} catch {
    Write-Host "Error setting permissions in WSL: $_" -ForegroundColor Red
    Exit 1
}

# Step 5: Initialize Terraform in WSL
Write-Host "Initializing Terraform..." -ForegroundColor Green
try {
    $TerraformInit = wsl terraform -chdir=/root/AzureGoat init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error during Terraform initialization: $TerraformInit" -ForegroundColor Red
        Exit 1
    }
    Write-Host "Terraform initialization completed successfully." -ForegroundColor Green
} catch {
    Write-Host "Error during Terraform initialization: $_" -ForegroundColor Red
    Exit 1
}

# Step 6: Apply the Terraform configuration with the Subscription ID
Write-Host "Applying Terraform configuration..." -ForegroundColor Green
try {
    $TerraformApply = wsl terraform -chdir=/root/AzureGoat apply -auto-approve -var "subscription_id=$AzureSubscriptionId"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error during Terraform apply: $TerraformApply" -ForegroundColor Red
        Exit 1
    }
    Write-Host "Terraform apply completed successfully." -ForegroundColor Green
} catch {
    Write-Host "Error during Terraform apply: $_" -ForegroundColor Red
    Exit 1
}

# Step 7: Completion message
Write-Host "Terraform provisioning complete. All resources have been provisioned in Azure." -ForegroundColor Green
