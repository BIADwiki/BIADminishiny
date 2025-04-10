

get_elements <- function(x, element) {
	newlist=list()
	for(elt in names(x)){
		if(elt == element) newlist=append(newlist,x[[elt]])
		else if(is.list(x[[elt]])) newlist=append(newlist,get_elements(x[[elt]],element) )
	}
	return(newlist)
}

extractData <- function(tree,selected){
    print("treexpl")
    if (is.null(tree)){
        NULL
    } else{
        print("bloqued?")
        alldatas=lapply(get_selected(tree),function(node){
            if(node == 'data'){
                uptree=attr(node, "ancestry")
                data=selected
                print(uptree)
                for(i in 1:length(uptree)){
                    data=data[[uptree[i]]]
                }
                return(data$data)
            }
            else array(dim=c(0,0))
        })
        print("no..")
        if(length(alldatas)>0)return(alldatas[[1]])
        else NULL
    }
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
    print("hmhm?")
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

buttonList <- function(keys=NULL,keytype,count=NULL){
    print("buttonlist")
    #print(keys)

    if(is.null(keys))return(card())
    res=card(
         card_header(paste(keytype,"found",ifelse(is.null(count),":",paste0("(15 shown among ",count,"):")))),
         card_body( fillable = FALSE,
                   lapply(keys, function(key){ actionButton(inputId = paste0("key_", key), label = key)})
         )
    )
    print("done button")
    return(res)
}

shinyServer(function(input, output, session) {
  print(Sys.time())
  check.conn(conn)

  userCoords <- reactiveVal(NULL)  # Hold the user coordinates
  output$map <- renderLeaflet({
    leaflet() |> addTiles() |> setView(lng = 10, lat = 50, zoom = 4)
  })

  observe({
    print("listsite")
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
  siteData <- reactiveVal(NULL)    

  # Logic triggered by Find Matches button
  observeEvent(input$find_matches, {
    output$siteTree <- renderTree(NULL)
    output$selTxt <- DT::renderDT(NULL)
    output$key_buttons <- renderUI(buttonList())
    resetMap()
    location <- input$location
    selected_table <- input$table
    selected_field <- input$field
    result <- NULL
    print("going for the query")
   	count=NULL 
    if (nchar(location) > 0 && !is.null(selected_table) && !is.null(selected_field)) {
	max=30
      # Construct a SQL query with the selected field and location
      count <- paste0("SELECT count(*) FROM ",selected_table," WHERE ",selected_field," LIKE '%",location,"%'")
      count <- query.database(sql.command = count,conn = conn)
	  print(paste0("total ",count))
      query <- paste0("SELECT * FROM ",selected_table," WHERE ",selected_field," LIKE '%",location,"%' ORDER BY RAND() LIMIT ",max)
	  print(paste0("running",query))
      result <- query.database(sql.command = query,conn = conn)
      #print(result)
      #print(paste0("found ",nrow(result)," matches"))
      
      # Store result in reactive variable
      if (!is.null(result) && nrow(result) > 0) {
          if (nrow(result)==max) {
              showModal(modalDialog(
                                    title = "Limit reached",
                                    paste0("Only ",max," firsts results are shown, your query returned ",count," values, try to refined your query!"),
                                    easyClose = TRUE,
									footer = modalButton("OK"),
                                    ))
          }
          print("pass results")
          resultData(result)  # Update reactive value
        primaryKey <- get.primary.column.from.table(table.name = selected_table, conn = conn)
        mainKey <<- primaryKey

        # Generate UI for each primary key in the result
          print("generate button")
        output$key_buttons <- renderUI({ buttonList(result[, primaryKey],selected_table,count) })
          print("button done")
        result <- resultData()
        if (!is.null(result) && nrow(result) > 0 ) {
			sites<-NULL
            if(selected_table == "Sites"){
				sites <- result
            }
            else{
                print(paste("look for sites :",primaryKey,selected_table))
                #print(result[1:min(5,nrow(result)),])
                sites <- sapply(result[,primaryKey],function(key)get_elements(get.relatives(table.name=selected_table,primary.value=as.character(key),conn=conn),"Sites"))
                print("displaying sites ")
                print(sites)
                sites <- t(sapply(sites,function(i)i[,c("SiteID","SiteName","Latitude","Longitude")]))
                print("adding original info")
                sites <- cbind.data.frame(sites, notes=paste0(primaryKey,": ",result[,primaryKey],","))
                print("update map")
            }
			siteData(sites)
			updateSitesOnMap(sites)

        } else {
          # Optionally provide feedback if there are no results to show
			output$selTxt <- DT::renderDT(NULL)
        }
      } else {
		  showModal(modalDialog( title = "Nothing", paste0("No match!"), easyClose = TRUE, footer = modalButton("OK")))
        resultData(NULL)  # Clear reactive value
        output$selTxt <- DT::renderDT(NULL)
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
        print(nrow(result))
		count=NULL
        if (nrow(result)>24) {
			count=nrow(result)
            result <- result[1:25,]
            showModal(modalDialog(
                                  title = "Too much neighbours",
                                  paste0("Only the 25 closest sites are shown (found: ",count,")"),
                                  easyClose = TRUE,
								  footer = modalButton("OK")
                                  ))
        }
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
                buttonList(result[, primaryKey],"Site",count=count)
            })
        }
        else
			showModal(modalDialog( title = "Nothing", paste0("No sites found"), easyClose = TRUE, footer = modalButton("OK")))
        resultData(result)  # Update result data
    }
  })

  #maybe should use a reactive value and change only 'key'and leave other observer to do the jon
  observeEvent(input$map_marker_click,{ 
      print("tada?")
      click <- input$map_marker_click
      if(is.null(click)) return()
      print("getrel click")
      x <- get.relatives(table.name = input$table, primary.value = click$id, conn = conn)
      print("end getrel click")
      get_json <- reactive({
          treeToJSON(FromListSimple(x), pretty = TRUE)
      })
      print("render tree click")
      output$siteTree <- renderTree(get_json())
      output$selTxt <- DT::renderDT({
          tree <- input$siteTree
          print("heee")
          extractData(tree,x)
      })
      print("end render tree click")
  })

  observe({
      print("boom")
      req(resultData()) #whoever you are, probably an AI? but you can see I have no clue what i am doin can't you?
      primaryKey <- mainKey
      result <- resultData()
      if (!is.null(result) && nrow(result) > 0) {
          # Iterate over each primary key
          lapply(result[, primaryKey], function(key) {
		#print(paste0("whatiskey",key))
             observeEvent(input[[paste0("key_", key)]], {
				print("getrel gen")
				x <- get.relatives(table.name = input$table, primary.value = as.character(key), conn = conn)
				print("end getrel gen")
				if(input$table == "Sites"){
				    updateSitesOnMap(result,key)
				}
				else{
				    site_key <- get_elements(x,"Sites")[["data"]][,"SiteID"]
				    print(paste0("whatis site_key",site_key))
				    sites <- siteData()
				    updateSitesOnMap(sites,site_key)
				}
				print("render tree gen")
				get_json <- reactive({
				    treeToJSON(FromListSimple(x), pretty = TRUE)
				})
				output$siteTree <- renderTree(get_json())
				output$selTxt <- DT::renderDT({
				    tree <- input$siteTree
				    extractData(tree,x)
				})
				print("end render tree gen")
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
        else
			showModal(modalDialog( title = "Nothing", paste0("No sites found"), easyClose = TRUE, footer = modalButton("OK")))
  })


})


