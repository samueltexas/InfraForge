output "resource_group_name" {
  description = "Foundation Resource Group name."
  value       = module.resource_group.name
}

output "virtual_network_id" {
  description = "Foundation Virtual Network resource ID."
  value       = module.networking.vnet_id
}

output "subnet_ids" {
  description = "Foundation subnet resource IDs."
  value       = module.networking.subnet_ids
}

output "managed_identity_id" {
  description = "Foundation managed identity resource ID."
  value       = module.identity.identity_id
}

output "managed_identity_principal_id" {
  description = "Foundation managed identity principal ID."
  value       = module.identity.principal_id
}
