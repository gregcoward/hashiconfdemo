# Main

# Terraform Version Pinning
terraform {
  required_version = "~> 0.13.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.1.0"
    }
    aws = {
      source = "hashicorp/aws"
    }
    bigip = {
      source = "f5networks/bigip"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

# Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.sp_subscription_id
  client_id       = var.sp_client_id
  client_secret   = var.sp_client_secret
  tenant_id       = var.sp_tenant_id
}

# AWS Provider
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret
}

# Select the correct zone from Route53
data "aws_route53_zone" "selected" {
  name         = "aserracorp.com."
  private_zone = false
}

#
# Create a random id
#
resource random_id id {
  byte_length = 2
}

#
# Create a resource group
#
resource "azurerm_resource_group" "f5-hashiconf-rg2" {
  name     = format("%s-rg-%s", var.prefix, random_id.id.hex)
  location = var.location
}

# Create Log Analytic Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = format("%s-law-%s", var.prefix, random_id.id.hex)
  sku                 = "PerNode"
  retention_in_days   = 300
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name
  location            = azurerm_resource_group.f5-hashiconf-rg2.location
}

resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = azurerm_resource_group.f5-hashiconf-rg2.location
  resource_group_name   = azurerm_resource_group.f5-hashiconf-rg2.name
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  workspace_name        = azurerm_log_analytics_workspace.law.name
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}

# Create the Storage Account
resource "azurerm_storage_account" "mystorage" {
  name                     = "${var.prefix}mystorage"
  resource_group_name      = azurerm_resource_group.f5-hashiconf-rg2.name
  location                 = azurerm_resource_group.f5-hashiconf-rg2.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}
