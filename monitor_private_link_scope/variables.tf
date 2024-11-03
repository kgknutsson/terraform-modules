variable "linked_resource_id" {
  type        = string
  description = "The ID of the linked resource. It must be the Log Analytics workspace or the Application Insights component or the Data Collection endpoint."
}

variable "private_link_scope_id" {
  type        = string
  description = "The Azure Monitor Private Link Scope."
}
