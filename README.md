
# contextR

Light‑weight **conversational memory** for R, inspired by LangChain but 100 % native.  
Easily store, trim, persist, and format chat history for any LLM workflow.  
Includes out‑of‑the‑box helpers for **AWS Bedrock** via the
[`ellmer`](https://github.com/mikmart/ellmer) package.

---

## Installation

```r
# devtools is optional but convenient
install.packages("devtools")
devtools::install_github("lazaroalva97/contextR")
```

### Dependencies
| Type      | Package  | Purpose                           |
|-----------|----------|-----------------------------------|
| Imports   | `tibble`, `glue` | tidy tables & string glue |
| Suggests  | `ellmer` | Bedrock chat helper (optional)   |
| Suggests  | `shiny`  | only for the demo Shiny app      |
| Suggests  | `promises`, `future` | async Shiny example  |

---

## Quick start (one‑shot helper)

```r
library(contextR)

buf <- memory_buffer(
  k = 6,
  system_prompt = "Answer concisely and use prior context."
)

if (requireNamespace("ellmer", quietly = TRUE)) {

  # Turn 1
  chat_with_memory_one_shot(
    buffer   = buf,
    user_msg = "Tell me about frogs or toads in the USA?",
    followup = "Answer in 2–3 sentences."
  )

  # Turn 2 – context automatically included
  chat_with_memory_one_shot(
    buffer   = buf,
    user_msg = "What about Mexico?",
    followup = "Focus on differences vs USA."
  )

  get_memory(buf)
}
```

---

## Persistent chat client

```r
library(contextR)

cli <- context_chat_client(k = 6)  # Bedrock client + internal buffer

cli$chat("Tell me about frogs or toads in the USA.",
         followup = "Answer in 2–3 sentences.")
cli$chat("What about Mexico?")

cli$get_turns()      # tibble of all turns
```

---

## Automatic persistence

```r
library(contextR)

buf <- load_or_new_memory(          # loads if file exists, else creates new
  k             = 6,
  system_prompt = "Answer concisely and use prior context.",
  save_dir      = "demo",
  save_file     = "frog_convo.rds"
)

if (requireNamespace("ellmer", quietly = TRUE)) {
  chat_with_memory_one_shot(buf, "Tell me about frogs in the USA.")
}

## later / next session ----

buf <- load_or_new_memory(
  save_dir  = "demo",
  save_file = "frog_convo.rds"
)
```

---

## Shiny demo

Launch:

```r
shiny::runApp(
  system.file("demo", "shiny_example.R", package = "contextR")
)
```

---

## CRAN notes

* All network calls are protected with `requireNamespace("ellmer", quietly = TRUE)`.
* Network examples are wrapped in `\dontrun{}`.
* Demo scripts are ignored by `.Rbuildignore`.

---

## License

MIT © 2025 Lazaro Alvarez
