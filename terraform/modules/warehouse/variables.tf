variable "name" {
  description = "Fully-qualified warehouse name."
  type        = string
}

variable "size" {
  description = "Snowflake warehouse size (e.g. XSMALL, SMALL)."
  type        = string
}

variable "auto_suspend" {
  description = "Seconds of inactivity before auto suspend."
  type        = number
  default     = 300
}

variable "auto_resume" {
  description = "Whether the warehouse resumes automatically on query."
  type        = bool
  default     = true
}

variable "comment" {
  description = "Optional warehouse comment."
  type        = string
  default     = null
}

variable "initially_suspended" {
  description = "Start the warehouse in a suspended state."
  type        = bool
  default     = true
}
