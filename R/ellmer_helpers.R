#' Send a single turn to Bedrock via **ellmer** with contextR memory
#'
#' This is a convenience wrapper for a **one-shot** call:
#' it creates a temporary `ellmer::chat_aws_bedrock()` client,
#' sends the prompt that includes your buffer context,
#' captures the assistant reply, and stores it back in the buffer.
#'
#' @param buffer   A `MemoryBuffer` created by [memory_buffer()].
#' @param user_msg Character. The new user message for this turn.
#' @param model    Character Bedrock model ID
#'                 (default Claude Sonnet 3.5; change as needed).
#' @param followup Character. Optional extra instruction appended after the
#'                 buffered context (e.g., "Answer in 2 sentences.").
#' @param ...      Additional arguments passed to `ellmer::chat_aws_bedrock()`
#'                 (e.g., `profile = "my-aws-profile"` or `api_args = list()`)
#' @return Character assistant reply.
#' @examples
#' \dontrun{
#'   buf <- memory_buffer()
#'   reply <- chat_with_memory_one_shot(buf,
#'            "Tell me about frogs in the USA?")
#' }
#' @export
chat_with_memory_one_shot <- function(buffer,
                                      user_msg,
                                      model = "anthropic.claude-3-5-sonnet-20240620-v1:0",
                                      followup = NULL,
                                      ...) {
  .assert_buffer(buffer)
  
  # 1. Add the new user turn to memory
  add_message(buffer, "user", user_msg)
  
  # 2. Build a prompt string that includes prior context + (optional) follow-up
  ask <- if (is.null(followup)) user_msg else followup
  prompt <- memory_prompt(buffer, ask, format = "ellmer")
  
  # 3. Create a transient chat client and call `$chat()`
  client <- ellmer::chat_aws_bedrock(
    model         = model,
    system_prompt = NULL,   # we already embedded everything in `prompt`
    ...
  )
  reply <- client$chat(prompt)
  
  # 4. Store assistant reply back into memory
  add_message(buffer, "assistant", reply)
  
  # 5. Return reply
  reply
}
