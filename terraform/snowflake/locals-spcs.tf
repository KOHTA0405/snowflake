locals {
  dlt = {
    database = "DLT_DEMO"

    warehouse = {
      name                = "DLT_WH"
      size                = "XSMALL"
      auto_suspend        = 60
      auto_resume         = true
      initially_suspended = true
      comment             = "warehouse for dlt pipeline"
    }

    role = {
      name    = "DLT_ROLE"
      comment = "service account role for dlt pipeline"
    }

    user = {
      name    = "DLT_USER"
      comment = "service account user for dlt pipeline"
    }

    compute_pool = {
      name                = "DLT_POOL"
      min_nodes           = 1
      max_nodes           = 1
      instance_family     = "CPU_X64_XS"
      auto_resume         = "true"
      auto_suspend_secs   = 60
      initially_suspended = true
      comment             = "compute pool for dlt pipeline"
    }

    task = {
      name    = "RUN_DLT_JSONPLACEHOLDER"
      comment = "daily dlt pipeline job via SPCS"
    }
  }
}
