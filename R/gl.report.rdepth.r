#' @name gl.report.rdepth
#' @title Reports summary of Read Depth for each locus
#' @description
#' SNP datasets generated by DArT report AvgCountRef and AvgCountSnp as counts
#' of sequence tags for the reference and alternate alleles respectively.
#' These can be used to back calculate Read Depth. Fragment presence/absence
#' datasets as provided by DArT (SilicoDArT) provide Average Read Depth and
#' Standard Deviation of Read Depth as standard columns in their report. This
#' function reports the read depth by locus for each of several quantiles.
#' @param x Name of the genlight object containing the SNP or presence/absence
#'  (SilicoDArT) data [required].
#' @param plot.out Specify if plot is to be produced [default TRUE].
#' @param plot_theme Theme for the plot. See Details for options
#' [default theme_dartR()].
#' @param plot_colors List of two color names for the borders and fill of the
#'  plots [default gl.colors(2)].
#' @param save2tmp If TRUE, saves any ggplots and listings to the session
#' temporary directory (tempdir) [default FALSE].
#' @param verbose Verbosity: 0, silent or fatal errors; 1, begin and end; 2,
#' progress log; 3, progress and results summary; 5, full report
#' [default 2, unless specified using gl.set.verbosity].
#' @details
#'  The function displays a table of minimum, maximum, mean and quantiles for
#'  read depth against possible thresholds that might subsequently be specified
#'  in \code{\link{gl.filter.rdepth}}. If plot.out=TRUE, display also includes a
#'   boxplot and a histogram to guide in the selection of a threshold for
#'   filtering on read depth.
#'
#'  If save2tmp=TRUE, ggplots and relevant tabulations are saved to the
#'  session's temp directory (tempdir).
#'
#'  For examples of themes, see  \itemize{
#'  \item \url{https://ggplot2.tidyverse.org/reference/ggtheme.html} and \item
#'  \url{https://yutannihilation.github.io/allYourFigureAreBelongToUs/ggthemes/}
#'  }
#' @return An unaltered genlight object
#' @author Custodian: Arthur Georges -- Post to
#' \url{https://groups.google.com/d/forum/dartr}
#' @examples
#'  \donttest{
#' # SNP data
#' df <- gl.report.rdepth(testset.gl)
#' }
#' df <- gl.report.rdepth(testset.gs)
#' @seealso \code{\link{gl.filter.rdepth}}
#' @family report functions
#' @import patchwork
#' @export

gl.report.rdepth <- function(x,
                             plot.out = TRUE,
                             plot_theme = theme_dartR(),
                             plot_colors = gl.colors(2),
                             save2tmp = FALSE,
                             verbose = NULL) {
    # SET VERBOSITY
    verbose <- gl.check.verbosity(verbose)
    
    # FLAG SCRIPT START
    funname <- match.call()[[1]]
    utils.flag.start(func = funname,
                     build = "Jody",
                     verbosity = verbose)
    
    # CHECK DATATYPE
    datatype <- utils.check.datatype(x, verbose = verbose)
    
    # FUNCTION SPECIFIC ERROR CHECKING
    
    if (datatype == "SilicoDArT") {
        if (!is.null(x@other$loc.metrics$AvgReadDepth)) {
            rdepth <- x@other$loc.metrics$AvgReadDepth
        } else {
            stop(error(
                "Fatal Error: Read depth not included among the locus metrics"
            ))
        }
    } else if (datatype == "SNP") {
        if (!is.null(x@other$loc.metrics$rdepth)) {
            rdepth <- x@other$loc.metrics$rdepth
        } else {
            stop(error(
                "Fatal Error: Read depth not included among the locus metrics"
            ))
        }
    }
    
    # DO THE JOB
    
    # get title for plots
    if (plot.out) {
        if (datatype == "SNP") {
            title <- paste0("SNP data (DArTSeq)\nRead Depth by locus")
        } else {
            title <-
                paste0("Fragment P/A data (SilicoDArT)\nRead Depth by locus")
        }
        
        # Calculate maximum graph cutoffs
        max <- max(rdepth, na.rm = TRUE)
        max <- ceiling(max / 10) * 10
        
        # Boxplot
        p1 <-
            ggplot(data.frame(rdepth), aes(y = rdepth)) + 
          geom_boxplot(color = plot_colors[1], fill = plot_colors[2]) + 
          coord_flip() + plot_theme +
            xlim(range = c(-1, 1)) + 
          ylim(c(0, max)) +
          ylab(" ") + 
          theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) + 
          ggtitle(title)
        
        # Histogram
        p2 <-
            ggplot(data.frame(rdepth), aes(x = rdepth)) +
          geom_histogram(bins=100,color=plot_colors[1],fill = plot_colors[2]) + 
          xlim(c(0,max)) +
          xlab("Read Depth") + 
          ylab("Count") +
          plot_theme
    }
    
    # Print out some statistics
    stats <- summary(rdepth)
    cat(report("  Reporting Read Depth by Locus\n"))
    cat("  No. of loci =", nLoc(x), "\n")
    cat("  No. of individuals =", nInd(x), "\n")
    cat("    Minimum      : ", stats[1], "\n")
    cat("    1st quartile : ", stats[2], "\n")
    cat("    Median       : ", stats[3], "\n")
    cat("    Mean         : ", stats[4], "\n")
    cat("    3r quartile  : ", stats[5], "\n")
    cat("    Maximum      : ", stats[6], "\n")
    cat("    Missing Rate Overall: ", round(sum(is.na(as.matrix(
        x
    ))) / (nLoc(x) * nInd(x)), 2), "\n\n")
    
    # Determine the loss of loci for a given threshold using quantiles
    quantile_res <- quantile(rdepth, probs = seq(0, 1, 1 / 20),type=1)
    retained <- unlist(lapply(quantile_res, function(y) {
        res <- length(rdepth[rdepth >= y])
    }))
    pc.retained <- round(retained * 100 / nLoc(x), 1)
    filtered <- nLoc(x) - retained
    pc.filtered <- 100 - pc.retained
    df <-
        data.frame(as.numeric(sub("%", "", names(quantile_res))),
                   quantile_res,
                   retained,
                   pc.retained,
                   filtered,
                   pc.filtered)
    colnames(df) <-
        c("Quantile",
          "Threshold",
          "Retained",
          "Percent",
          "Filtered",
          "Percent")
    df <- df[order(-df$Quantile),]
    df$Quantile <- paste0(df$Quantile, "%")
    rownames(df) <- NULL
    
    # PRINTING OUTPUTS
    if (plot.out) {
        # using package patchwork
        p3 <- (p1 / p2) + plot_layout(heights = c(1, 4))
        suppressWarnings(print(p3))
    }
    print(df)
    
    # SAVE INTERMEDIATES TO TEMPDIR
    
    # creating temp file names
    if (save2tmp) {
        if (plot.out) {
            temp_plot <- tempfile(pattern = "Plot_")
            match_call <-
                paste0(names(match.call()),
                       "_",
                       as.character(match.call()),
                       collapse = "_")
            # saving to tempdir
            saveRDS(list(match_call, p3), file = temp_plot)
            if (verbose >= 2) {
                cat(report("  Saving the ggplot to session tempfile\n"))
            }
        }
        temp_table <- tempfile(pattern = "Table_")
        saveRDS(list(match_call, df), file = temp_table)
        if (verbose >= 2) {
            cat(report("  Saving tabulation to session tempfile\n"))
            cat(
                report(
                    "  NOTE: Retrieve output files from tempdir using 
                    gl.list.reports() and gl.print.reports()\n"
                )
            )
        }
    }
    
    # FLAG SCRIPT END
    
    if (verbose >= 1) {
        cat(report("Completed:", funname, "\n"))
    }
    
    # RETURN
    invisible(x)
    
}
