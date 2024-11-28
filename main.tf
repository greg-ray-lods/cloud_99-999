# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Variables
variable "subscription_id" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
}

variable "windows_vm_size" {
  description = "Size of the Windows Virtual Machine"
  type        = string
}

variable "ubuntu_vm_size" {
  description = "Size of the Ubuntu Virtual Machine"
  type        = string
}

# Generate Random Passwords for VMs
resource "random_password" "windows_vm_password" {
  length  = 16
  special = true
}

resource "random_password" "ubuntu_vm_password" {
  length  = 16
  special = true
}

# Generate Random IDs for Unique Names
resource "random_id" "storage_suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "goat" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "goat" {
  name                = "goat-vnet"
  location            = azurerm_resource_group.goat.location
  resource_group_name = azurerm_resource_group.goat.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "goat" {
  name                 = "goat-subnet"
  resource_group_name  = azurerm_resource_group.goat.name
  virtual_network_name = azurerm_virtual_network.goat.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IPs
resource "azurerm_public_ip" "windows_vm_ip" {
  name                = "windows-vm-ip"
  location            = azurerm_resource_group.goat.location
  resource_group_name = azurerm_resource_group.goat.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "ubuntu_vm_ip" {
  name                = "ubuntu-vm-ip"
  location            = azurerm_resource_group.goat.location
  resource_group_name = azurerm_resource_group.goat.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interfaces
resource "azurerm_network_interface" "windows_nic" {
  name                = "windows-nic"
  location            = azurerm_resource_group.goat.location
  resource_group_name = azurerm_resource_group.goat.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.goat.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_vm_ip.id
  }
}

resource "azurerm_network_interface" "ubuntu_nic" {
  name                = "ubuntu-nic"
  location            = azurerm_resource_group.goat.location
  resource_group_name = azurerm_resource_group.goat.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.goat.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu_vm_ip.id
  }
}

# Windows VM
resource "azurerm_virtual_machine" "windows_vm" {
  name                  = "windows-vm"
  location              = azurerm_resource_group.goat.location
  resource_group_name   = azurerm_resource_group.goat.name
  network_interface_ids = [azurerm_network_interface.windows_nic.id]
  vm_size               = var.windows_vm_size

  storage_os_disk {
    name              = "windows-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = 127
  }

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "windows-vm"
    admin_username = "azureuser"
    admin_password = random_password.windows_vm_password.result
  }

  os_profile_windows_config {
    provision_vm_agent = true
    enable_automatic_upgrades = true
  }
}

# Ubuntu VM
resource "azurerm_virtual_machine" "ubuntu_vm" {
  name                  = "ubuntu-vm"
  location              = azurerm_resource_group.goat.location
  resource_group_name   = azurerm_resource_group.goat.name
  network_interface_ids = [azurerm_network_interface.ubuntu_nic.id]
  vm_size               = var.ubuntu_vm_size

  storage_os_disk {
    name              = "ubuntu-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = 30
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "ubuntu-vm"
    admin_username = "azureuser"
    admin_password = random_password.ubuntu_vm_password.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Azure Storage Account
resource "azurerm_storage_account" "goat" {
  name                     = "storacct${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.goat.name
  location                 = azurerm_resource_group.goat.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
