variable "settings" {
  type = object({
    name        = string
    environment = string
    location    = string
    tags        = map(string)
  })
  description = "Global settings."
}
