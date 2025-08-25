#' Add a turn and (conditionally) append a rolling summary
#'
#' Works with `MemoryBuffer` created by [memory_buffer()]. After appending the
#' new turn via [add_message()], this will summarize the next window of `n`
#' raw turns (user/assistant) *after* the last summary and append that summary
#' as a `system` message with `name = "summary"`. Covered ranges are recorded
#' in the message `meta` to avoid duplicates.
#'
#' @param buffer A `MemoryBuffer` as returned by [memory_buffer()].
#' @param role One of `"user"` or `"assistant"`.
#' @param content Message text (non-character objects are coerced with [as_text()]).
#' @param client An LLM chat client function; must accept a list of messages
#'   (each with `role` and `content`) and return a list with `content` or a
#'   character string. If `NULL`, no summarization is attempted.
#' @param n Integer; number of raw turns per summary window. Default:
#'   `getOption("contextR.summary_window", 5)`.
#' @param system_prompt Optional system prompt used for summarization. Default:
#'   `getOption("contextR.summary_system", "You are a concise scribe. Summarize faithfully in <=120 words; include decisions, actions, open questions.")`
#'
#' @return The same `buffer`, mutated by reference and returned (invisibly).
#' @export
memory_add_and_summarize <- function(buffer,
                                     role,
                                     content,
                                     client = NULL,
                                     n = getOption("contextR.summary_window", 5),
                                     system_prompt = getOption(
                                       "contextR.summary_system",
                                       "You are a concise scribe. Summarize faithfully in <=120 words; include decisions, actions, open questions."
                                     )) {
  .assert_buffer(buffer)
  role <- match.arg(role, c("user","assistant"))
  
  # 1) Append the new raw message
  add_message(buffer, role = role, content = content)
  
  # 2) Try to summarize if we have a client
  if (is.null(client)) return(invisible(buffer))
  if (!is.function(client) && !inherits(client, "environment")) {
    # allow ellmer client object; we'll call through helper below
  }
  
  .maybe_summarize_latest_window(buffer, n = n, client = client, system_prompt = system_prompt)
  invisible(buffer)
}

# --- internal helpers ----------------------------------------------------------

# Summarize the next window of n raw turns after the last covered index.
.maybe_summarize_latest_window <- function(buffer, n, client, system_prompt) {
  msgs <- buffer$messages
  if (!nrow(msgs)) return(invisible(buffer))
  
  last_cov <- .last_covered_index(msgs)  # 0 if none
  raw_idx  <- which(msgs$role %in% c("user","assistant") & seq_len(nrow(msgs)) > last_cov)
  
  if (length(raw_idx) < n) return(invisible(buffer))  # not enough new turns
  
  take_idx <- raw_idx[seq_len(n)]
  window   <- msgs[take_idx, , drop = FALSE]
  
  # Build chat messages for the client
  chat_msgs <- list(
    list(role = "system",  content = system_prompt),
    list(role = "user",    content = "Summarize this window of dialogue:")
  )
  chat_msgs <- c(chat_msgs,
                 lapply(seq_len(nrow(window)), function(i) {
                   list(role = window$role[i], content = window$content[i])
                 }))
  
  # Call client; support either ellmer::chat(client, messages=…) or a simple function
  summary_text <- tryCatch({
    if (exists("ellmer::chat")) {
      # if client is an ellmer chat client env/object:
      ans <- ellmer::chat(client, messages = chat_msgs)
      if (!is.null(ans$content)) ans$content else as.character(ans)
    } else if (is.function(client)) {
      as.character(client(chat_msgs))
    } else {
      stop("Unsupported client type for summarization.")
    }
  }, error = function(e) {
    # Fallback: cheap local summary
    paste("SUMMARY (fallback):", paste(window$content, collapse = " | "))
  })
  
  # Append the summary as a system message with metadata recording coverage
  add_message(
    buffer,
    role     = "system",
    content  = summary_text,
    name     = "summary",
    meta     = list(
      summary = TRUE,
      covered_from  = min(take_idx),
      covered_through = max(take_idx),
      n_turns = n
    )
  )
}

# Return the highest covered_through index from prior summaries; 0 if none.
.last_covered_index <- function(msgs) {
  if (!nrow(msgs)) return(0L)
  # summaries are system messages with name="summary" and meta$summary==TRUE
  is_sum <- msgs$role == "system" &
    !is.na(msgs$name) & msgs$name == "summary" &
    vapply(msgs$meta, function(m) isTRUE(m$summary %||% FALSE), logical(1))
  if (!any(is_sum)) return(0L)
  
  cov_through <- vapply(msgs$meta[is_sum], function(m) m$covered_through %||% NA_integer_, integer(1))
  ct <- cov_through[!is.na(cov_through)]
  if (!length(ct)) 0L else max(ct)
}
