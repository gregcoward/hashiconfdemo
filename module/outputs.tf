output mgmtPublicIP {
  value = module.bigip.*.mgmtPublicIP
}

output mgmtPublicDNS {
  value = module.bigip.*.mgmtPublicDNS
}
output bigip_username {
  value = module.bigip.*.f5_username
}

output bigip_password {
  value = module.bigip.*.bigip_password
}

output internal_self {
  value = module.bigip
}

output mgmtPort {
  value = module.bigip.*.mgmtPort
}

output mgmtPublicURL {
  description = "mgmtPublicURL"
  value       = [for i in range(var.instance_count) : format("https://%s:%s", module.bigip[i].mgmtPublicDNS, module.bigip[i].mgmtPort)]
}

output declaration {
  value       = "https://${module.bigip.0.mgmtPublicDNS}:8443${var.rest_ts_uri}"
}

output resourcegroup_name {
  description = "Resource Group in which objects are created"
  value = azurerm_resource_group.rg.name
} 
