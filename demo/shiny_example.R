# app.R ----------------------------------------------------------------------
# contextR chat client + Shiny (blocking call, two tabs)

library(shiny)
library(contextR)     # provides context_chat_client()

ui <- fluidPage(
  titlePanel("contextR Bedrock Chat (with built-in client)"),
  
  sidebarLayout(
    sidebarPanel(
      textInput("msg", "Your message"),
      actionButton("send", "Send"),
      width = 3
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Chat Log",
          tags$div(
            style = "max-height: 400px; overflow-y:auto; border:1px solid #ccc; padding:1em",
            uiOutput("chat_ui")
          )
        ),
        tabPanel(
          "Raw tibble",
          verbatimTextOutput("history")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  ## ---- create persistent chat client (Bedrock + internal buffer) ----------
  cli <- context_chat_client(k = 10)   # uses default model & system prompt
  
  ## version counter to trigger reactivity
  ver <- reactiveVal(0L)
  
  ## ---- Send button ----
  observeEvent(input$send, {
    req(trimws(input$msg) != "")
    
    # one-liner: adds user, calls model, stores assistant
    cli$chat(input$msg)
    
    ver(ver() + 1L)                    # bump version so outputs refresh
    updateTextInput(session, "msg", value = "")
  })
  
  ## ---- pretty chat log ----
  output$chat_ui <- renderUI({
    ver()                              # depend on version
    mem <- cli$get_turns()
    if (!nrow(mem)) return()
    tags$ul(
      lapply(seq_len(nrow(mem)), function(i) {
        row   <- mem[i, ]
        style <- if (row$role == "user") "color:#007bff" else "color:#28a745"
        tags$li(tags$span(style = style, paste0("[", row$role, "] ")), row$content)
      })
    )
  })
  
  ## ---- raw tibble ----
  output$history <- renderPrint({
    ver()                              # depend on version
    cli$get_turns()
  })
}

shinyApp(ui, server)
