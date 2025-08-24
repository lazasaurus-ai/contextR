
# contextR

Light-weight **conversational memory** for R, inspired by LangChain but 100 % native.  
Easily store, trim, persist, and format chat history for any LLM workflow.  
Out‑of‑the‑box helpers for **AWS Bedrock** via the [`ellmer`](https://github.com/mikmart/ellmer) package.

---

## Installation

```r
# devtools is optional but convenient
install.packages("devtools")
devtools::install_github("lazaroalva97/contextR")
```

### Dependencies
| Type    | Package | Purpose                                   |
|---------|---------|-------------------------------------------|
| Imports | `tibble`, `glue` | tidy tables & string glue        |
| Suggests| `ellmer`         | Bedrock chat helper (optional)   |
| Suggests| `shiny`          | only for demo Shiny app          |

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

## Shiny demo

Launch the minimal app that lives in **demo/shiny_example.R**:

```r
shiny::runApp(
  system.file("demo", "shiny_example.R", package = "contextR")
)
```

Tabs:

* **Chat Log** – coloured user & assistant turns  
* **Raw tibble** – live view of the `MemoryBuffer`

---

## CRAN notes

* Network code is guarded with `requireNamespace("ellmer", quietly = TRUE)`.  
* Examples that hit Bedrock are wrapped in `\dontrun{}`.  
* Demo scripts reside in `demo/` and are ignored by `.Rbuildignore`.

---

## License

MIT © 2025 Lazaro Alvarez
