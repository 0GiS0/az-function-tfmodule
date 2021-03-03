###### PROVIDERS ########
provider "azurerm" {
  features {}
}

#Random name
resource "random_pet" "service" {}

#Locals
locals {
  service_name = var.name != "" ? var.name : random_pet.service.id
}


#Resource group
resource "azurerm_resource_group" "rg" {
  name     = local.service_name
  location = var.location
}

#Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = replace(local.service_name, "-", "")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_mode
}

#Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = local.service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

#App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = local.service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

#Function App
resource "azurerm_function_app" "function" {
  name                       = local.service_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.appinsights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
  }
}

#Azure Monitor - Alerts
