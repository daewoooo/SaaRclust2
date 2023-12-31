#' Order and orient contigs within each cluster
#'
#' This function takes a \code{\link{GRangesList-class}} object and order and orient each contigs
#' within the cluster and reports new clustered/scaffolded FASTA file.
#' 
#' @param clustered.grl A \code{\link{GRangesList-class}} object with cluster assignments for each contig.
#' @param split.pairs A \code{list} with a sets of cluster IDs that belong the same scaffold/chromosome.
#' @param ord.method A method ('TSP' or 'greedy') used to order contigs within a cluster (default: 'TSP')
#' @param min.region.to.order A minimum size region to try to order within a cluster.
#' @param filename A path to a file where clustered on ordered contigs should be stored.
#' @inheritParams countProb
#' @inheritParams importBams
#' @inheritParams connectDividedClusters
#' @importFrom S4Vectors endoapply
#' @importFrom BiocGenerics as.data.frame
#' @author David Porubsky
#' @export
#' @examples
#'\dontrun{
#'## Get example files
#'mergeClusters.file <- system.file("extdata/data", "connectedClusters_5e+06bp_dynamic.RData", package = "SaaRclust")
#'clustered.file <- system.file("extdata/data", "clustered.grl.RData", package = "SaaRclust")
#'## Load connected clusters
#'connected.clusters <- get(load(mergeClusters.file))
#'#'## Load clustered regions per single cell
#'clustered.grl <- get(load(clustered.file))
#'ordered.contigs.gr <- orderAndOrientClusters(clustered.grl=clustered.grl, split.pairs=connected.clusters, min.region.to.order=0)}
#' 
orderAndOrientClusters <- function(clustered.grl, split.pairs, ord.method='TSP', alpha=0.1, min.region.to.order=0, filename=NULL, remove.always.WC=FALSE) {
  
  ptm <- startTimedMessage("Preparing contigs for ordering and orienting")
  ## Merge by cluster ID
  grl.collapsed <- S4Vectors::endoapply(clustered.grl, function(x) collapseBins(x, id.field = 1, measure.field = c(2,3)))
  ## Add cluster ID
  grl.collapsed <- S4Vectors::endoapply(grl.collapsed, function(x) addClusterGroup(cluster.gr = x, cluster.groups = split.pairs$clusters))
  ## Merge by group ID [!!! this might disrupt ordering and confuse primary cluster IDs !!!] Collapses misorients within the same contig & cluster!!!
  #grl.collapsed <- S4Vectors::endoapply(grl.collapsed, function(x) collapseBins(x, id.field = 4, measure.field = c(2,3)))
  
  ## Remove ranges smaller than the min.region.to.order
  #if (min.region.to.order > 0) {
  #  grl.collapsed <- S4Vectors::endoapply(grl.collapsed, function(x) x[width(x) >= min.region.to.order])
  #}  
  
  ## Get strand state for each region
  grl.BN.probs <- lapply(grl.collapsed, function(x) countProb(minusCounts = x$W, plusCounts = x$C, alpha=alpha, log.scale=TRUE))
  grl.BN.probs.max <- lapply(grl.BN.probs, function(x) apply(x, 1, which.max))
  grl.BN.probs.max <- do.call(cbind, grl.BN.probs.max)
  ## Construct strand-state data.frame
  grl.BN.probs.max.df <- data.frame(grl.BN.probs.max, clust.ID = grl.collapsed[[1]]$clust.ID, group.ID = grl.collapsed[[1]]$group.ID)
  rownames(grl.BN.probs.max.df) <- as.character(grl.collapsed[[1]])
  stopTimedMessage(ptm)
  
  ## Loop over all clusters to order and orient them within a chromosome
  cluster.states.dfl <- split(grl.BN.probs.max.df, grl.BN.probs.max.df$group.ID)
  ordered.contigs.grl <- GenomicRanges::GRangesList()
  for (i in seq_along(cluster.states.dfl)) {
    ID <- names(cluster.states.dfl[i])
    message("Ordering cluster: ", ID)
    cluster.data <- cluster.states.dfl[[i]]
    cluster.m <- cluster.data
    
    ## Remove 'clust.ID' and 'group.ID' columns
    cluster.m <- cluster.m[,-which(colnames(cluster.m) %in% c('clust.ID', 'group.ID'))]
    
    ## Get indices of putative HET inversions
    HET.idx <- which(cluster.data$clust.ID %in% split.pairs$putative.HETs)
    
    ## Do not remove putative HET inversions if they consist more than 50% of all contigs in a cluster
    if ((length(HET.idx) / nrow(cluster.m)) >= 0.5) {
      HET.idx <- integer()
    }
    
    if (nrow(cluster.m) == 0) { next }
    
    ## Reorient misoriented contigs ##
    if (length(HET.idx) > 0) {
      ## Temporarily remove HET inversions from contig re-orienting procedure
      het.ctg <- cluster.m[HET.idx,]
      ## Add directionality mark to any putative HET inversion to be 'dir'
      rownames(het.ctg) <- paste0(rownames(het.ctg), '_dir')
      ## Synchronize contig directionality
      cluster.m <- syncClusterDir(contig.states = cluster.m[-HET.idx,])
      cluster.m <- rbind(cluster.m, het.ctg)
    } else {
      ## Synchronize contig directionality
      cluster.m <- syncClusterDir(contig.states = cluster.m)
    }  
    
    ## Order contigs using TSP or contiBAIT heuristic ##
    ## Remove ranges smaller than the 'min.region.to.order'
    if (min.region.to.order > 0) {
      cluster.m.gr <- string2GRanges(rownames(cluster.m))
      mask <- width(cluster.m.gr) >= min.region.to.order
      cluster.m <- cluster.m[mask,]
      cluster.m.gr.masked <- cluster.m.gr[!mask]
    } else {
      cluster.m.gr.masked <- GenomicRanges::GRanges()
    }
    
    if (nrow(cluster.m) > 2) {
      if (ord.method == 'TSP') {
        cluster.m.clustered <- orderContigsTSP(contig.states = cluster.m, filt.cols = FALSE)
      } else if (ord.method == 'greedy') {  
        cluster.m.clustered <- orderContigsGreedy(contig.states = cluster.m)
      } else {
        message("Unsupported ordering method!!! Use 'TSP' or 'greedy'")
      }  
      ## Export ordered contigs
      ordered.contigs <- string2GRanges(region.string = cluster.m.clustered$ordered.contigs)
      ordered.contigs$order <- 1:length(ordered.contigs)
      ordered.contigs$ID <- ID
    } else if (nrow(cluster.m) == 1 | nrow(cluster.m) == 2) {
      ## Export ordered contigs
      ordered.contigs <- string2GRanges(region.string = rownames(cluster.m))
      ordered.contigs$order <- 1:nrow(cluster.m)
      ordered.contigs$ID <- ID
    } else {
      ordered.contigs <- GenomicRanges::GRanges()
    }
    ## Add filtered contigs by 'min.region.to.order'
    if (length(cluster.m.gr.masked) > 0) {
      cluster.m.gr.masked$order <- 0
      cluster.m.gr.masked$ID <- ID
      ordered.contigs <- c(ordered.contigs, cluster.m.gr.masked)
    }
    
    ## Collapse neighbouring regions of the same contig and having the same directionality [TESTING]
    ## Define helper function
    collapseOrdContigs <- function(gr) {
      if (length(gr) > 1) {
        if (length(unique(gr$dir)) == 1) {
          gr.new <- reduce(gr)
          mcols(gr.new) <- mcols(gr[which.max(width(gr))])
          return(gr.new)
        } else {
          return(gr)
        }
      } else {
        return(gr)
      }
    }
    
    hits <- findOverlaps(ordered.contigs, reduce(ordered.contigs))
    contigs.grl <- split(ordered.contigs, subjectHits(hits))
    contigs.grl <- endoapply(contigs.grl, collapseOrdContigs)
    ordered.contigs <- unlist(contigs.grl, use.names = FALSE)
    ordered.contigs$order[ordered.contigs$order > 0] <- 1:length(ordered.contigs[ordered.contigs$order > 0])
    
    ## Store ordered and oriented regions per cluster
    ordered.contigs.grl[[length(ordered.contigs.grl) + 1]] <- ordered.contigs
  }
  
  ordered.contigs.gr <- unlist(ordered.contigs.grl, use.names = FALSE)
  ordered.contigs.df <- BiocGenerics::as.data.frame(ordered.contigs.gr)
  if (!is.null(filename) & is.character(filename)) {
    ## Export contig order
    utils::write.table(ordered.contigs.df, file = filename, quote = FALSE, row.names = FALSE, append = FALSE, sep = "\t")
  }
  return(ordered.contigs.gr)
}

