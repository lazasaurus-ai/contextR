#' Coerce common SDK response objects to a single character string
#'
#' Works with characters, lists, and ellmer Chat objects (environments/R6).
#' For ellmer Chat, it uses get_turns()/last_turn() to extract the last assistant text.
#'
#' @param x Any object
#' @return length-1 character string
#' @export
as_text <- function(x) {
  # Character → single string
  if (is.character(x)) return(paste(x, collapse = " "))
  
  # List-like → probe common shapes
  if (is.list(x)) {
    for (nm in c("content","text","message","output","answer","body","response","value")) {
      if (!is.null(x[[nm]])) return(as_text(x[[nm]]))
    }
    if (!is.null(x$choices) && length(x$choices) >= 1) {
      ch <- x$choices[[1]]
      if (!is.null(ch$message$content)) return(as_text(ch$message$content))
      if (!is.null(ch$text)) return(as_text(ch$text))
    }
    if (!is.null(x$messages) && length(x$messages) >= 1) {
      last <- x$messages[[length(x$messages)]]
      if (!is.null(last$content)) return(as_text(last$content))
    }
    return(paste(capture.output(utils::str(x)), collapse = "\n"))
  }
  
  # Environment / R6 (ellmer Chat)
  if (is.environment(x)) {
    # Prefer: get_turns(include_system_prompt = FALSE)
    if (exists("get_turns", envir = x, inherits = FALSE)) {
      f <- get("get_turns", envir = x, inherits = FALSE)
      if (is.function(f)) {
        turns <- try(f(include_system_prompt = FALSE), silent = TRUE)
        if (!inherits(turns, "try-error") && length(turns)) {
          # turns can be a list or data.frame/tibble with columns $role, $content
          # 1) try to find the last assistant turn
          idx <- NA_integer_
          if (is.list(turns) && !is.data.frame(turns)) {
            roles <- vapply(turns, function(t) t$role %||% NA_character_, character(1))
            idx <- tail(which(roles == "assistant"), 1)
            turn <- if (is.finite(idx)) turns[[idx]] else turns[[length(turns)]]
            return(.extract_turn_content(turn))
          } else {
            # data.frame/tibble
            if (!is.null(turns$role)) {
              idxs <- which(turns$role == "assistant")
              idx <- if (length(idxs)) tail(idxs, 1) else nrow(turns)
              turn <- lapply(names(turns), function(nm) turns[[nm]][idx])
              names(turn) <- names(turns)
              return(.extract_turn_content(turn))
            }
          }
        }
      }
    }
    # Fallback: last_turn(role = "assistant")
    if (exists("last_turn", envir = x, inherits = FALSE)) {
      f <- get("last_turn", envir = x, inherits = FALSE)
      if (is.function(f)) {
        lt <- try(f(role = "assistant"), silent = TRUE)
        if (!inherits(lt, "try-error") && !is.null(lt$content)) return(as_text(lt$content))
        lt <- try(f(), silent = TRUE)
        if (!inherits(lt, "try-error") && !is.null(lt$content)) return(as_text(lt$content))
      }
    }
    # Final fallback: view env as list
    return(as_text(as.list.environment(x, all.names = TRUE)))
  }
  
  # S3/S4 try as.character
  out <- try(as.character(x), silent = TRUE)
  if (!inherits(out, "try-error") && length(out)) return(paste(out, collapse = " "))
  paste(capture.output(utils::str(x)), collapse = "\n")
}

# internal: robustly extract text from a turn
.extract_turn_content <- function(turn) {
  # turn may have $content (char or list), or nested pieces
  if (is.null(turn)) return("")
  content <- turn$content %||% turn$text %||% turn$message
  if (is.null(content)) return("")
  if (is.character(content)) return(paste(content, collapse = " "))
  if (is.list(content)) {
    pieces <- unlist(lapply(content, function(e) {
      if (is.character(e)) return(e)
      if (is.list(e)) {
        if (!is.null(e$text)) return(as_text(e$text))
        if (!is.null(e$content)) return(as_text(e$content))
      }
      return(character(0))
    }), use.names = FALSE)
    if (length(pieces)) return(paste(pieces, collapse = " "))
  }
  as_text(content)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b
