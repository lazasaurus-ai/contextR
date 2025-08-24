#' Reactive conversational memory buffer for **Shiny**
#'
#' This helper wraps [memory_buffer()] in a reactive container so that
#' any Shiny expression depending on the buffer is automatically
#' updated after you add or clear messages.
#'
#' The returned object is **a list with four members**:
#' \describe{
#'   \item{`buffer()`}{a *reactive* expression returning the live `MemoryBuffer`}
#'   \item{`add(role, content, …)`}{add any message (reactive‐aware wrapper for [add_message()])}
#'   \item{`add_user(content, …)`}{shortcut for adding a `"user"` message}
#'   \item{`add_assistant(content, …)`}{shortcut for adding an `"assistant"` message}
#'   \item{`clear()`}{clear the buffer and trigger reactivity}
#' }
#'
#' @param k,system_prompt,metadata,autosave,save_dir,save_file
#'   Same arguments as [memory_buffer()].
#'
#' @return A list with reactive helpers (see Details).
#'
#' @section Usage inside *server*:  
#' ```r
#' rbuf <- reactive_memory_buffer(k = 6)
#'
#' observeEvent(input$send, {
#'   rbuf$add_user(input$msg)
#'   reply <- my_model(memory_prompt(rbuf$buffer(), input$msg, "ellmer"))
#'   rbuf$add_assistant(reply)
#' })
#'
#' output$history <- renderPrint({
#'   get_memory(rbuf$buffer())   # re-runs automatically
#' })
#' ```
#'
#' @export
reactive_memory_buffer <- function(k = 10,
                                   system_prompt = NULL,
                                   metadata = list(),
                                   autosave = FALSE,
                                   save_dir = getwd(),
                                   save_file = "context_memory.rds") {
  
  # underlying mutable buffer
  buf <- memory_buffer(
    k             = k,
    system_prompt = system_prompt,
    metadata      = metadata,
    autosave      = autosave,
    save_dir      = save_dir,
    save_file     = save_file
  )
  
  # simple version counter; increment to invalidate dependents
  ver <- shiny::reactiveVal(0L)
  
  list(
    # ---- reactive accessor ---------------------------------------------------
    buffer = shiny::reactive({ ver(); buf }),
    
    # ---- mutators ------------------------------------------------------------
    add = function(role, content, ...) {
      add_message(buf, role, content, ...)
      ver(ver() + 1L); invisible(NULL)
    },
    add_user = function(content, ...) {
      add_message(buf, "user", content, ...)
      ver(ver() + 1L); invisible(NULL)
    },
    add_assistant = function(content, ...) {
      add_message(buf, "assistant", content, ...)
      ver(ver() + 1L); invisible(NULL)
    },
    
    # ---- clear ---------------------------------------------------------------
    clear = function() {
      clear_memory(buf)
      ver(ver() + 1L); invisible(NULL)
    }
  )
}