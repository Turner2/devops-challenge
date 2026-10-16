variable "name" {
  description = "Repository name."
  type        = string
}

variable "keep_image_count" {
  description = "How many images to keep. Older ones are expired, leaving enough history to roll back."
  type        = number
  default     = 20
}

variable "force_delete" {
  description = "Allow `terraform destroy` to delete the repository even if it still has images."
  type        = bool
  default     = false
}
