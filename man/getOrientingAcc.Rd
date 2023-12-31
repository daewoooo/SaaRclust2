% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{getOrientingAcc}
\alias{getOrientingAcc}
\title{Report orienting accuracy of de novo assembled contigs}
\usage{
getOrientingAcc(bed.data, cluster.ID = "ID", dir.ID = "dir")
}
\arguments{
\item{bed.data}{A \code{data.frame} object containing alignments of de novo assembly to the reference genome in BED format.}

\item{cluster.ID}{A column name the uniquely defines assignment of contigs to unique clusters.}

\item{dir.ID}{A column name the uniquely defines mapping directionality of each contigs to the reference genome.}
}
\value{
A \code{data.frame} object.
}
\description{
This function takes alignments of de novo assembled contigs to the referene genome in BED format and reports
accuracy of orienting within each unique cluster.
}
\author{
David Porubsky
}
