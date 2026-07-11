# Privileges関連のlocals
locals {
  privileges_to_database_role = {
    "write" = [
      "SELECT",
      "INSERT",
      "UPDATE",
      "DELETE",
      "TRUNCATE"
    ]

    "change_schema" = [
      "USAGE",
      "CREATE TABLE",
      "CREATE VIEW",
      "CREATE FILE FORMAT",
      "CREATE STAGE",
      "CREATE FUNCTION",
      "CREATE PROCEDURE",
      "CREATE SEQUENCE",
      "CREATE PIPE",
      "CREATE STREAM",
      "CREATE TASK",
      "CREATE SNAPSHOT"
    ]

    "read" = [
      "SELECT"
    ]
  }
}

