library(contextR)

# ── 1. Create client with rolling summaries every 4 raw turns ──────────
cli <- context_chat_client(k = 6, summary_n = 4)

# ── 2. Four turns → Summary 1 is auto-appended ─────────────────────────
cli$chat("Tell me about frogs or toads in the USA.",
         followup = "Answer in 2–3 sentences.")
cli$chat("What about Mexico? Focus on differences vs USA.")
cli$chat("List three endangered amphibian species in Mexico.")
cli$chat("Briefly explain why amphibians are declining worldwide.")  # ← Summary 1 created

# Inspect buffer: note the single system row named "summary"
cli$get_turns()
#> # A tibble: 6 × 5
#>   role      content                          timestamp            name   meta
#> 1 assistant “… USA answer …”                2025-08-24 …         NA     …
#> 2 system    "SUMMARY: Tell me about …"      2025-08-24 …         summary <…>
#> 3 user      "List three endangered …"       2025-08-24 …         NA     …
#> 4 assistant "Three endangered amphibian …"  2025-08-24 …         NA     …
#> 5 user      "Briefly explain why …"         2025-08-24 …         NA     …
#> 6 assistant "Amphibians are declining …"    2025-08-24 …         NA     …

# ── 3. Show exactly what will be sent to the LLM next ──────────────────
prompt_preview <- memory_prompt(
  cli$memory(),                                        # buffer with summary row
  "Given our discussion, name one frog species unique to Mexico and explain why it is endemic.",
  format = "ellmer"
)
cat(prompt_preview)

# ── 4. Buffer Memory Drops since n > 6 ──────────────────
cli$chat("What can we do to help conserve the populations?") 
cli$get_turns()
cli$chat("Do you know of any organizations who are focused on this as their mission?") 
cli$get_turns()
cli$chat("Are these USA based?") 
cli$get_turns()
cli$chat("What about in Texas?") 
cli$get_turns()  # You should see a new summary here 
cli$chat("What about in Florida?") 
cli$get_turns()  # You should see a new summary here 


# EXAMPLE OF SIMULATED CUSHION 

cli <- context_chat_client(k = 6, summary_n = 4)

for (q in 1:20) {
  cli$chat(paste("Turn", q))
}

table(cli$get_turns()$role)
#> system      1   ← always at least one summary
#> user        2
#> assistant   3


cli <- context_chat_client(k = 12, summary_n = 4)

for (q in 1:20) {
  cli$chat(paste("Turn", q))
}

table(cli$get_turns()$role)
