% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hardClust.R
\name{estimateTheta}
\alias{estimateTheta}
\title{Estimate theta values based on hard clustering}
\usage{
estimateTheta(counts.l = NULL, hard.clust = NULL, alpha = 0.1)
}
\arguments{
\item{counts.l}{A \code{list} of directional read counts per long read/contig per library.}

\item{hard.clust}{A \code{integer} of cluster assignments for each long read or contig.}

\item{alpha}{Estimated level of background in Strand-seq reads.}
}
\value{
A \code{list} of estimated theta values for every cluster and cell.
}
\description{
This function takes results of hard clustering and estimates majority cell types for each Strand-seq library
}
\examples{
## Get an example file
exampleFile <- system.file("extdata/data", "rawCounts_5e+06bp_dynamic.RData", package = "SaaRclust")
## Load BAM count table
counts.l <- get(load(exampleFile))
## Get hard clustering results
hardClust.ord <- hardClust(counts.l, num.clusters=100, nstart = 100)
## Estimate theta parameter
theta.param <- estimateTheta(counts.l, hard.clust=hardClust.ord, alpha=0.1)

}
\author{
David Porubsky
}
