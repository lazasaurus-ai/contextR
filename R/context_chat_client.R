#' context_chat_client
#'
#' Create a persistent chat client that automatically maintains
#' conversational memory with contextR and talks to Bedrock via **ellmer**.
#'
#' @param model Bedrock model ID (default = Claude Sonnet 3.5).
#' @param k     Maximum messages to retain in memory.
#' @param system_prompt System prompt for the LLM (used once when client is created).
#' @param ...   Additional args passed to `ellmer::chat_aws_bedrock()` (profile, api_args…).
#' @return A **list** with methods:  \cr
#'   * `$chat(user_msg, followup = NULL)` – send a turn, get reply (character)  \cr
#'   * `$memory()` – return the underlying `MemoryBuffer`  \cr
#'   * `$clear()`  – clear the buffer  \cr
#'   * `$get_turns()` – convenience `get_memory()` shortcut
#'
#' @examples
#' \dontrun{
#'   cli <- context_chat_client(k = 6)
#'   cli$chat("Tell me about frogs in the USA.", followup = "Answer in 2 sentences.")
#'   cli$chat("What about Mexico?")
#'   cli$get_turns()
#' }
#' @export
context_chat_client <- function(model = "anthropic.claude-3-5-sonnet-20240620-v1:0",
                                k = 10,
                                system_prompt = "Answer concisely and use prior context.",
                                ...) {
  
  # 1) create persistent ellmer chat client
  chat <- ellmer::chat_aws_bedrock(
    model         = model,
    system_prompt = system_prompt,
    ...
  )
  
  # 2) memory buffer for this client only
  buf <- memory_buffer(k = k)
  
  # 3) helper that sends a turn and updates memory
  send_turn <- function(user_msg, followup = NULL) {
    add_message(buf, "user", user_msg)
    ask   <- if (is.null(followup)) user_msg else followup
    prompt <- memory_prompt(buf, ask, "ellmer")
    reply  <- chat$chat(prompt)
    add_message(buf, "assistant", reply)
    reply
  }
  
  # 4) return list of closures (simple client object)
  list(
    chat       = send_turn,
    clear      = function() clear_memory(buf),
    memory     = function() buf,
    get_turns  = function() get_memory(buf)
  )
}
