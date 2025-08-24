#' Create a conversational memory buffer
#'
#' A lightweight, mutable memory buffer that stores the last \code{k} messages.
#' Messages are kept as a tibble with columns: role, content, timestamp, name, meta.
#'
#' @param k Integer, maximum messages to keep (default 10).
#' @param system_prompt Optional string included first in formatted context.
#' @param metadata Optional list of metadata about this buffer.
#' @param autosave Logical; if TRUE write .rds after each change. Default FALSE.
#' @param save_dir Directory for .rds when autosave=TRUE. Default getwd().
#' @param save_file File name for .rds when autosave=TRUE. Default "context_memory.rds".
#' @return An object of class "MemoryBuffer" (an environment with fields).
#' @export
memory_buffer <- function(k = 10,
                          system_prompt = NULL,
                          metadata = list(),
                          autosave = FALSE,
                          save_dir = getwd(),
                          save_file = "context_memory.rds") {
  stopifnot(is.numeric(k), length(k) == 1, k >= 0)
  buf <- new.env(parent = emptyenv())
  buf$k <- as.integer(k)
  buf$system_prompt <- system_prompt
  buf$metadata <- metadata
  buf$autosave <- isTRUE(autosave)
  buf$save_dir <- normalizePath(save_dir, winslash = "/", mustWork = FALSE)
  buf$save_file <- as.character(save_file)
  buf$messages <- tibble::tibble(
    role = character(),
    content = character(),
    timestamp = as.POSIXct(character()),
    name = character(),
    meta = I(list())
  )
  class(buf) <- "MemoryBuffer"
  .persist_if_enabled(buf)
  buf
}

#' Add a message to the buffer
#'
#' @param buffer A MemoryBuffer.
#' @param role One of "user","assistant","system","tool".
#' @param content Message text OR an SDK response object (coerced via \code{as_text()}).
#' @param name Optional speaker name/label.
#' @param timestamp POSIXct; defaults to now.
#' @param meta Optional list of extra fields for this message.
#' @return The same buffer (invisible), mutated by reference.
#' @export
add_message <- function(buffer, role, content, name = NULL,
                        timestamp = Sys.time(), meta = list()) {
  .assert_buffer(buffer)
  role <- match.arg(role, c("user","assistant","system","tool"))
  
  # Coerce non-character content (e.g., SDK list outputs) to a single string
  if (!is.character(content) || length(content) != 1) {
    content <- as_text(content)
  }
  stopifnot(is.character(content), length(content) == 1)
  
  new_row <- tibble::tibble(
    role = role,
    content = content,
    timestamp = as.POSIXct(timestamp),
    name = if (is.null(name)) NA_character_ else as.character(name),
    meta = list(meta)
  )
  buffer$messages <- rbind(buffer$messages, new_row)
  
  if (buffer$k >= 0 && nrow(buffer$messages) > buffer$k) {
    buffer$messages <- utils::tail(buffer$messages, buffer$k)
  }
  
  .persist_if_enabled(buffer)
  invisible(buffer)
}

#' Add an assistant response (coerces SDK output to text)
#'
#' Convenience wrapper around \code{add_message(..., role = "assistant", ...)}
#' that accepts raw SDK responses (e.g., from ellmer) and converts them to text.
#'
#' @param buffer MemoryBuffer
#' @param response Object returned by an SDK (e.g., ellmer::chat_aws_bedrock()).
#' @export
add_assistant_response <- function(buffer, response) {
  add_message(buffer, "assistant", response)
}

#' Get messages as a tibble
#' @param buffer A MemoryBuffer.
#' @return tibble with columns: role, content, timestamp, name, meta.
#' @export
get_memory <- function(buffer) {
  .assert_buffer(buffer)
  buffer$messages
}

#' Clear all messages
#' @param buffer A MemoryBuffer.
#' @return The same buffer (invisible), emptied.
#' @export
clear_memory <- function(buffer) {
  .assert_buffer(buffer)
  buffer$messages <- buffer$messages[0, ]
  .persist_if_enabled(buffer)
  invisible(buffer)
}

#' Set the maximum size k
#' @param buffer A MemoryBuffer.
#' @param k Integer >= 0.
#' @export
set_k <- function(buffer, k) {
  .assert_buffer(buffer)
  stopifnot(is.numeric(k), length(k) == 1, k >= 0)
  buffer$k <- as.integer(k)
  if (nrow(buffer$messages) > buffer$k) {
    buffer$messages <- utils::tail(buffer$messages, buffer$k)
  }
  .persist_if_enabled(buffer)
  invisible(buffer)
}

#' Format the buffer into a prompt string
#'
#' Produces a compact prompt string suitable for feeding into an LLM.
#' \itemize{
#' \item \code{format = "plain"} yields "role: content" lines separated by blank lines.
#' \item \code{format = "ellmer"} wraps with simple headers friendly for LLM prompts.
#' }
#'
#' @param buffer A MemoryBuffer.
#' @param format One of "plain","ellmer".
#' @param include_system If TRUE and a system_prompt exists, add it first.
#' @return A single character string.
#' @export
get_formatted_context <- function(buffer,
                                  format = c("plain","ellmer"),
                                  include_system = TRUE) {
  .assert_buffer(buffer)
  format <- match.arg(format)
  
  parts <- character()
  
  if (include_system && !is.null(buffer$system_prompt) && nzchar(buffer$system_prompt)) {
    parts <- c(parts, glue::glue("### System\n{buffer$system_prompt}"))
  }
  
  if (nrow(buffer$messages) > 0) {
    if (format == "plain") {
      msg_lines <- apply(buffer$messages, 1, function(row) {
        role <- row[["role"]]
        content <- row[["content"]]
        sprintf("%s: %s", role, content)
      })
      parts <- c(parts, paste(msg_lines, collapse = "\n\n"))
    } else if (format == "ellmer") {
      header <- "### Conversation History"
      body <- paste(apply(buffer$messages, 1, function(row) {
        role <- row[["role"]]
        content <- row[["content"]]
        sprintf("- %s: %s", role, content)
      }), collapse = "\n")
      parts <- c(parts, header, body)
    }
  }
  
  paste(parts, collapse = "\n\n")
}

#' Compose a final prompt with current memory + a new user prompt
#'
#' @param buffer A MemoryBuffer.
#' @param user_prompt The new user prompt/question.
#' @param format One of "plain","ellmer".
#' @return Combined prompt string.
#' @export
memory_prompt <- function(buffer, user_prompt, format = c("plain","ellmer")) {
  .assert_buffer(buffer)
  stopifnot(is.character(user_prompt), length(user_prompt) == 1)
  format <- match.arg(format)
  
  ctx <- get_formatted_context(buffer, format = format, include_system = TRUE)
  if (nzchar(ctx)) paste0(ctx, "\n\n### New User Prompt\n", user_prompt) else user_prompt
}

#' Save and load memory buffers
#'
#' @param buffer A MemoryBuffer to save.
#' @param file Path to an .rds file.
#' @name memory_persistence
#' @export
save_memory <- function(buffer, file) {
  .assert_buffer(buffer)
  obj <- list(
    k = buffer$k,
    system_prompt = buffer$system_prompt,
    metadata = buffer$metadata,
    messages = buffer$messages,
    autosave = buffer$autosave,
    save_dir = buffer$save_dir,
    save_file = buffer$save_file
  )
  saveRDS(obj, file = file)
  invisible(file)
}

#' @rdname memory_persistence
#' @export
load_memory <- function(file) {
  obj <- readRDS(file)
  buf <- memory_buffer(
    k = obj$k,
    system_prompt = obj$system_prompt,
    metadata = obj$metadata,
    autosave = isTRUE(obj$autosave),
    save_dir = obj$save_dir %||% getwd(),
    save_file = obj$save_file %||% "context_memory.rds"
  )
  buf$messages <- obj$messages
  .persist_if_enabled(buf)
  buf
}

#' Enable/disable autosave and/or update path
#' @param buffer MemoryBuffer
#' @param enabled logical
#' @param save_dir optional new dir
#' @param save_file optional new file name
#' @export
set_autosave <- function(buffer, enabled = TRUE, save_dir = NULL, save_file = NULL) {
  .assert_buffer(buffer)
  buffer$autosave <- isTRUE(enabled)
  if (!is.null(save_dir)) buffer$save_dir <- normalizePath(save_dir, winslash = "/", mustWork = FALSE)
  if (!is.null(save_file)) buffer$save_file <- as.character(save_file)
  .persist_if_enabled(buffer)
  invisible(buffer)
}

#' Get the current autosave target path
#' @export
get_save_path <- function(buffer) {
  .assert_buffer(buffer)
  file.path(buffer$save_dir, buffer$save_file)
}

# ---- internal ---------------------------------------------------------------

#' @keywords internal
#' @noRd
.assert_buffer <- function(buffer) {
  if (!inherits(buffer, "MemoryBuffer")) {
    stop("`buffer` must be a MemoryBuffer created by memory_buffer().", call. = FALSE)
  }
}

#' @keywords internal
#' @noRd
`%||%` <- function(a, b) if (!is.null(a)) a else b

#' @keywords internal
#' @noRd
.persist_if_enabled <- function(buffer) {
  if (isTRUE(buffer$autosave)) {
    dir.create(buffer$save_dir, recursive = TRUE, showWarnings = FALSE)
    save_memory(buffer, file.path(buffer$save_dir, buffer$save_file))
  }
}

#' Get the last assistant message from the buffer as plain text
#' @export
last_assistant_text <- function(buffer) {
  .assert_buffer(buffer)
  m <- buffer$messages
  if (!nrow(m)) return("")
  idx <- tail(which(m$role == "assistant"), 1)
  if (!length(idx)) return("")
  m$content[idx]
}

#' Print the most recent model reply (pretty)
#' @export
print_last_reply <- function(buffer) {
  txt <- last_assistant_text(buffer)
  cat(txt, sep = "\n")
  invisible(txt)
}
