#' context_chat_client  with auto-shrink + optional model 
#'
#' Create a persistent chat client that maintains conversational memory
#' (with optional rolling summaries) and talks to Bedrock via **ellmer**.
#'
#' @param model Bedrock model ID.  If `NULL`, the client will look for
#'              `getOption("contextR.chat_model")`; if that too is `NULL`,
#'              it lets `ellmer::chat_aws_bedrock()` choose its default.
#' @param k     Maximum total rows kept in the buffer (raw + summaries).
#' @param system_prompt System prompt shown to the LLM at client creation.
#' @param summary_n     Summarise every *n* raw turns (user + assistant).
#'                      Use `NULL` to disable summaries.
#' @param summary_system System prompt for the summariser.
#' @param ...   Extra args passed to `ellmer::chat_aws_bedrock()`.
#' @export
context_chat_client <- function(
    model           = getOption("contextR.chat_model", NULL),
    k               = 10,
    system_prompt   = "Answer concisely and use prior context.",
    summary_n       = NULL,
    summary_system  = getOption(
      "contextR.summary_system",
      "You are a concise scribe. Summarize faithfully in <=120 words; include decisions, actions, open questions."
    ),
    ...
) {
  
  ## ── 1. sanity-check summary_n vs k ───────────────────────────────────
  if (!is.null(summary_n) && summary_n > k - 1) {
    warning("`summary_n` (", summary_n, ") is larger than k - 1 (", k - 1,
            ").  Reducing summary_n to ", k - 1, ".")
    summary_n <- k - 1
  }
  
  ## ── 2. create Bedrock client via ellmer ──────────────────────────────
  ellmer_args <- list(system_prompt = system_prompt, ...)
  if (!is.null(model)) ellmer_args$model <- model
  chat <- do.call(ellmer::chat_aws_bedrock, ellmer_args)
  
  ## ── 3. create memory buffer ──────────────────────────────────────────
  buf <- memory_buffer(k = k, system_prompt = system_prompt)
  
  ## ── 4. helper: send one chat turn & update memory ────────────────────
  send_turn <- function(user_msg, followup = NULL) {
    
    # (a) record USER turn
    if (is.null(summary_n)) {
      add_message(buf, "user", user_msg)
    } else {
      memory_add_and_summarize(
        buf, "user", user_msg,
        client        = chat,
        n             = summary_n,
        system_prompt = summary_system
      )
    }
    
    # (b) build prompt & call LLM
    ask    <- if (is.null(followup)) user_msg else followup
    prompt <- memory_prompt(buf, ask, format = "ellmer")
    reply  <- chat$chat(prompt)
    
    # (c) record ASSISTANT turn
    if (is.null(summary_n)) {
      add_message(buf, "assistant", reply)
    } else {
      memory_add_and_summarize(
        buf, "assistant", reply,
        client        = chat,
        n             = summary_n,
        system_prompt = summary_system
      )
    }
    
    reply
  }
  
  ## ── 5. expose public methods ─────────────────────────────────────────
  list(
    chat       = send_turn,
    clear      = function() clear_memory(buf),
    memory     = function() buf,
    get_turns  = function() get_memory(buf)
  )
}
