library(shiny)
library(leaflet)
library(ggmap)
library(geosphere) 
library(shinyTree)
library(data.tree)
#devtools::install_github("simoncarrignon/BIADconnect",force=TRUE)
library(BIADconnect)


# Register your Google Maps API key
ggmap::register_google(key = Sys.getenv("GMAP_API"))#attention ac ma clef



# Function to get the list of tables from the database
get_table_list <- function(conn) {
    check.conn(conn)
    alltables <- tryCatch(DBI::dbListTables(conn),error=function(e){
            print("pb during connection")
            disco <- disconnect()
            conn <- init.conn(db.credentials=db.credential)
            assign("conn",conn,envir = .GlobalEnv)
    })
    alltables[!grepl("z.*_.*",alltables)]
}

# Retrieve field names for a specified table
get_field_list <- function(conn, table) {
    DBI::dbListFields(conn, table)
}

conn <<- init.conn()
allsites=tryCatch(
     readRDS("../data/sites_table.RDS")
 ,error=function(e){
     query.database("SELECT * FROM Sites;",conn=conn)
})
coords <- cbind(allsites$Longitude, allsites$Latitude)
tables <- get_table_list(conn)

