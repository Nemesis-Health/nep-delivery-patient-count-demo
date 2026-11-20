if (identical(tolower(Sys.getenv("PATIENT_COUNT_DEMO_FAIL", "false")), "true")) {
  stop("Intentional demo failure: patient-count LEP test")
}

suppressPackageStartupMessages(library(DatabaseConnector))

run_patient_count <- function() {
  db_host <- Sys.getenv("OMOP_DB_HOST", "localhost")
  db_port <- as.integer(Sys.getenv("OMOP_DB_PORT", "5432"))
  db_name <- Sys.getenv("OMOP_DB_NAME", "omop")
  db_user <- Sys.getenv("OMOP_DB_USER", "nep_ci")
  db_pass <- Sys.getenv("OMOP_DB_PASS", "")
  cdm_schema <- Sys.getenv("OMOP_CDM_SCHEMA", "synpuf")
  output_dir <- Sys.getenv("OUTPUT_DIR", "/output")

  if (!grepl("^[A-Za-z][A-Za-z0-9_]*$", cdm_schema)) {
    stop("OMOP_CDM_SCHEMA must be a simple PostgreSQL schema name")
  }
  if (is.na(db_port) || db_port < 1L || db_port > 65535L) {
    stop("OMOP_DB_PORT must be a valid TCP port")
  }
  if (!nzchar(db_pass)) {
    stop("OMOP_DB_PASS is required")
  }

  jdbc_dir <- Sys.getenv("OMOP_JDBC_PATH", "/jdbc")
  if (!dir.exists(jdbc_dir) || !length(list.files(jdbc_dir, pattern = "\\.jar$"))) {
    jdbc_dir <- file.path(tempdir(), "jdbc")
    dir.create(jdbc_dir, recursive = TRUE, showWarnings = FALSE)
    DatabaseConnector::downloadJdbcDrivers("postgresql", pathToDriver = jdbc_dir)
  }

  connection_details <- DatabaseConnector::createConnectionDetails(
    dbms = "postgresql",
    server = paste0(db_host, "/", db_name),
    user = db_user,
    password = db_pass,
    port = db_port,
    pathToDriver = jdbc_dir
  )
  connection <- DatabaseConnector::connect(connection_details)
  on.exit(DatabaseConnector::disconnect(connection), add = TRUE)

  result <- DatabaseConnector::querySql(
    connection,
    sprintf("SELECT COUNT(*) AS patient_count FROM %s.person", cdm_schema)
  )
  if (nrow(result) != 1L || ncol(result) != 1L) {
    stop("Patient count query returned an unexpected result shape")
  }

  patient_count <- as.numeric(result[[1]][[1]])
  if (length(patient_count) != 1L || is.na(patient_count) || patient_count < 0) {
    stop("Patient count query returned an invalid count")
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(output_dir, "patient_count.csv")
  utils::write.csv(
    data.frame(patient_count = patient_count),
    output_file,
    row.names = FALSE
  )
  message("Wrote aggregate patient count to ", output_file)
}

run_patient_count()
