
get_elements <- function(x, element) {
	newlist=list()
	for(elt in names(x)){
		if(elt == element) newlist=append(newlist,x[[elt]])
		else if(is.list(x[[elt]])) newlist=append(newlist,get_elements(x[[elt]],element) )
	}
	return(newlist)
}

renderSitesOnMap <- function(df,  key = NULL){
    colors="blue"
    if(!is.null(key)) colors = ifelse(df[["SiteID"]] == key, 'red', 'blue') # Change color for selected key
    if(is.null(df$notes)) df$notes = ""

    renderLeaflet({
        leaflet(data = df) |>
        addTiles() |>
        addCircleMarkers(id = df$id, lng = as.numeric(df$Longitude), lat = as.numeric(df$Latitude), popup = paste(df$SiteID,":",df$SiteName,",",df$notes," last update:",df$time_last_update),color=colors)
    })
}

updateSitesOnMap <- function(df,  key = NULL){
    colors="blue"
    if(!is.null(key)) colors = ifelse(df[["SiteID"]] == key, 'red', 'blue') # Change color for selected key
    if(is.null(df$notes)) df$notes = ""

    leafletProxy("map", data = df) |>
        clearMarkers() |>
        addCircleMarkers(layerId=df$SiteID,lng = as.numeric(df$Longitude), lat = as.numeric(df$Latitude), popup = paste(df$SiteID,":",df$SiteName,",",df$notes," last update:",df$time_last_update),color=colors) |>
    fitBounds(lng1 = min(as.numeric(df$Longitude)),lng2 = max(as.numeric(df$Longitude)),lat1 = min(as.numeric(df$Latitude)),lat2 = max(as.numeric(df$Latitude)))
}

resetMap <- function(){
    leafletProxy("map") |> clearMarkers() |> clearShapes() |> setView(lng = 10, lat = 50, zoom = 4)
}

buttonList <- function(keys=NULL,keytype){
    if(is.null(keys))return(card())
    card(
         card_header(paste(keytype,"found:")),
         card_body( fillable = FALSE,
                   lapply(keys, function(key){ actionButton(inputId = paste0("key_", key), label = key)})
         )
    )
}

shinyServer(function(input, output, session) {
  print(Sys.time())

  userCoords <- reactiveVal(NULL)  # Hold the user coordinates
  output$map <- renderLeaflet({
    leaflet() |> addTiles() |> setView(lng = 10, lat = 50, zoom = 4)
  })

  observe({
    tables <- c("Sites", tables[tables != "Sites"])  # Start with "Sites" and append other tables
    updateSelectInput(session, "table", choices = tables)
    mainKey <<- "SiteID"
    primaryKey <<- "SiteID"
  })

  observeEvent(input$tabpan,{
    print(input$tabpan)
    output$siteTree <- renderTree(NULL)
    output$selTxt <- DT::renderDT(NULL)
    output$key_buttons <- renderUI(buttonList())
    resetMap()
  })


  observeEvent(input$table, {
    fields <- get_field_list(conn, input$table)
    if(input$table == "Sites") fields <- c("SiteName", fields[fields != "SiteName"])  
    output$fields_ui <- renderUI({
      selectInput("field", "Choose a field:", choices = fields)
    })
  })

  resultData <- reactiveVal(NULL)

  # Logic triggered by Find Matches button
  observeEvent(input$find_matches, {
    output$siteTree <- renderTree(NULL)
    output$key_buttons <- renderUI(buttonList())
    resetMap()
    location <- input$location
    selected_table <- input$table
    selected_field <- input$field
    output$selTxt <- renderUI(NULL)
    result <- NULL
    
    if (nchar(location) > 0 && !is.null(selected_table) && !is.null(selected_field)) {
      # Construct a SQL query with the selected field and location
      query <- paste0("SELECT * FROM ",selected_table," WHERE ",selected_field," LIKE '%",location,"%'")
      result <- query.database(sql.command = query,conn = conn)
      
      # Store result in reactive variable
      if (!is.null(result) && nrow(result) > 0) {
         resultData(result)  # Update reactive value
         primaryKey <- get.primary.column.from.table(table.name = selected_table, conn = conn)
         mainKey <<- primaryKey

         # Generate UI for each primary key in the result
         output$key_buttons <- renderUI({ buttonList(result[, primaryKey],selected_table) })
        result <- resultData()
        if (!is.null(result) && nrow(result) > 0 ) {
            if(selected_table == "Sites"){
                updateSitesOnMap(result)
            }
            else{
-                sites <- sapply(result[,primaryKey],function(key)get_elements(get.relatives(table.name=selected_table,primary.value=key,conn=conn),"Sites"))


				sites <- t(sapply(sites,function(i)i[,c("SiteID","SiteName","Latitude","Longitude")]))
				sites <- cbind.data.frame(sites, notes=paste0(primaryKey,": ",result[,primaryKey],","))
                updateSitesOnMap(sites)
			}

        } else {
          # Optionally provide feedback if there are no results to show
          output$selTxt <- renderPrint(print( "No results to show on map" ))
        }
      } else {
        resultData(NULL)  # Clear reactive value
        output$selTxt <- renderPrint(print("No results found"))
        output$key_buttons <- renderUI(buttonList())
      }
    }
  })

  observeEvent(input$find_matches_dis, {
    mainKey <<- "SiteID"
    output$siteTree <- renderTree(NULL)
    output$key_buttons <- renderUI(buttonList())
    print(input$name)
    print(input$latitude)
    print(input$longitude)
    if ((is.na(input$name) || input$name == "") && (is.na(input$latitude) || is.na(input$longitude))) {
      showModal(modalDialog(
        title = "Input Error",
        "Please enter either a name or both latitude and longitude.",
        easyClose = TRUE,
        footer = modalButton("Dismiss")
      ))
    } else{
        if(!is.na(input$name) && input$name != ""){
            print("fromm lonlat")
            focus  <- geocode(input$name)
            user_coords <- c(Longitude=focus$lon,Latitude=focus$lat)
        }
        else if (!is.null(input$latitude) && !is.null(input$longitude)) {
            print("fromm lonlat")
            user_coords <- c(Longitude=input$longitude,Latitude=input$latitude)
        }
        userCoords(user_coords)  # Update result data
        distances <- distm(x = coords, y = user_coords, fun = distHaversine)
        result <- allsites[distances <= input$distance * 1000, ,drop=F] # Convert km to meters
        leafletProxy("map",session) |>
           addCircleMarkers(lng = user_coords["Longitude"], lat = user_coords["Latitude"], popup = "POI", color = "green") |>
           #fitBounds(lng1 = lng_min, lat1 = lat_min, lng2 = lng_max, lat2 = lat_max) |>
           addCircles(
                      layerId="search_zone",
                      lng = user_coords["Longitude"], lat = user_coords["Latitude"],
                      radius = input$distance * 1000, weight = 1, color = "#FF0000"
           ) |>
           setView(lat = as.numeric(user_coords["Latitude"]),lng = as.numeric(user_coords["Longitude"]), zoom=8) 
        if(nrow(result)>0){
            updateSitesOnMap(result)
            output$key_buttons <- renderUI({
                buttonList(result[, primaryKey],"Site")
            })
        }
        resultData(result)  # Update result data
    }
  })

  observe({ 
      req(resultData())
      result <- resultData()
      click <- input$map_marker_click
      if(is.null(click)) return()
      x <- get.relatives(table.name = input$table, primary.value = click$id, conn = conn)
      #updateSitesOnMap(result,click$id)
      get_json <- reactive({
          treeToJSON(FromListSimple(x), pretty = TRUE)
      })
      output$siteTree <- renderTree(get_json())
      output$selTxt <- DT::renderDT({
          alldatas=NULL
          tree <- input$siteTree
          if (is.null(tree)){
              NULL
          } else{
              alldatas=lapply(get_selected(tree),function(node){
                  if(node == 'data'){
                      uptree=attr(node, "ancestry")
                      data=x
                      for(i in 1:length(uptree)){
                          data=data[[uptree[i]]]
                      }
                      return(data$data)
                  }
                  else array(dim=c(0,0))
              })
           if(length(alldatas)>0)return(alldatas[[1]])
           else NULL
          }
      })
  })

  observe({
      req(resultData())
      primaryKey <- mainKey
      result <- resultData()
      if (!is.null(result) && nrow(result) > 0) {
          # Iterate over each primary key
          lapply(result[, primaryKey], function(key) {
             observeEvent(input[[paste0("key_", key)]], {
                x <- get.relatives(table.name = input$table, primary.value = key, conn = conn)
                if(input$table == "Sites"){
                    #output$map <- renderSitesOnMap(result,key)
                    updateSitesOnMap(result,key)
                }
                get_json <- reactive({
                    treeToJSON(FromListSimple(x), pretty = TRUE)
                })
                output$siteTree <- renderTree(get_json())
                output$selTxt <- DT::renderDT({
                    tree <- input$siteTree
                    if (is.null(tree)){
                        NULL
                    } else{
                        alldatas=lapply(get_selected(tree),function(node){
                            if(node == 'data'){
                                uptree=attr(node, "ancestry")
                                data=x
                                for(i in 1:length(uptree)){
                                    data=data[[uptree[i]]]
                                }
                                return(data$data)
                            }
							else array(dim=c(0,0))
                        })
						if(length(alldatas)>0)return(alldatas[[1]])
						else NULL
                    }
                })
          })

      })
      }
	  else{
		  output$siteTree <- renderUI(NULL)
		  output$selTxt <- renderUI(NULL)
	  }
  })
  observeEvent(input$distance, {
      user_coords <- userCoords()
      if(is.null(user_coords)) return()()
      leafletProxy("map",session) |>
        removeShape(layerId = "search_zone") |>  
            addCircles(
                       layerId="search_zone",
                       lng = user_coords["Longitude"], lat = user_coords["Latitude"],
                       radius = input$distance * 1000, weight = 1, color = "#FF0000"
            ) 
      distances <- distm(x = coords, y = user_coords, fun = distHaversine)
      result <- allsites[distances <= input$distance * 1000, ,drop=F] # Convert km to meters
      if(nrow(result)>0){
          resultData(result)  # Update reactive value
          updateSitesOnMap(result)
          output$key_buttons <- renderUI( buttonList(result[,"SiteID"],"Site"))
      }
  })


})


