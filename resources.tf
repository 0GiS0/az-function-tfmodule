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
  application_type    = "Node.JS"
}

#App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = local.service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  reserved            = true # this has to be set to true for Linux. Not related to the Premium Plan
  sku {
    tier = "Dynamic"
    size = "Y1"
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
  os_type                    = "linux"
  version                    = "~3"

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.appinsights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

#Azure Monitor - Alerts
# Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = local.service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  # retention_in_days   = "${var.retention_period}"
}

# Action Group
resource "azurerm_monitor_action_group" "actiongroup" {
  name                = local.service_name
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "action"

  webhook_receiver {
    name        = "webhook-test"
    service_uri = "http://www.returngis.net"
  }
}

# Alert
resource "azurerm_monitor_metric_alert" "functionalert" {
  name                = "func-metricalert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_insights.appinsights.id]
  description         = "Action will be triggered when the request execution time is greater than 20ms."

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "performanceCounters/requestExecutionTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 20
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
