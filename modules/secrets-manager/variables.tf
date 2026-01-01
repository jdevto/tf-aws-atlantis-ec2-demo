variable "secret_name_prefix" {
  description = "Prefix for the secret name"
  type        = string
}

variable "secret_name" {
  description = "Name suffix for the secret (will be combined with prefix)"
  type        = string
}

variable "secret_value" {
  description = "Value to store in the secret"
  type        = string
  sensitive   = true
}

variable "description" {
  description = "Description of the secret"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the secret"
  type        = map(string)
  default     = {}
}
