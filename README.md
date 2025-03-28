# BIAD Mini Shiny:

It's mini, it's shiny, it's BIADMINISHINY!

## Install the app

To use this app you will need to have credential to access [BIAD](biadwiki.org) and install a bunch of package. First the [BIADconnect](https://github.com/BIADwiki/BIADconnect) package, and a few shiny-related ones.

## Running the app

There are multiple ways to define/run a shiny app, I went for the the run shiny app from a folder way. Which meen we need a folder with `server.R` and `ui.R`

To run the shiny app this way one need to run:

```bash
Rscript -e "shiny::shinyAppDir('.',options=list(port=1112))" #I like to use the port option, if you don't specify it shiny create a different port each time, ennoying for debbuging
```


