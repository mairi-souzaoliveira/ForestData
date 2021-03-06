% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/correct_alive.R
\name{.correct_alive_tree}
\alias{.correct_alive_tree}
\title{Internal tree-level life status correction}
\usage{
.correct_alive_tree(tree_temp, censuses, dead_confirmation_censuses, i)
}
\arguments{
\item{tree_temp}{a data.frame corresponding to a single tree's measurements, arranged by time}

\item{censuses}{numeric, censuses for the plot in which the tree is.}

\item{dead_confirmation_censuses}{see correct_alive}

\item{i}{character or numeric, but single value. the id of the tree that is being corrected in the function}
}
\value{
a data.frame containing the inputted individual-tree-level data with corrected life status. 1 = alive, 0 = dead. NAs indicate that the tree was unseen and cannot be considered yet. The output does not necessarily have the same number of lines as the input. Lines are added when the tree is unseen then seen alive again, with all columns being NA except trees' id, plot, census year and corrected status. Useless lines -with NA status before first sight alive, or after death- are suppressed.
}
\description{
Internal tree-level life status correction
}
