# Input:
# The output of the estimated genic DP
# A list of genes that are known to NOT escape XCI (or a file).
# Output:
#
#dt <- data.table(tot)
#xciGenes <- "data/startdata/xciGene.txt"

#' Get fraction of cell expressing the inactivated allele
#'
#' @param dt A \code{data.table}. The data.
#' @param xciGenes A \code{character}. The name of the genes to analyze.
#'
#' @return A \code{data.table} containing the average, and median fraction of
#' expression of the inactivated chromosome for each subject.
#' @export
getCellFrac <- function(dt, xciGenes){
  xci <- readLines(xciGenes)
  dt <- dt[GENE %in% c(xci, "XIST"),]
  dt <- dt[, frac := AD_ref/tot]
  dt <- dt[frac > .5, frac := 1-frac] #Set fraction that are above .5 to 1-frac
  dt <- dt[tot < 10, tot := NA]
  dt <- dt[, frac_mean := mean(frac, na.rm = TRUE), by = "subject"]
  dt <- dt[, frac_median := median(frac, na.rm = TRUE), by = "subject"]

  dt_frac <- unique(dt[GENE == "XIST", list(subject, frac, frac_median, frac_mean)])
  setnames(dt_frac, "frac", "frac_XIST")
  return(dt_frac) #This is fracCell.allXci.txt
}

#Input:
# The output of estimated genicDP
# A list of genes that are known to NOT espcape XCI.
# The output of getCellFrac
#Output:
# For each cutoff: The pI, pval, sd, quantile

#' @export
getXIexpr <- function(dt, dt_frac, xciGenes, dp_max = 500){
  xci <- readLines(xciGenes)
  dt[, frac := AD_ref/tot]
  dt <- dt[GENE %in% xci]
  dt <- dt[gender == "female"]
  dt[tot > dp_max, AD_ref := frac*dp_max]
  dt[tot > dp_max, tot := dp_max]
  dt <- merge(dt, dt_frac, by = "subject")
  for(dp_cutoff in seq(50, 10, -10)){
    # Anything that depends on the coverage is affected by the cutoff
    dt[AD_ref < dp_cutoff, AD_ref := NA]
    dt[tot < dp_cutoff, tot := NA]
    dt[, pI := (AD_ref/tot + frac_mean - 1)/(2*frac_mean-1), by = c("GENE", "subject")]
    dt[, sd_pI := sqrt((AD_ref/tot)*(1-AD_ref/tot)/(tot))/abs(2*frac_mean-1), by = c("GENE", "subject")]
    dt[, pval_pI := pnorm(pI/sd_pI, mean = 0, lower.tail = FALSE), by = c("GENE", "subject")]
    dt[, t := pI/sd_pI]
    dt[, normExp := qnorm(pval_pI, lower.tail = FALSE)]
    write.table(dt[!is.na(normExp) & !is.nan(frac_XIST)], file=paste0("XIexpr_", dp_cutoff)) # Write the output for the cutoff
  }
}
