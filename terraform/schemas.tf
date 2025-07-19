resource "snowflake_schema" "lake_schema" {
  name     = "lake"
  database = snowflake_database.data_analytics_db.name
}

resource "snowflake_schema" "dwh_schema" {
  name     = "dwh"
  database = snowflake_database.data_analytics_db.name
}

resource "snowflake_schema" "mart_schema" {
  name     = "mart"
  database = snowflake_database.data_analytics_db.name
}
