# Load necessary libraries.
library(ggplot2)
library(shiny)
library(shinyAce)

# Keep track of data with these entries for each upload:
# 1. Name (filename with .csv stripped)
# 2. Location (path on server to use)
# 3. Data
dataList <- list()    

# All server code must be within shinyServer()
shinyServer(
    # Function takes input as a list from ui.R, and returns output as a list
    # of objects computed based on input list.
    function(input, output, session) {
        
        #####
        # Code download
        #####
        
            # Include a downloadable file of the plot in the output list.
            output$downloadCode <- downloadHandler(
                filename = function() {
                    paste("ggplot2Code.R")   
                },
                # The argument content below takes filename as a function
                # and returns what's printed to it.
                content = function(con) {
                    codeLines <- unlist(split(input$plotCode, "\n"))
                    writeLines(codeLines, con)
                }
            )
        
        #####
        # Data tab
        ##### 
        
            # Returns the name of the data file uploaded by the user.
            getDataName <- reactive({
                # Get name from input, remove .csv, then ensure it's a syntactically-valid object name.
                out <- input$uploadFile$name
                if (length(out) > 0) {
                    out <- sub(".csv", "", out)
                    out <- make.names(out)
                } else out <- NULL
                out
            })
        
            getDataPath <- reactive({
                # Get data path, will be used to read data file.
                input$uploadFile$datapath
            })
            
            # Returns the data file uploaded by the user.
            getData <- reactive({
                if (!is.null(getDataPath())) {
                    out <- read.csv(getDataPath(), 
                        header = TRUE,
                        stringsAsFactors = FALSE)
                } else out <- NULL
                out
            })
            
            updateDataList <- reactive({
                if (!is.null(getDataName())) {
                    dataName <- getDataName()
                    
                    # Defaults to using file name as dataName, but will
                    # avoid overwriting a previously uploaded data by appending a numeric suffix.
                    if (exists(dataName)) {
                        suffix <- 1L
                        while (exists(paste(dataName, suffix, sep=""))) suffix <- suffix + 1L
                        dataName <- paste(dataName, suffix, sep="")
                    }
                    
                    dataList[[dataName]]$name      <<- dataName
                    dataList[[dataName]]$colnames  <<- colnames(getData())
                    assign(dataName, getData(), envir = .GlobalEnv)
                    
                    out <- dataList
                } else out <- NULL
                out
                
            })
            
            output$dataInfo <- renderUI({
                if (length(updateDataList()) == 0L) out <- HTML("<pre>No data files have been uploaded yet.</pre>")
                else {
                    out <- lapply(
                        updateDataList(),
                        FUN = function(x) {
                           HTML(sprintf("<pre><strong>data.frame:</strong> %s<p><strong>column names: </strong>%s</pre>", x$name, paste(sort(x$colnames), collapse=", "))) 
                        })
                }
                out
            })
            
        #####
        # Help tab
        #####
        
            helpFunction <- reactive({
                input$helpFunctionSelect
            })
        
            output$helpFunctionFormals <- renderUI({
                list(
                    strong(sprintf("Formal arguments for function %s:", helpFunction())),
                    HTML(paste(names(formals(match.fun(helpFunction()))), collapse=", "))
                )
            })
        
            
        #####
        # Plotting tab
        #####
            
            # Get plot code from the aceEditor input object, and remove line breaks from it.
            plotCode <- reactive({
                input$plotCode
            })        
            
            # Create a plot object from the code in plotCode()
            plotObject <- reactive({
                plotNo <- input$plotButton
                isolate(eval(parse(text = gsub("\\n", "", plotCode()))))
            })
                
            # Include the printed plot in the output list.
            output$plot <- renderPlot({
                print(plotObject())
            })

        #####
        # Download tab
        #####
        
            # Get the selected download file type.
            downloadPlotType <- reactive({
                input$downloadPlotType  
            })
        
            observe({
                plotType    <- input$downloadPlotType
                plotTypePDF <- plotType == "pdf"
                plotUnit    <- ifelse(plotTypePDF, "inches", "pixels")
                plotUnitDef <- ifelse(plotTypePDF, 7, 480)
                
                updateNumericInput(
                    session,
                    inputId = "downloadPlotHeight",
                    label = sprintf("Height (%s)", plotUnit),
                    value = plotUnitDef)
                
                updateNumericInput(
                    session,
                    inputId = "downloadPlotWidth",
                    label = sprintf("Width (%s)", plotUnit),
                    value = plotUnitDef)
                
            })
        
        
            # Get the download dimensions.
            downloadPlotHeight <- reactive({
                input$downloadPlotHeight
            })
        
            downloadPlotWidth <- reactive({
                input$downloadPlotWidth
            })
        
            # Get the download file name.
            downloadPlotFileName <- reactive({
                input$downloadPlotFileName
            })
            
            # Include a downloadable file of the plot in the output list.
            output$downloadPlot <- downloadHandler(
                filename = function() {
                    paste(downloadPlotFileName(), downloadPlotType(), sep=".")   
                },
                # The argument content below takes filename as a function
                # and returns what's printed to it.
                content = function(con) {
                    # Gets the name of the function to use from the 
                    # downloadFileType reactive element. Example:
                    # returns function pdf() if downloadFileType == "pdf".
                    plotFunction <- match.fun(downloadPlotType())
                    plotFunction(con, width = downloadPlotWidth(), height = downloadPlotHeight())
                        print(plotObject())
                    dev.off(which=dev.cur())
                }
            )
            
    }
)