library(shiny)
library(leaflet)
library(shinyTree)
library(bslib)
library(shinycssloaders)

ui <- page_sidebar(
    theme = bs_theme(bootswatch = "pulse"),
    title = div( tags$a(href="http://biadwiki.org:3838/BIADminishiny/",tags$img(src = "favicon.ico", height = "60px")),
                "A minimal Shiny app for BIAD",
                ) ,
    sidebar=sidebar( 
      bg = "#1976D2",
      width = "20%",
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
             shinycssloaders::withSpinner(uiOutput("key_buttons"),proxy.height="80px"), # Output for clickable primary key buttons
             shinyTree("siteTree")
        ),
    ),      
   
    card(
         card_header("Spatial Distribution"),
         card_body(leafletOutput("map")),
         card_footer(DT::DTOutput("selTxt"))
    )
 # fluidRow(
 #          card(
 #      column(width=12,
 #             br(),
 #             DT::DTOutput("selTxt")
 #      )
 #  )
 # )
)

