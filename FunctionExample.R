library(shiny)

ui <- fluidPage(
  titlePanel("Function Example"),
  

  h4("Give an example of a function."),
  
 
  textInput(inputId = "user_answer", 
            label = "Your answer:", 
            placeholder = "e.g., f(x) = x^2"),
  
  h4("You typed:"),
  textOutput("echoed_text")
)

server <- function(input, output, session) {
  
  output$echoed_text <- renderText({
    input$user_answer
  })
  
}

shinyApp(ui = ui, server = server)