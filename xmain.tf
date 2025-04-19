terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.84"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "prefix" {
  type    = string
  default = "gptrag"
}

data "azurerm_client_config" "current" {}

locals {
  resource_group_name = "${var.prefix}-rg"
  network_name        = "${var.prefix}-vnet"
  subnet_name         = "${var.prefix}-subnet"
  kv_name             = "${var.prefix}kv"
  sa_name             = lower(replace("${var.prefix}storage", "-", ""))
  ai_name             = "${var.prefix}-appinsights"
  asp_name            = "${var.prefix}-plan"
  search_name         = "${var.prefix}-search"
  cosmos_name         = "${var.prefix}-cosmos"
  openai_name         = "oai0-${var.prefix}"
  tags = {
    environment             = "lab"
    AZURE_NETWORK_ISOLATION = "true"
  }
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = local.network_name
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_subnet" "main" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
}

resource "azurerm_storage_account" "main" {
  name                     = local.sa_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false
  tags                     = local.tags

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
    bypass                     = ["AzureServices"]
  }
}

resource "azurerm_application_insights" "main" {
  name                = local.ai_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-log"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_key_vault" "main" {
  name                        = local.kv_name
  location                    = var.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_enabled         = true
  enable_rbac_authorization   = true
  tags                        = local.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
  }
}

resource "azurerm_service_plan" "main" {
  name                = local.asp_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

resource "azurerm_cognitive_account" "openai" {
  name                = local.openai_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
  tags                = local.tags

  network_acls {
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_search_service" "main" {
  name                = local.search_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "standard"
  partition_count     = 1
  replica_count       = 1
  tags                = local.tags
}

resource "azurerm_cosmosdb_account" "main" {
  name                = local.cosmos_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  enable_automatic_failover = false
  tags                      = local.tags
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "app_insights_name" {
  value = azurerm_application_insights.main.name
}

output "openai_name" {
  value = azurerm_cognitive_account.openai.name
}

output "search_service_name" {
  value = azurerm_search_service.main.name
}

output "cosmos_db_name" {
  value = azurerm_cosmosdb_account.main.name
}
