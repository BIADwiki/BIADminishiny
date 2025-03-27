## BIAD Mini Shiny:

It's mini, it's shiny, it's BIADMINISHINY!


There are multiple ways to define/run a shiny app, I went for the the run shiny app from a folder way. Which meen we need a folder with `server.R` and `ui.R`

To run the shiny app this way one need to run:

```bash
Rscript -e "shiny::shinyAppDir('shiny-app',options=list(port=1111))" #I like to use the port option, if you don't specify it shiny create a different port each time, ennoying for debbuging
```


