###############################################################################
# Session 1  ───────────────────────────────────────────────────────────────────
#  ▸ Ask two questions
#  ▸ Buffer autosaves to  demo/frog_convo.rds
###############################################################################

library(contextR)

save_dir  <- "~/R/contextR/demo"   # adjust if your project path differs
save_file <- "frog_convo.rds"

dir.create(save_dir, showWarnings = FALSE, recursive = TRUE)

buf <- load_or_new_memory(
  k             = 6,
  system_prompt = "Answer concisely and use prior context.",
  save_dir      = save_dir,
  save_file     = save_file
)

if (requireNamespace("ellmer", quietly = TRUE)) {
  chat_with_memory_one_shot(
    buffer   = buf,
    user_msg = "Tell me about frogs in the USA.",
    followup = "Answer in 2 sentences."
  )
  
  chat_with_memory_one_shot(
    buffer   = buf,
    user_msg = "What about Mexico?",
    followup = "Focus on key differences vs USA."
  )
} else {
  message("ellmer not installed — skipping Bedrock calls.")
}

print(get_memory(buf))
cat("Saved to:", get_save_path(buf), "\n")

# ── End of Session 1 ──
###############################################################################
# Restart R (or just run the block below in a fresh session)
###############################################################################


###############################################################################
# Session 2  ───────────────────────────────────────────────────────────────────
#  ▸ Reload the same buffer
#  ▸ Ask a follow-up question
###############################################################################

library(contextR)

save_dir  <- "~/R/contextR/demo"      # same path as above
save_file <- "frog_convo.rds"

buf <- load_or_new_memory(
  save_dir  = save_dir,
  save_file = save_file
)   # history auto-restored

if (requireNamespace("ellmer", quietly = TRUE)) {
  chat_with_memory_one_shot(
    buffer   = buf,
    user_msg = "Are any frog species endangered in either country?"
  )
}

print(get_memory(buf))
