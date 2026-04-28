# ============================================================
# SPCS + dlt リソース
# ============================================================

# --- Role ---

resource "snowflake_account_role" "dlt_role" {
  provider = snowflake.security_admin
  name     = local.dlt.role.name
  comment  = local.dlt.role.comment
}

resource "snowflake_grant_account_role" "dlt_role_to_sysadmin" {
  provider         = snowflake.security_admin
  role_name        = snowflake_account_role.dlt_role.name
  parent_role_name = "SYSADMIN"
}

# --- User ---

resource "snowflake_user" "dlt_user" {
  provider          = snowflake.user_admin
  name              = local.dlt.user.name
  comment           = local.dlt.user.comment
  default_role      = snowflake_account_role.dlt_role.name
  default_warehouse = snowflake_warehouse.dlt_wh.name
  rsa_public_key    = var.DLT_USER_RSA_PUBLIC_KEY
}

resource "snowflake_grant_account_role" "dlt_role_to_dlt_user" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.dlt_role.name
  user_name = snowflake_user.dlt_user.name
}

# --- Database & Schemas ---

resource "snowflake_database" "dlt_demo" {
  provider = snowflake.sysadmin
  name     = local.dlt.database
  comment  = "database for dlt demo pipeline"
}

resource "snowflake_schema" "dlt_public" {
  provider = snowflake.sysadmin
  database = snowflake_database.dlt_demo.name
  name     = "PUBLIC"
}

resource "snowflake_schema" "dlt_raw" {
  provider = snowflake.sysadmin
  database = snowflake_database.dlt_demo.name
  name     = "RAW"
}

# --- Warehouse ---

resource "snowflake_warehouse" "dlt_wh" {
  provider            = snowflake.sysadmin
  name                = local.dlt.warehouse.name
  warehouse_size      = local.dlt.warehouse.size
  auto_suspend        = local.dlt.warehouse.auto_suspend
  auto_resume         = local.dlt.warehouse.auto_resume
  initially_suspended = local.dlt.warehouse.initially_suspended
  comment             = local.dlt.warehouse.comment
}

# --- Image Repository ---

resource "snowflake_image_repository" "my_repo" {
  provider = snowflake.sysadmin
  database = snowflake_database.dlt_demo.name
  schema   = snowflake_schema.dlt_public.name
  name     = "MY_REPO"
}

# --- Secrets ---

resource "snowflake_secret_with_generic_string" "dlt_snowflake_user" {
  provider      = snowflake.sysadmin
  database      = snowflake_database.dlt_demo.name
  schema        = snowflake_schema.dlt_public.name
  name          = "DLT_SNOWFLAKE_USER"
  secret_string = snowflake_user.dlt_user.name
}

resource "snowflake_secret_with_generic_string" "dlt_snowflake_private_key" {
  count         = var.DLT_SNOWFLAKE_PRIVATE_KEY != null ? 1 : 0
  provider      = snowflake.sysadmin
  database      = snowflake_database.dlt_demo.name
  schema        = snowflake_schema.dlt_public.name
  name          = "DLT_SNOWFLAKE_PRIVATE_KEY"
  secret_string = var.DLT_SNOWFLAKE_PRIVATE_KEY
}

# --- Compute Pool (ACCOUNTADMIN required) ---

resource "snowflake_grant_privileges_to_account_role" "create_compute_pool_to_sysadmin" {
  provider          = snowflake.accountadmin
  account_role_name = "SYSADMIN"
  privileges        = ["CREATE COMPUTE POOL"]
  on_account        = true
}

resource "snowflake_compute_pool" "dlt_pool" {
  provider            = snowflake.sysadmin
  depends_on          = [snowflake_grant_privileges_to_account_role.create_compute_pool_to_sysadmin]
  name                = local.dlt.compute_pool.name
  min_nodes           = local.dlt.compute_pool.min_nodes
  max_nodes           = local.dlt.compute_pool.max_nodes
  instance_family     = local.dlt.compute_pool.instance_family
  auto_resume         = local.dlt.compute_pool.auto_resume
  auto_suspend_secs   = local.dlt.compute_pool.auto_suspend_secs
  initially_suspended = local.dlt.compute_pool.initially_suspended
  comment             = local.dlt.compute_pool.comment
}

# --- Stage ---

resource "snowflake_stage" "spcs_specs" {
  provider = snowflake.sysadmin
  database = snowflake_database.dlt_demo.name
  schema   = snowflake_schema.dlt_public.name
  name     = "SPCS_SPECS"
  comment  = "stage for SPCS spec files"
}

# --- Network Rules ---

resource "snowflake_network_rule" "jsonplaceholder_rule" {
  provider   = snowflake.sysadmin
  database   = snowflake_database.dlt_demo.name
  schema     = snowflake_schema.dlt_public.name
  name       = "JSONPLACEHOLDER_RULE"
  mode       = "EGRESS"
  type       = "HOST_PORT"
  value_list = ["jsonplaceholder.typicode.com:443"]
}

resource "snowflake_network_rule" "snowflake_rule" {
  provider   = snowflake.sysadmin
  database   = snowflake_database.dlt_demo.name
  schema     = snowflake_schema.dlt_public.name
  name       = "SNOWFLAKE_RULE"
  mode       = "EGRESS"
  type       = "HOST_PORT"
  value_list = ["${lower(var.SNOWFLAKE_ORGANIZATION)}-${lower(var.SNOWFLAKE_ACCOUNT)}.snowflakecomputing.com:443"]
}

resource "snowflake_network_rule" "s3_stage_rule" {
  count      = var.DLT_S3_STAGE_HOST != null ? 1 : 0
  provider   = snowflake.sysadmin
  database   = snowflake_database.dlt_demo.name
  schema     = snowflake_schema.dlt_public.name
  name       = "S3_STAGE_RULE"
  mode       = "EGRESS"
  type       = "HOST_PORT"
  value_list = ["${var.DLT_S3_STAGE_HOST}:443"]
}

# --- External Access Integration ---
# snowflake_external_access_integration は provider v2.x 未実装のため snowflake_execute で対応

resource "snowflake_execute" "jsonplaceholder_integration" {
  provider = snowflake.sysadmin
  execute  = "CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION JSONPLACEHOLDER_INTEGRATION ALLOWED_NETWORK_RULES = (${local.dlt.database}.PUBLIC.JSONPLACEHOLDER_RULE, ${local.dlt.database}.PUBLIC.SNOWFLAKE_RULE${var.DLT_S3_STAGE_HOST != null ? ", ${local.dlt.database}.PUBLIC.S3_STAGE_RULE" : ""}) ENABLED = TRUE COMMENT = 'external access integration for dlt pipeline'"
  revert   = "DROP EXTERNAL ACCESS INTEGRATION IF EXISTS JSONPLACEHOLDER_INTEGRATION"
  depends_on = [
    snowflake_network_rule.jsonplaceholder_rule,
    snowflake_network_rule.snowflake_rule,
    snowflake_network_rule.s3_stage_rule,
  ]
}

# --- Grants to dlt_role ---
# SYSADMINはdlt_roleを継承するため、dlt_roleへのgrantがそのままSYSADMINに引き継がれる

resource "snowflake_grant_privileges_to_account_role" "dlt_role_warehouse_usage" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.dlt_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_database_usage" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.dlt_demo.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_schema_public" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE", "CREATE SERVICE"]
  on_schema {
    schema_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_schema_raw" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE", "CREATE TABLE"]
  on_schema {
    schema_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_raw.name}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_compute_pool_usage" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "COMPUTE POOL"
    object_name = snowflake_compute_pool.dlt_pool.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_stage_read" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["READ"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}.${snowflake_stage.spcs_specs.name}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_integration_usage" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["USAGE"]
  depends_on        = [snowflake_execute.jsonplaceholder_integration]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = "JSONPLACEHOLDER_INTEGRATION"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_image_repo_read" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["READ"]
  on_schema_object {
    object_type = "IMAGE REPOSITORY"
    object_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}.${snowflake_image_repository.my_repo.name}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_secret_user_read" {
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["READ"]
  on_schema_object {
    object_type = "SECRET"
    object_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}.${snowflake_secret_with_generic_string.dlt_snowflake_user.name}"
  }
}

resource "snowflake_grant_privileges_to_account_role" "dlt_role_secret_key_read" {
  count             = var.DLT_SNOWFLAKE_PRIVATE_KEY != null ? 1 : 0
  provider          = snowflake.security_admin
  account_role_name = snowflake_account_role.dlt_role.name
  privileges        = ["READ"]
  on_schema_object {
    object_type = "SECRET"
    object_name = "${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}.${snowflake_secret_with_generic_string.dlt_snowflake_private_key[0].name}"
  }
}

# --- Account-level grant: EXECUTE TASK to SYSADMIN ---

resource "snowflake_grant_privileges_to_account_role" "execute_task_to_sysadmin" {
  provider          = snowflake.accountadmin
  account_role_name = "SYSADMIN"
  privileges        = ["EXECUTE TASK"]
  on_account        = true
}

# --- Task ---

resource "snowflake_task" "dlt_jsonplaceholder" {
  provider  = snowflake.sysadmin
  database  = snowflake_database.dlt_demo.name
  schema    = snowflake_schema.dlt_public.name
  name      = local.dlt.task.name
  warehouse = snowflake_warehouse.dlt_wh.name

  sql_statement = <<-SQL
    EXECUTE JOB SERVICE
      IN COMPUTE POOL ${snowflake_compute_pool.dlt_pool.name}
      EXTERNAL_ACCESS_INTEGRATIONS = (JSONPLACEHOLDER_INTEGRATION)
      FROM @${snowflake_database.dlt_demo.name}.${snowflake_schema.dlt_public.name}.${snowflake_stage.spcs_specs.name} SPECIFICATION_FILE = 'spec.yaml'
  SQL

  started = false
  comment = local.dlt.task.comment
}
