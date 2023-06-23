#' @name gl.filter.secondaries
#' @title Filters loci that represent secondary SNPs in a genlight object
#' @description
#' SNP datasets generated by DArT include fragments with more than one SNP and
#' record them separately with the same CloneID (=AlleleID). These multiple SNP
#' loci within a fragment (secondaries) are likely to be linked, and so you may
#' wish to remove secondaries.

#' This script filters out all but the first sequence tag with the same CloneID
#' after ordering the genlight object on based on repeatability, avgPIC in that
#' order (method='best') or at random (method='random').

#' The filter has not been implemented for tag presence/absence data.

#' @param x Name of the genlight object containing the SNP data [required].
#' @param method Method of selecting SNP locus to retain, 'best' or 'random'
#'  [default 'random'].
#' @param verbose Verbosity: 0, silent or fatal errors; 1, begin and end; 2,
#' progress log; 3, progress and results summary; 5, full report
#' [default 2, unless specified using gl.set.verbosity].
#' @return The genlight object, with the secondary SNP loci removed.
#' @author Custodian: Arthur Georges -- Post to
#' \url{https://groups.google.com/d/forum/dartr}
#' @examples
#' gl.report.secondaries(testset.gl)
#' result <- gl.filter.secondaries(testset.gl)
#' @family filter functions
#' @importFrom stats dpois
#' @import patchwork
#' @export

gl.filter.secondaries <- function(x,
                                  method = "random",
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
    
    if (method != "best" && method != "random") {
        cat(warn("  Warning: method must be specified, set to 'random'\n"))
    }
    
    # DO THE JOB
    
    if (verbose > 2) {
        cat(report("  Total number of SNP loci:", nLoc(x), "\n"))
    }
    
    # Sort the genlight object on AlleleID (asc), RepAvg (desc), AvgPIC (desc)
    if (method == "best") {
        if (verbose > 1) {
            cat(
                report(
                    "  Selecting one SNP per sequence tag based on best RepAvg 
                    and AvgPIC\n"
                )
            )
        }
        loc.order <-
            order(
                x@other$loc.metrics$AlleleID,-x@other$loc.metrics$RepAvg,
                -x@other$loc.metrics$AvgPIC
            )
        x2 <- x[, loc.order]
        x2@other$loc.metrics <- x@other$loc.metrics[loc.order, ]
    } else {
        if (verbose > 1) {
            cat(report("  Selecting one SNP per sequence tag at random\n"))
        }
        n <- length(x@other$loc.metrics$AlleleID)
        index <- sample(1:(n + 10000), size = n, replace = FALSE)
        
          x2 <- x[, order(index)]
          x2@other$loc.metrics <- x@other$loc.metrics[order(index), ]
        
    }
    # Extract the clone ID number
    a <- strsplit(as.character(x2@other$loc.metrics$AlleleID), "\\|")
    b <- unlist(a)[c(TRUE, FALSE, FALSE)]
    # Identify and remove secondaries from the genlight object, including the
    #metadata

      x3 <- x2[, duplicated(b) == FALSE]
      x3@other$loc.metrics <- x2@other$loc.metrics[duplicated(b) == FALSE, ]
    
    # Report secondaries from the genlight object
    if (verbose > 2) {
        if (is.na(table(duplicated(b))[2])) {
            nsec <- 0
        } else {
            nsec <- table(duplicated(b))[2]
        }
        cat("    Number of secondaries:", nsec, "\n")
        cat("    Number of loci after secondaries removed:",
            table(duplicated(b))[1],
            "\n")
    }
    
    # ADD TO HISTORY
    nh <- length(x3@other$history)
    x3@other$history[[nh + 1]] <- match.call()
    
    # FLAG SCRIPT END
    
    if (verbose > 0) {
        cat(report("Completed:", funname, "\n"))
    }
    
    return(x3)
}
