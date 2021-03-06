% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/vec_ang.R
\name{vec_ang}
\alias{vec_ang}
\title{Calculate radial angles from horizontal and vertical component vectors}
\usage{
vec_ang(vx, vy)
}
\arguments{
\item{vx}{A numeric vector of 1 or more values representing
horizontal components of Euclidean vectors. \code{vx} can be obtained
using \code{\link{vec.x}}.}

\item{vy}{A numeric vector of 1 or more values representing vertical
components of Euclidean vectors. \code{vy} can be obtained using
\code{\link{vec.y}}.}
}
\value{
Returns the polar coordinate angle corresponding to each
  horizontal and vertical component vector pair.
}
\description{
Calculate the radial angle for each horizontal and
  vertical component vector pair.
}
\details{
vec_ang returns the angle corresponding to the horizontal
  (\eqn{vx}) and vertical vector components (\eqn{vy}) according to:
\deqn{atan2(vy, vx) + \pi}{atan2(vy, vx) + \pi}
}
\examples{
dpy <- 365                 # Days/yr
data(mndvi)                # Load data
t <- as.vector(mndvi$day)  # Days since January 1, 2000
r <- t2rad(t,dpy)          # Transform days of year to radians
v <- as.vector(mndvi$wc)   # MODIS NDVI for Willow Creek tower, WI
vx <- mean(vec.x(r,v), na.rm=TRUE) # Avg horizontal vector
vy <- mean(vec.y(r,v), na.rm=TRUE) # Avg vertical vector
rv_ang <- vec_ang(vx,vy)    # Angle of resultant vec (point of max activity)
}
\references{
Brooks, B.J., Lee, D.C., Desai, A.R., Pomara, L.Y.,
  Hargrove, W.W. (2017). Quantifying seasonal patterns in
  disparate environmental variables using the PolarMetrics R package.
}
\author{
Bjorn J. Brooks, Danny C. Lee, William W. Hargrove, Lars Y. Pomara
}
