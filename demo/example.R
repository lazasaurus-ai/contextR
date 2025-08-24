library(contextR)

buf <- memory_buffer(
  k = 6,
  system_prompt = "Answer concisely and use prior context if relevant."
)

# Turn 1
chat_with_memory_one_shot(
  buffer   = buf,
  user_msg = "Tell me about frogs or toads in the USA?",
  followup = "Answer in 2–3 sentences."
)

# Turn 2 (follow-up automatically sees previous turn)
chat_with_memory_one_shot(
  buffer   = buf,
  user_msg = "What about Mexico?",
  followup = "Focus on differences vs USA."
)

get_memory(buf)        # shows user + assistant text neatly

#Turn 3
chat_with_memory_one_shot(
  buffer   = buf,
  user_msg = "List three endangered species in Mexico."
  # followup omitted → NULL
)


# Example with Client 

library(contextR)

cli <- context_chat_client(k = 6)      # creates Bedrock client + buffer

cli$chat("Tell me about frogs or toads in the USA.",
         followup = "Answer in 2–3 sentences.")
cli$chat("What about Mexico?")

cli$get_turns()   # tibble of all turns


