library(shiny)
library(leaflet)
library(shinyTree)

shinyUI(fluidPage(
  titlePanel("Let's dig BIAD a bit..."),
  
  sidebarLayout(
    sidebarPanel(
      tabsetPanel(
        tabPanel(
           "Fuzzy Search",
            selectInput("table", "In which table is the element you are looking for?", choices = get_table_list(conn)),
            uiOutput("fields_ui"),
            textInput("location", "Enter a string to match:", ""),
            actionButton("find_matches", "Find Matches"),
            ),
        tabPanel(
           "Distance based Search",
           textInput("name", "Enter Name (optional):", ""),
           numericInput("latitude", "Latitude:", value = NULL, step = 0.0001),
           numericInput("longitude", "Longitude:", value = NULL, step = 0.0001),
           actionButton("find_matches_dis", "Find Matches"),
           hr(),
           sliderInput("distance", "Distance (D) in km:", min = 1, max = 100, value = 10, step = 1)
        )
      ),
        hr(),
        uiOutput("key_buttons"), # Output for clickable primary key buttons
        textOutput("downtree"),
        shinyTree("siteTree")
    ),      
    
    mainPanel(
      leafletOutput("map")
    )
  ),
  fluidRow(
		   column(width=12,
				  br(),
				  DT::DTOutput("selTxt")
		   )
  )
))


