# Inputs: what differs between dev, stage and prod. Names are derived inside.

variable "env" {
  description = "Environment name: dev, stage, prod."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "canadacentral"
}

variable "node_vm_size" {
  description = "VM size of the nodes. System pools need at least 2 vCPUs and 4 GB."
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the system pool."
  type        = number
}
