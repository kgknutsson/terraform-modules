

variable "resource_group_name" {
    type = string
    description = "Name of resource group"
}

variable "subdomain_name" {
    type = string
    description = "Name of the subdomain"
}

variable "private_dns_zone_name_001" {
    type = string
    description = "Name of the private domain"
}

variable "private_dns_zone_name_002" {
    type = string
    description = "Name of the private domain"
}

variable "private_dns_zone_name_003" {
    type = string
    description = "Name of the private domain"
}

variable "cname_records_private_zone_002" {
    type = map(string)
    description = "CNAMEs for carsmart-staging.local"
}

variable "cname_records_private_zone_003" {
    type = map(string)
    description = "CNAME:s for carsmart-production.local"
}

variable "a_records_public_subdomain" {
    type = map(string)
    description = "all A records for public subdomain"
}

variable "a_records_private_zone_001" {
    type = map(string)
    description = "A records for private domain cloud.carsmart.se"
}

variable "a_records_private_zone_002" {
    type = map(string)
    description = "A records for private domain carsmart-staging.local"
}

variable "a_records_private_zone_003" {
    type = map(string)
    description = "A records for private domain carsmart-production.local"
}

resource "azurerm_dns_zone" "subdomain-public" {
  name                = var.subdomain_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone" "domain-private_001" {
  name                = var.private_dns_zone_name_001
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone" "domain-private_002" {
  name                = var.private_dns_zone_name_002
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone" "domain-private_003" {
  name                = var.private_dns_zone_name_003
  resource_group_name = var.resource_group_name
}

//A records for public sub domain
resource "azurerm_dns_a_record" "a_records_public_subdomain" {
  zone_name = var.subdomain_name
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.a_records_public_subdomain
  name = each.key
  records = [ each.value ]
}

//A records and CNAMES for private zones

resource "azurerm_private_dns_a_record" "a_records_private_zone_001" {
  zone_name = var.private_dns_zone_name_001
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.a_records_private_zone_001
  name = each.key
  records = [ each.value ]
}

resource "azurerm_private_dns_a_record" "a_records_private_zone_002" {
  zone_name = var.private_dns_zone_name_002
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.a_records_private_zone_002
  name = each.key
  records = [ each.value ]
}

resource "azurerm_private_dns_cname_record" "cname_records_private_zone_002" {
  zone_name = var.private_dns_zone_name_002
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.cname_records_private_zone_002
  name = each.key
  record = each.value
}

resource "azurerm_private_dns_a_record" "a_records_private_zone_003" {
  zone_name = var.private_dns_zone_name_003
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.a_records_private_zone_003
  name = each.key
  records = [ each.value ]
}

resource "azurerm_private_dns_cname_record" "cname_records_private_zone_003" {
  zone_name = var.private_dns_zone_name_003
  resource_group_name = var.resource_group_name
  ttl = 60
  for_each = var.cname_records_private_zone_003
  name = each.key
  record = each.value 
}