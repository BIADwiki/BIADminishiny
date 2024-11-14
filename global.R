library(shiny)
library(leaflet)
library(ggmap)
library(geosphere) 
library(shinyTree)
library(data.tree)
source("functions.R")
source("functions.database.connect.R")
library(shinybusy)

add_busy_bar(color = "#FF0000",timeout=1000)

# Register your Google Maps API key
allsites=readRDS("../data/sites_table.RDS")

# Register your Google Maps API key
register_google(key = Sys.getenv("GMAP_API"))#attention ac ma clef

conn <- init.conn()

coords <- cbind(allsites$Longitude, allsites$Latitude)

# Function to get the list of tables from the database
get_table_list <- function(conn) {
    alltables <- DBI::dbListTables(conn)
    alltables[!grepl("z.*_.*",alltables)]
}

# Retrieve field names for a specified table
get_field_list <- function(conn, table) {
    DBI::dbListFields(conn, table)
}

tables <- get_table_list(conn)
