library(shiny)
library(leaflet)
library(shinyTree)
library(bslib)

#shinyUI(fluidPage(
#  titlePanel("Let's dig BIAD a bit..."),
ui <- page_fluid(
  title="BIAD exploration",
  titlePanel("Let's dig BIAD a bit..."),
  layout_sidebar(
    sidebar=sidebar( 
      width = 650,
    navset_card_underline(id='tabpan',
        nav_panel(
           title="Fuzzy Search",
           selectInput("table", "In which table is the element you are looking for?", choices = get_table_list(conn)),
           uiOutput("fields_ui"),
           textInput("location", "Enter a string to match:", ""),
           actionButton("find_matches", "Find Matches"),
        ),
        nav_panel(
           title=  "Distance based Search",
           textInput("name", "Enter Name (optional):", ""),
           layout_column_wrap(
           numericInput("latitude", "Latitude:", value = NULL, step = 0.0001),
           numericInput("longitude", "Longitude:", value = NULL, step = 0.0001)
           ),
           actionButton("find_matches_dis", "Find Matches"),
           conditionalPanel(
                condition = "input.name != ''",
               sliderInput("distance", "Distance (D) in km:", min = 1, max = 100, value = 10, step = 1)
           )
        )
      ),
        card(
            uiOutput("key_buttons"), # Output for clickable primary key buttons
            shinyTree("siteTree")
        ),
    ),      
    
      leafletOutput("map")
  ),
  fluidRow(
       column(width=12,
              br(),
              DT::DTOutput("selTxt")
       )
  )
)

