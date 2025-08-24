# R/persistence.R ------------------------------------------------------------
#' Enable autosave for an existing MemoryBuffer
#'
#' After every change the buffer is written to disk (RDS).  The function also
#' forces an *immediate* save so the file exists right away.
#'
#' @param buffer MemoryBuffer
#' @param save_dir Directory where the RDS file should live (default = getwd()).
#' @param save_file File name (default = "context_memory.rds").
#' @return the buffer (invisible)
#' @export
enable_autosave <- function(buffer,
                            save_dir  = getwd(),
                            save_file = "context_memory.rds") {
  .assert_buffer(buffer)
  
  buffer$autosave  <- TRUE
  buffer$save_dir  <- normalizePath(save_dir, winslash = "/", mustWork = FALSE)
  buffer$save_file <- as.character(save_file)
  
  # snapshot right away
  dir.create(buffer$save_dir, recursive = TRUE, showWarnings = FALSE)
  save_memory(buffer, file.path(buffer$save_dir, buffer$save_file))
  invisible(buffer)
}

#' Disable autosave for a MemoryBuffer
#' @param buffer MemoryBuffer
#' @export
disable_autosave <- function(buffer) {
  .assert_buffer(buffer)
  buffer$autosave <- FALSE
  invisible(buffer)
}

#' Load an existing buffer from disk **or** create a fresh one
#'
#' Useful for scripts, RMarkdown, or Shiny apps: you always get a buffer,
#' and history is restored automatically if the RDS file exists.
#'
#' @param k Maximum messages to keep (ignored when file exists).
#' @param system_prompt Optional system prompt (ignored when file exists).
#' @param save_dir Directory to look for / write the RDS (default = getwd()).
#' @param save_file File name (default = "context_memory.rds").
#' @return A MemoryBuffer
#' @export
load_or_new_memory <- function(k = 10,
                               system_prompt = NULL,
                               save_dir      = getwd(),
                               save_file     = "context_memory.rds") {
  
  path <- file.path(normalizePath(save_dir, winslash = "/", mustWork = FALSE),
                    save_file)
  
  if (file.exists(path)) {
    buf <- load_memory(path)
  } else {
    buf <- memory_buffer(k             = k,
                         system_prompt = system_prompt,
                         autosave      = TRUE,
                         save_dir      = save_dir,
                         save_file     = save_file)
  }
  buf
}
