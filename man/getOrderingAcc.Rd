% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{getOrderingAcc}
\alias{getOrderingAcc}
\title{Report ordering accuracy of de novo assembled contigs}
\usage{
getOrderingAcc(bed.data, cluster.ID = "ID", order.ID = "order")
}
\arguments{
\item{bed.data}{A \code{data.frame} object containing alignments of de novo assembly to the reference genome in BED format.}

\item{cluster.ID}{A column name the uniquely defines assignment of contigs to unique clusters.}

\item{order.ID}{A column name the uniquely defines order of each contigs within a cluster.}
}
\value{
A \code{data.frame} object.
}
\description{
This function takes alignments of de novo assembled contigs to the referene genome in BED format and reports
accuracy of ordering within each unique cluster.
}
\author{
David Porubsky
}
