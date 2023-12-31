#' Concatenate FASTA sequences given a set of Genomic Ranges and cluster identity.
#'
#' This function takes a \code{\link{GRanges-class}} object and cluster assignment stored 
#' in 'ID' field and export concated FASTA file for each cluster and genomic region/contig 
#' assigned to a given cluster.
#' 
#' @param clustered.gr A \code{\link{GRanges-class}} object with given fields: dir - contig directionality
#' order - contig order and ID - contig assignment to clusters.
#' @param assembly.fasta An assembly FASTA file to extract DNA sequence determined by clustered.gr.
#' @param outputfolder A path to a folder to export concatenated FASTA sequences.
#' @param concat.fasta Set to \code{TRUE} if you want to concatenate FASTA sequences within a cluster by 100 N's.
#' @importFrom Rsamtools indexFa FaFile scanFa scanFaIndex
#' @importFrom Biostrings reverseComplement DNAStringSet writeXStringSet
#' @importFrom BiocGenerics as.data.frame
#' @author David Porubsky
#' @export
exportPseudoChromosomalScaffolds <- function(clustered.gr=NULL, assembly.fasta=NULL, outputfolder=NULL, concat.fasta=TRUE) {
  ## Check if submitted fasta file is indexed
  assembly.fasta.idx <- paste0(assembly.fasta, ".fai")
  if (!file.exists(assembly.fasta.idx)) {
    ptm <- startTimedMessage("Fasta file is not indexed, indexing")
    fa.idx <- Rsamtools::indexFa(file = assembly.fasta)
    stopTimedMessage(ptm)
  }
  ## Open FASTA file instance
  fa.file <- open(Rsamtools::FaFile(assembly.fasta))
  
  ## Go through all clusters and exports pseudo-chromosomal scaffolds
  clustered.grl <- GenomicRanges::split(clustered.gr, clustered.gr$ID)
  for (i in seq_along(clustered.grl)) {
    cluster.regions <- clustered.grl[[i]]
    cluster.ID <- unique(cluster.regions$ID)
    ptm <- startTimedMessage(paste0("Exporting FASTA for: ", cluster.ID))
    ## Sort ranges based on predicted order
    cluster.regions <- cluster.regions[order(cluster.regions$order)]
    ## Remove sequences not present in the FASTA index
    fa.idx <- Rsamtools::scanFaIndex(fa.file)
    cluster.regions <- suppressWarnings( subsetByOverlaps(cluster.regions, fa.idx) )
    if (length(cluster.regions) > 0) {
      ## Read in contigs for a given cluster
      cluster.seq <- Rsamtools::scanFa(file = fa.file, param = cluster.regions, as = "DNAStringSet")
      ## Reverse complement based on 'dir' field
      revcomp <- which(cluster.regions$dir == 'revcomp')
      cluster.seq[revcomp] <- Biostrings::reverseComplement(cluster.seq[revcomp])
      ## Reverse based on 'dir' field
      #rev <- which(cluster.regions$dir == 'rev')
      #cluster.seq[rev] <- Biostrings::reverse(cluster.seq[rev])
      if (concat.fasta) {
        ## Concatenate all sequences into a single FASTA separated by 100 N's.
        delim <- paste(rep('N', 100), collapse = '')
        cluster.seq.collapsed <- Biostrings::DNAStringSet(paste(cluster.seq, collapse = delim))
        names(cluster.seq.collapsed) <- cluster.ID
        ## Write final FASTA
        destination <- file.path(outputfolder, paste0(cluster.ID, '.fasta')) 
        Biostrings::writeXStringSet(x = cluster.seq.collapsed, filepath = destination, format = 'fasta')
      } else {
        #new.names <- paste0(names(cluster.seq), '_', cluster.regions$order, '_', cluster.regions$ploidy, '_', cluster.regions$ID)
        mcols.names <- do.call('paste', c(BiocGenerics::as.data.frame(mcols(cluster.regions)[,-1]), list(sep='_')))
        new.names <- paste(names(cluster.seq), mcols.names, sep = '_')
        names(cluster.seq) <- new.names
        ## Write final FASTA
        destination <- file.path(outputfolder, paste0(cluster.ID, '.fasta')) 
        Biostrings::writeXStringSet(x = cluster.seq, filepath = destination, format = 'fasta')
      }
    } else {
      message("    \nNo regions to export to FASTA file, skipping!!!", appendLF=FALSE)
    }  
    stopTimedMessage(ptm)
  }
}
