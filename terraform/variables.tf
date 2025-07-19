variable "SNOWFLAKE_ORGANIZATION" {
  description = "Snowflake organization name"
  type        = string

}

variable "SNOWFLAKE_ACCOUNT" {
  description = "Snowflake account name"
  type        = string
}

variable "SNOWFLAKE_USER" {
  description = "Snowflake user"
  type        = string
}

variable "SNOWFLAKE_PASSWORD" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "SNOWFLAKE_ROLE" {
  description = "Snowflake role"
  type        = string
}
