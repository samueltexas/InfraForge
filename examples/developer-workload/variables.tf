variable "admin_username" {
  description = "Linux administrator username for the workload VM."
  type        = string
  default     = "infraadmin"
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key used to authenticate to the workload VM."
  type        = string

  validation {
    condition = can(regex(
      "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ",
      trimspace(var.admin_ssh_public_key)
    ))

    error_message = "Provide a valid OpenSSH public key."
  }
}
