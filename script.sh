RESOURCE_NAME=/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RESOURCE_GROUP}/providers/Microsoft.Insights/components/{RESOURCE_NAME}

az monitor metrics list-definitions --resource $RESOURCE_NAME
az monitor metrics list --resource $RESOURCE_NAME --metric performanceCounters/requestExecutionTime 
