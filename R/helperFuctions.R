#' Obtain summary measures of minimap output.
#'
#' Takes imported data table and export relevant data quality measures.
#'
#' @param inputData A \code{data.frame} loaded by \code{\link[SaaRclust]{importTestData}}
#' @importFrom dplyr group_by summarise
#' @importFrom rlang .data
#' @author David Porubsky
#' 
getQualMeasure <- function(inputData) {
  ptm <- startTimedMessage("Getting data quality measures")
  
  #get number of SS reads per PB read
  SSreads.perPB <- sort(table(inputData$PBreadNames), decreasing = T) #this won't be needed when output will be already sorted by PBreads
  
  #get number of SS libs per PB read
  inputData %>% dplyr::group_by(.data$PBreadNames) %>% dplyr::summarise(counts = length(unique(.data$SSlibNames))) -> SSlib.perPB
  
  #get number of SS reads per lib per PB read
  SSreads.perPB.l <- split(inputData$SSlibNames, inputData$PBreadNames)
  SSreads.perlib.perPB <- sapply(SSreads.perPB.l, function(x) rle(sort(x))$lengths)
  SSreads.perlib.perPB <- do.call(c, SSreads.perlib.perPB)
  
  #get PB read distribution hist
  #hist.data <- hist(inputData$PBreadLen, breaks = 100)
  #hist.df <- data.frame(midpoints= hist.data$mids, freq= hist.data$counts)
  
  stopTimedMessage(ptm)
  return(list(SSreads.perPB=SSreads.perPB, SSlib.perPB=SSlib.perPB, SSreads.perlib.perPB=SSreads.perlib.perPB))
}

#' Check clustering accuracy
#'
#' Takes assigned identity of each PB read and compares it to known location.
#'
#' @param clusters List of clusters with predicted chromosome identity for each PB read
#' @author David Porubsky
#' 
getClusterAcc <- function(clusters) {
  stat <- list()
  miss.reads <- list()
  for (i in 1:length(clusters)) { 
    cluster <- clusters[[i]]
    max.chr <- names(which.max(table(cluster)))
    trues <- length(cluster[cluster == max.chr])
    miss <- length(cluster[cluster != max.chr])
    stat.df <- data.frame(trues=trues, miss=miss, id=i)
    
    miss.PBreads <- names(cluster[cluster != max.chr])
    miss.chr <- unname(cluster[cluster != max.chr])
    if (length(miss.PBreads)>0) {
      tab <- data.frame(miss.PBreads=miss.PBreads, miss.chr=miss.chr, id=i)
      miss.reads[[length(miss.reads)+1]] <- tab
    }
    stat[[length(stat)+1]] <- stat.df  
  }
  stat <- do.call(rbind, stat)
  miss.reads <- do.call(rbind, miss.reads)
  return(list(stat=stat, miss.reads=miss.reads))
}

                               
#' Computes the performance of the hard clustering algorithm
#' 
#' This function takes hard clustering results and check the accuracy against know genomic locations of PacBio reads
#' 
#' @param hard.clust An \code{integer} vecotr of cluster assignements of each PacBio read.
#' @param pb.chr The true chromosomes of PacBio reads.
#' @param pb.flag The true directionality of PacBio reads.
#' @param tab.filt A \code{data.frame} obejct containing selected the best PacBio alignments.
#' @param female Set to \code{TRUE} if analyzed data are coming from female individual.
#' @author Maryam Ghareghani, David Porubsky
#' 
hardClustAccuracy <- function(hard.clust, pb.chr, pb.flag, tab.filt, female=TRUE)
{
  # filter and keep PB reads that have only defined (true) chromosome names with flag 0 or 16
  if(female)
  {
    filt.chrom <- which(grepl('^chr[0-9X][0-9]?$',tab.filt$PBchrom))
  } else {
    filt.chrom <- which(grepl('^chr[0-9XY][0-9]?$',tab.filt$PBchrom))
  }
  filt.flag <- union(which(tab.filt$PBflag == 0), which(tab.filt$PBflag == 16))
  filt <- intersect(filt.chrom, filt.flag)
  tab <- tab.filt[filt,]
  
  # define the classe (true clusters)
  classes <- paste0(pb.chr, "_", pb.flag)
  # some extra filtering ---> take only those PB reads that have flag 0 or 16
  names(classes) <- names(pb.chr)
  # filter out the PB reads that have more than one chr or flag
  oneChrPBreads <- which(sapply(pb.chr, length)==1)
  oneFlagPBreads <- which(sapply(pb.flag, length)==1)
  classes <- classes[intersect(oneChrPBreads, oneFlagPBreads)]
  
  classes <- classes[which(names(classes) %in% tab$PBreadNames)]
  clusters <- hard.clust[which(names(hard.clust) %in% names(classes))]
  ord <- order(names(classes))
  classes <- classes[ord]
  clusters <- clusters[ord]
  
  t <- table(classes, clusters)
  clust.assigned <- apply(t, 2, function(x) which(x == max(x))[1])
  clust.purity <- sum(sapply(1:length(clust.assigned), function(i) t[clust.assigned[i],i]))/length(clusters)
  
  missed <- setdiff(1:nrow(t), clust.assigned)
  names(missed) <- rownames(t)[missed]
  clust.purity.perClust <- sapply(1:length(clust.assigned), function(i) t[clust.assigned[i],i]/sum(t[,i]))
  
  df <- data.frame(clustIDs=clust.assigned, clustNames=rownames(t)[clust.assigned], accuracy=clust.purity.perClust)
  df <- df[order(clust.purity.perClust),]
  
  
  return( list(acc=clust.purity, missed.clusters = missed) )
}


#' Simulate random theta estimates for cell type
#'
#' Function to simulate random theta values in order to initialize EM algorithm.
#'
#' @param num.cells Number of cells used in the analysis.
#' @param num.clusters Expected number of clusters. (for 22 autosomes == 44 clusters)
#' @importFrom stats runif
#' @author David Porubsky
#' 
#TODO: set parameter alpha to be optional
randomTheta <- function(num.cells=100, num.clusters=44) {
  theta.l <- list()
  for (j in 1:num.cells) {
    cell.theta <- list()
    for (k in 1:num.clusters) {
      random.type <- stats::runif(3)
      max.type <- which.max(random.type)
      if (max.type == 1) {
        theta <- c(0.9, 0.05, 0.05)
      } else if (max.type == 2) {
        theta <- c(0.05, 0.9, 0.05)
      } else {
        theta <- c(0.05, 0.05, 0.9)
      }
      cell.theta[[k]] <- theta
    }
    theta.l[[j]] <- do.call(rbind, cell.theta)
  }
  return(theta.l)
}


#' Rescale theta values for WC cell type.
#'
#' Adjust estimated theta values based on expected number of WC chromosomes given random segregation of parental homologues.
#'
#' @param theta.param A \code{list} of estimated cell types for each cluster and each cell.
#' @param theta.expected A \code{vector} of expected sums of probabilities to observe WW,CC or WC chromosomes across all cells.
#' @author David Porubsky
#' 
thetaRescale <- function(theta.param, theta.expected) {
  theta.rescaled <- list()
  for (i in 1:length(theta.param)) {
    theta.cell <- theta.param[[i]]
    theta.ObservedSums <- colSums(theta.cell)
    corr.factor <- theta.expected / theta.ObservedSums
    theta.param.rescaled <- t(t(theta.cell) * corr.factor)
    theta.param.rescaled.norm <- theta.param.rescaled / rowSums(theta.param.rescaled)
    theta.rescaled[[i]] <- theta.param.rescaled.norm
  }
  return(theta.rescaled)
}

#' Alternative sum function to reduce numerical error caused by finite precision of floating point numbers.
#'
#' @param x A \code{vector} of values tp sum up.
#' @export
#' 
kahansum <- function(x) {
  ks <- 0
  c <- 0
  for(i in 1:length(x)) {
    y <- x[i] - c
    kt <- ks + y
    c = (kt - ks) - y
    ks = kt
  }
  ks
}


#' Export best cluster IDs for each PB read
#' 
#' Function to get best clust ID for each PB read or eventually multiple cluster IDs if max pVal is lower than threshold
#'
#' @param soft.clust ...
#' @param prob.th ...
#' @author David Porubsky
#' 
exportGenomicLocations <- function(soft.clust, prob.th=0.6) {
  
  getMaxPvals <- function(pval.vector) {
    srt.pval <- sort(pval.vector, decreasing = T)
    breakpoint <- which.min(diff(srt.pval))
    max.pvals <- srt.pval[1:breakpoint]
    max.pvals.clust <- which(pval.vector %in% max.pvals)
    return(max.pvals.clust)
  }  
  
  max.pVal <- apply(soft.clust, 1, max)
  mask <- max.pVal >= prob.th
  ord <- apply(soft.clust[mask,], 1, which.max)
  
  read.IDs <- rep(list(0), nrow(soft.clust)) 
  read.IDs[mask] <- ord 
  
  best.idx <- apply(soft.clust[!mask,], 1, getMaxPvals)
  read.IDs[!mask] <- best.idx 
  
  names(read.IDs) <- rownames(soft.clust)

  return(list(clust.IDs=read.IDs, th.boolean=mask))
  #best.idx <- t( apply(soft.clust[!mask,], 1, function(x) which(x %in% sort(x, decreasing = T)[1:5])) )
  #best.pval <- t( apply(soft.clust[!mask,], 1, function(x) x[which(x %in% sort(x, decreasing = T)[1:5])]) )
}

exportGenomicLocationsAllBest <- function(soft.clust, prob.th=0.6) {
  
  getMaxPvals <- function(pval.vector) {
    srt.pval <- sort(pval.vector, decreasing = T)
    breakpoint <- which.min(diff(srt.pval))
    max.pvals <- srt.pval[1:breakpoint]
    max.pvals.clust <- which(pval.vector %in% max.pvals)
    return(max.pvals.clust)
  }  
  
  best.idx <- apply(soft.clust, 1, getMaxPvals)
  read.IDs <- best.idx 
  names(read.IDs) <- rownames(soft.clust)
  
  return(read.IDs)
}


#' Export corresponding cluster for true chromosome and directionality
#'
#' @param soft.clust Soft clustering probabilities for each long read and each cluster
#' @param chr.rows Expected location of long reads based on their mapping to a respective chromosome
#' @param chr.flag Expected directionality of long reads based on their mapping to a respective chromosome
#' @author David Porubsky
#' 
getClusterIdentityPerChrPerDir <- function(soft.clust, chr.rows, chr.flag) {
  max.Clust <- apply(soft.clust, 1, which.max)
  unique.clust.ID <- paste0(chr.rows,"_",chr.flag)
  unique.clust.ID <- factor(unique.clust.ID, unique(unique.clust.ID))
  clustByChromByflag <- split(max.Clust, unique.clust.ID)
  clustIdPerChrom <- lapply(clustByChromByflag, function(x) names(which.max(table(x))))
  clustIDperPB <- rep(as.numeric(unlist(clustIdPerChrom)), table(unique.clust.ID))
  return(clustIDperPB)
}

#' Export corresponding clusters for true chromosome
#'
#' @param soft.clust Soft clustering probabilities for each long read and each cluster
#' @param chr.rows Expected location of long reads based on their mapping to a respective chromosome
#' @author David Porubsky
#' 
getClusterIdentityPerChr <- function(soft.clust, chr.rows) {
  max.Clust <- apply(soft.clust, 1, which.max)
  clustByChrom <- split(max.Clust, chr.rows)
  clustIdPerChrom <- lapply(clustByChrom, function(x) as.numeric(names(sort(table(x), decreasing=T)[1:2])))
  return(clustIdPerChrom)
}


#' Print names of long reads into separate files based on soft clustering assignment.
#'
#' @param inputfolder Path to the data analysis folder
#' @param prob.th Filter out long reads with max probability below this threshold
#' @param minLib Filter out long reads with number of StrandS libraries being represented below this threshold
#' @importFrom utils write.table
#' @author David Porubsky
#' 
exportClusteredReads <- function(inputfolder=NULL, prob.th=NULL, minLib=NULL) {
  
  #This function exports group of largest probabilites per PacBio read.
  getMaxPvals <- function(pval.vector) {
    srt.pval <- sort(pval.vector, decreasing = T)
    breakpoint <- which.min(diff(srt.pval))
    max.pvals <- srt.pval[1:breakpoint]
    max.pvals.clust <- which(pval.vector %in% max.pvals)
    return(max.pvals.clust)
  }  
  
  folder.name <- paste0("ReadPerCluster_minLib", minLib, "_probTh", prob.th)
  destination <- file.path(inputfolder, folder.name)
  if (!file.exists(destination)) {
    dir.create(destination)
  } else {
    beQuiet <- do.call(file.remove, list(list.files(destination, full.names = TRUE)))
  }
  
  Clusters2process <- list.files(file.path(inputfolder, 'Clusters'), pattern = "clusters.RData", full.names = TRUE)
  Quals2process <- list.files(file.path(inputfolder, 'RawData'), pattern = "dataQuals.RData", full.names = TRUE)
  
  for (i in 1:length(Clusters2process)) {  
    data.file <- get(load(Clusters2process[i]))
    data.qual <- get(load(Quals2process[i]))
    fileID <- basename(Clusters2process[i])
    message("Processing file: ",fileID)
    
    #Sort data quals according to PB order in clusters
    SSlib.perPB <- data.qual$SSlib.perPB
    SSlib.perPB <- SSlib.perPB[match(rownames(data.file$soft.pVal), SSlib.perPB$PBreadNames),]
    pb.minLib <- SSlib.perPB$counts
    prob.tab <- data.file$soft.pVal
    
    #Find WC cluster in all cells
    theta.sums <- Reduce("+", data.file$theta.param)
    remove.clust <- which.max(theta.sums[,3])
    #Remove probabilities for always WC cluster
    prob.tab <- prob.tab[,-remove.clust]
    
    #Remove PB reads represneted by SSlib less than minLib
    filt <- pb.minLib >= minLib
    prob.tab <- prob.tab[filt,]
    
    #filter reads based on set probability treshold
    if (prob.th > 0 & !is.null(prob.th)) {
      max.prob <- apply(prob.tab, 1, max)
      mask <- max.prob >= prob.th
      Clust.locations <- apply(prob.tab[mask,], 1, which.max)
      readNames.perCluster <- split(names(Clust.locations), Clust.locations)
    } else {
      Clust.locations <- apply(prob.tab, 1, getMaxPvals)
      Clust.locations.expanded <- unlist(Clust.locations) #expand list of vectors
      names(Clust.locations.expanded) <- rep(names(Clust.locations), lengths(Clust.locations)) #assigne proper PB read names to expanded vector
      readNames.perCluster <- split(names(Clust.locations.expanded), Clust.locations.expanded)
    }
    
    for (k in 1:length(readNames.perCluster)) {
      filename <- paste0("reads_cluster", k, "_minLib", minLib, "_probTh", prob.th, ".txt")
      path2file <- file.path(destination, filename)
      utils::write.table(readNames.perCluster[[k]], file = path2file, append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)
    }
  } 
} 

