<img src="https://github.com/daewoooo/SaaRclust/raw/master/saarclust_logo.png" />

# SaaRclust
R Package to cluster and orient long sequencing reads or contigs into chromosomal scaffolds to facilitate de novo genome assembly. To do so this package utilize single-cell Strand-seq data (Falconer et al., 2012) that are able to preserve structural contiguity of individual homologs.

Collaborators: David Porubsky, Maryam Ghareghani, Peter Ebert and Tobias Marschall

## Installation

### Development version from Github
To install the development version from Github, follow the steps given below. The installation has only been tested on Ubuntu so far, if you need to install on Windows or Mac additional steps might be necessary (e.g. installation of Rtools from https://cran.r-project.org/bin/windows/Rtools/)

1. Install a recent version of R (>=3.5) from https://www.r-project.org/
2. Optional: For ease of use, install Rstudio from https://www.rstudio.com/
3. Open R and install all dependencies. Please ensure that you have writing permissions to install packages. Execute the following lines one by one:

  install.packages("devtools")
	source("http://bioconductor.org/biocLite.R")
	library(devtools)
	install_github("daewoooo/SaaRclust2", ref = "main")
	
#### External Code
This package implements source code of orderContigsGreedy from [ContiBAIT](https://bioconductor.org/packages/contiBAIT) package. 
Copyright (c) 2015, Kieran O'Neill, Mark Hills, Mike Gottlieb

## Report Errors
If you encounter errors of any kind, please report an [issue here](https://github.com/daewoooo/SaaRclust/issues/new).

## NOTE
SaaRclust2 package is currently under development and contains unpublished work. Any usage for publishing is strictly prohibited without permission.

