#' Title
#'
#' @param InputList
#'
#' @return
#' @export
#'
#' @examples
CompareAcrossData <- function(InputList, CatOrder = NULL) {

  library(shiny)

  nSpans = length(InputList)

  for(i in 1:length(InputList)){

    WorkStruct <- InputList[[i]]$OrderedData

    ValidCells <- intersect(colnames(InputList[[i]]$Expression),
              intersect(colnames(WorkStruct$CellExp),
                        names(WorkStruct$CellsPT))
              )

    InputList[[i]]$Expression <- InputList[[i]]$Expression[, colnames(InputList[[i]]$Expression) %in% ValidCells]
    WorkStruct$CellExp <- WorkStruct$CellExp[, colnames(WorkStruct$CellExp) %in% ValidCells]
    WorkStruct$CellsPT <- WorkStruct$CellsPT[names(WorkStruct$CellsPT) %in% ValidCells]

    InputList[[i]]$OrderedData <- WorkStruct

  }


  # Define UI
  ui <- fluidPage(

    # Application title
    titlePanel("Explore gene expression over the principal curve"),

    fluidPage(
      fluidRow(
        wellPanel(
          selectizeInput(
            inputId = 'GeneList', label = 'Select gene',
            choices = c('', sort(unique(unlist(lapply(lapply(InputList, "[[", "Expression"), rownames))))),
            selected = '',
            multiple = FALSE),
          lapply(1:nSpans, function(i){
            sliderInput(inputId = paste0("Span", i),
                        label = paste(InputList[[i]]$Name, "Span"), min = 0, max = 1, value = .25, step = .01)
            }
            )
        ),
        plotOutput("distPlot", height = "1500px")
      )
    )

  )

  # Define server logic
  server <- function(input, output, session) {

    # Plotting function ----------------------------------------

    output$distPlot <- renderPlot({

      gName <- input$GeneList

      print(paste("Plotting", gName))

      SpanVect <- rep(.25, length(InputList))

      for(i in 1:length(InputList)){
        SpanVect[i] <- input[[paste0("Span", i)]]
      }

      print(paste("Spans:", SpanVect))

      if(gName == ''){
        return(NULL)
      }

      plotList <- list()

      for(i in 1:length(InputList)){

        WorkStruct <- InputList[[i]]$OrderedData

        ReOrd.Sel <- match(colnames(WorkStruct$CellExp), names(WorkStruct$CellsPT))
        ReOrd.Sel.Mat <- match(colnames(InputList[[i]]$Expression), names(WorkStruct$CellsPT))

        if(!is.null(CatOrder)){
          WorkStruct$RecCoord$Stage <- factor(as.character(WorkStruct$RecCoord$Stage), levels = CatOrder)
        }

        if(gName %in% rownames(WorkStruct$NodesExp)){

          SmoothData <- data.frame(x=c(WorkStruct$CellsPT[ReOrd.Sel],
                                       WorkStruct$CellsPT[ReOrd.Sel] + max(WorkStruct$NodesPT),
                                       WorkStruct$CellsPT[ReOrd.Sel] - max(WorkStruct$NodesPT)),
                                   y=c(WorkStruct$CellExp[gName,],
                                       WorkStruct$CellExp[gName,],
                                       WorkStruct$CellExp[gName,]))

          p1 <- ggplot2::ggplot(data = data.frame(x=WorkStruct$NodesPT,
                                                  y=WorkStruct$NodesExp[gName,]),
                                mapping = ggplot2::aes(x = x, y = y, color="PC")) +
            ggplot2::labs(x = "Pseudotime", y="Gene expression", title = InputList[[i]]$Name) +
            ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5)) +
            ggplot2::geom_rect(data = WorkStruct$RecCoord,
                               mapping = ggplot2::aes(fill=Stage, xmin=Min, xmax=Max),
                               ymin = -Inf, ymax = Inf, inherit.aes = FALSE, alpha=.4) +
            ggplot2::geom_smooth(data = SmoothData,
                                 mapping = ggplot2::aes(x=x, y=y, color="Data"),
                                 inherit.aes = FALSE, span = SpanVect[i], method = "loess") +
            ggplot2::geom_point(data = data.frame(x=WorkStruct$CellsPT[ReOrd.Sel],
                                                  y=WorkStruct$CellExp[gName,]),
                                mapping = ggplot2::aes(x=x, y=y, color="Data"), inherit.aes = FALSE, alpha=.5) +
            ggplot2::geom_point() + ggplot2::geom_line() + ggplot2::scale_color_manual(values = c(Data = "blue", PC = "black")) +
            ggplot2::coord_cartesian(xlim = c(0, max(WorkStruct$NodesPT)))

        } else {

          if(gName %in% rownames(InputList[[i]]$Expression)){

            SmoothData <- data.frame(x=c(WorkStruct$CellsPT[ReOrd.Sel.Mat],
                                         WorkStruct$CellsPT[ReOrd.Sel.Mat] + max(WorkStruct$NodesPT),
                                         WorkStruct$CellsPT[ReOrd.Sel.Mat] - max(WorkStruct$NodesPT)),
                                     y=c(unlist(InputList[[i]]$Expression[gName,]),
                                         unlist(InputList[[i]]$Expression[gName,]),
                                         unlist(InputList[[i]]$Expression[gName,])))

            p1 <- ggplot2::ggplot(data = data.frame(x=WorkStruct$CellsPT[ReOrd.Sel.Mat],
                                                    y=unlist(InputList[[i]]$Expression[gName,])),
                                  mapping = ggplot2::aes(x=x, y=y, color="Data")) +
              ggplot2::labs(x = "Pseudotime", y="Gene expression", title = InputList[[i]]$Name) +
              ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5)) +
              ggplot2::geom_rect(data = WorkStruct$RecCoord,
                                 mapping = ggplot2::aes(fill=Stage, xmin=Min, xmax=Max),
                                 ymin = -Inf, ymax = Inf, inherit.aes = FALSE, alpha=.4) +
              ggplot2::geom_smooth(data = SmoothData,
                                   mapping = ggplot2::aes(x=x, y=y, color="Data"),
                                   inherit.aes = FALSE, span = SpanVect[i], method = "loess") +
              ggplot2::geom_point(alpha=.5) + ggplot2::scale_color_manual(values = c(Data = "blue", PC = "black")) +
              ggplot2::coord_cartesian(xlim = c(0, max(WorkStruct$NodesPT)))

          } else {

            p1 <- ggplot2::ggplot(data = data.frame(x=WorkStruct$CellsPT[ReOrd.Sel.Mat],
                                                    y=unlist(InputList[[i]]$Expression[1,])),
                                  mapping = ggplot2::aes(x=x, y=y, color="Data")) +
              ggplot2::labs(x = "Pseudotime", y="Gene expression", title = InputList[[i]]$Name) +
              ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5)) +
              ggplot2::geom_rect(data = WorkStruct$RecCoord,
                                 mapping = ggplot2::aes(fill=Stage, xmin=Min, xmax=Max),
                                 ymin = -Inf, ymax = Inf, inherit.aes = FALSE, alpha=.4) +
              ggplot2::scale_color_manual(values = c(Data = "blue", PC = "black")) +
              ggplot2::coord_cartesian(xlim = c(0, max(WorkStruct$NodesPT)))

          }



        }


        WorkStruct2 <- InputList[[i]]$PGStruct

        if(gName %in% rownames(InputList[[i]]$Expression)){
          p2 <- ProjectOnCircle(
            Points = WorkStruct2$Data,
            Edges = WorkStruct2$IntGrahs[[length(WorkStruct2$IntGrahs)]]$Edges,
            Nodes = WorkStruct2$IntGrahs[[length(WorkStruct2$IntGrahs)]]$Nodes,
            Categories = WorkStruct2$Categories,
            Title = InputList[[i]]$Name,
            ExpValues = unlist(InputList[[i]]$Expression[gName,])
          )
        } else {
          # p2 <- ggplot2::ggplot(data = data.frame(x=WorkStruct$NodesPT,
          #                                         y=WorkStruct$NodesExp[1,]),
          #                       mapping = ggplot2::aes(x = x, y = y, color="PC"))
          p2 <- ProjectOnCircle(
            Points = WorkStruct2$Data,
            Edges = WorkStruct2$IntGrahs[[length(WorkStruct2$IntGrahs)]]$Edges,
            Nodes = WorkStruct2$IntGrahs[[length(WorkStruct2$IntGrahs)]]$Nodes,
            Categories = WorkStruct2$Categories,
            Title = WorkStruct2$Name,
            ExpValues = NULL
          )
        }

        plotList[[length(plotList)+1]] <- p2
        plotList[[length(plotList)+1]] <- p1

      }

      gridExtra::grid.arrange(grobs = plotList, ncol=2)

    })

  }


  # Run the application
  shinyApp(ui = ui, server = server)

}

