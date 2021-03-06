#' @name calc_metrics
#' @title Easy function for calculating all polar meatrics.
#' @description A basic, but fast function for calculating all polar
#'   metrics from arrays or xts objects.
#' @importFrom stats sd
#' @importFrom zoo index
#' @param input Either a vector of values or a 1-column xts object
#'   indexed with time stamps. If \code{input} is an xts object then omit
#'   argument \code{t}. Else if \code{input} is a vector of values then
#'   \code{t} should be set to a corresponding vector of time values.
#' @param t An optional vector of time values (e.g., days) corresponding
#'   to the input vector sampling points. Do not use this argument if
#'   \code{input} is an xts object.
#' @param yr_type Argument specifying either 'cal_yr' for output (of
#'   timing variables) given in days starting from Jan. 1, or 'rot_yr'
#'   for output in days starting from the average seasonal minimum.
#' @param timing Argument specifying 'from_vecs_integer' or
#'   'from_vecs_dpc' or 'from_percentiles_dpc'. Default is 'from_vecs_integer',
#'   which means the timing variable EMS, MS, & LMS will be calculated
#'   from the mean of VECTORS within their respective milestones with a
#'   precision to the nearest INTEGER (not the original dpc sampling of
#'   the data). 'from_vecs_dpc' means the timing variables EMS, MS & LMS
#'   will again be calculated from the mean of VECTORS, but only at one
#'   of the 1->dpc sampling points. 'from_percentiles_dpc' means all timing
#'   variables will be calculated from their percentile completion
#'   milestones at one of dpc sampling points. Note that ES & LS
#'   variables are always calculated from percentiles as is required by
#'   this methodology of defining the range of the growing season.
#' @param spc Integer value specifying the number of samples per cycle
#'   (measurements per year) in input.
#' @param lcut Numeric value in the range [0,0.5] passed to
#'   \code{window_idx} function. Indicates the percentile to truncate
#'   from the first half of each cycle. For example, 0.15 will result
#'   in remove the interval corresponding to [0\%,15\%] representing a
#'   window that begins after the 15th-percentile is crossed.
#' @param hcut Numeric value in the range (0.5,1] passed to
#'   \code{window_idx} function. Indicates the percentile to truncate
#'   from the last half of each cycle. For example, 0.85 will result in
#'   remove the interval corresponding to [85\%,100\%] representing a
#'   window that begins after the 85th-percentile is crossed.
#' @param return_vecs logical argument specifying whether or not to
#'   include all of the horizontal and vertical component vectors in output.
#' @param sin_cos logical argument. If TRUE then each timing
#'   metric (es, ms, etc.) is returned as its sine and cosine components,
#'   es is returned as es_sin and es_cos.
#' @details \code{calc_metrics} runs through the entire polar
#'   transformation process and conveniently outputs the final polar
#'   metrics for all years included in the input.
#' @return Returns a list with all of the derived polar metrics (e.g.,
#'   early season, mid season, etc.). Timing variables in output can
#'   be returned relative to the standard calendar year or rotated to
#'   a relative year using \code{yr_type} argument.
#'   Sine and cosine components can also be returned instead of days since
#'   start using \code{sin_cos} argument.
#'   The optional argument \code{return_vecs} can be used to add
#'   the actual vecturs used in deriving the polar metrics to the returned
#'   list. This will also return the overall average (all years) statistics
#'   of the resultant vector (rv) and its opposite the anti-vector (av).
#'   Table below indicates the variable components of each object within
#'   the returned list.
#' metrics (data frame):     year,
#'                           es (or es_sin, es_cos),    # Early ssn DOY
#'                           ems (or ems_sin, ems_cos), # Early-mid ssn DOY
#'                           ms (or ms_sin, ms_cos),    # Mid ssn DOY
#'                           lms (or lms_sin, lms_cos), # Late-mid ssn DOY
#'                           ls (or ls_sin, ls_cos),    # Late ssn DOY
#'                           s_intv,                    # Season length(days)
#'                           s_avg,                     # Avg data val in ssn
#'                           s_sd,                      # StDev of data dur ssn
#'                           s_mag,                     # Mag of avg vec in ssn
#'                           ems_mag,                   # Mag early-mid ssn vec
#'                           lms_mag,                   # Mag late-mid ssn vec
#'                           s_mag_std,                 # s_mag stdzd by GS NDVI
#'                           a_avg                      # Avg data val of yr
#' component_vectors (data frame): VX, VY               # Hrz, vert vec comp.
#' average_vectors (data frame): rv_idx, rv_ang,        # Resultant vector
#'                           rv_doy, rv_mag,            #  attributes
#'                           av_idx, av_ang, av_doy     # Anti-vector attr.
#' @examples
#' library(PolarMetrics)
#' library(xts)
#' input <- xts(mndvi$fef, as.Date(mndvi$date))
#' ### Calculate polar measures relative to calendar year
#' calc_metrics(input, yr_type='cal_yr', spc=46, lcut=0.15, hcut=0.8,
#'              return_vecs=FALSE, sin_cos=FALSE)
#' ### Calculate as above and return sine, cosine components of timing metrics
#' calc_metrics(input, yr_type='cal_yr', spc=46, lcut=0.15, hcut=0.8,
#'              return_vecs=FALSE, sin_cos=TRUE)
#' ### Calculate & return the average vectors for the entire time series
#' calc_metrics(input, yr_type='cal_yr', spc=46, lcut=0.15, hcut=0.8,
#'              return_vecs=TRUE, sin_cos=FALSE)$avg_vectors
#' ### Calculate & return the horizontal and vertical vector components
#' head(calc_metrics(input, yr_type='cal_yr', spc=46, lcut=0.15, hcut=0.8,
#'              return_vecs=TRUE, sin_cos=FALSE)$vectors)
#' @author Bjorn J. Brooks, Danny C. Lee, William W. Hargrove, Lars Y. Pomara
#' @references Brooks, B.J., Lee, D.C., Desai, A.R., Pomara, L.Y.,
#'   Hargrove, W.W. (2017). Quantifying seasonal patterns in
#'   disparate environmental variables using the PolarMetrics R package.
#' @export

calc_metrics <- function(input, t=NULL, timing='from_vecs_integer', yr_type, spc, lcut, hcut, return_vecs, sin_cos) {
  dpy <- 365 # Days per year
  if (is.null(t)) { # If no values supplied for t then obtain from xts index
    t <- as.integer(format(index(input), '%j')) # Time coordinates
  }
  t <- as.vector(t)
  input <- as.vector(input)
  if (length(input) != length(t)) {
    stop('input and t should be have the same number of values')
  }
  if (all(timing != c('from_vecs_integer', 'from_vecs_dpc', 'from_percentiles_dpc'))) {
    stop('Acceptable arguments for timing are: from_vecs_integer, from_vecs_dpc, or from_percentiles_dpc')
	}
  nyr <- length(input)/spc  # No. of years in input
  r <- t2rad(t, dpc=dpy)    # Transform days of year to radians
  v <- as.vector(input)     # Input values (e.g., NDVI)
  VX <- vec.x(r,v)        # Horizontal vectors
  VY <- vec.y(r,v)        # Vertical vectors
  vx <- mean(VX, na.rm=T) # Avg horizontal vector
  vy <- mean(VY, na.rm=T) # Avg vertical vector
  rv_ang <- vec_ang(vx,vy) # Angle of resultant vec (point of max activity)
  rv_idx <- rad2idx(rv_ang, spc=spc) # Index (1-spc) marking avg vector
  rv_doy <- rad2d(rv_ang, dpc=dpy) # Day of year equivalent of rv_ang
  rv_mag <- vec_mag(vx,vy) # Magnitude (length) of resultant vector
  av_ang <- avec_ang(rv_ang) # Angle marking point of least activity
  av_doy <- rad2d(av_ang, dpc=dpy) # Day of year equivalent of av_ang
  av_idx <- rad2idx(av_ang, spc=spc) # Idx (1-spc) marking avg start of yr
  ann_cum <- sum_cycle(v,av_idx,spc=spc)$cumsum # Accum vals within rot. yrs
  npy <- length(ann_cum)/spc # No. of complete years in output
  # Note, output is re-centered, and accumulates starting from av_idx
  #  (offset of variable yr from calendar yr) and has nyr-1 yrs of data
  #  due to re-centering.

  if (!isTRUE(sin_cos)) { # if false
    output <- data.frame(yr=rep(NA,npy),
    es=rep(NA,npy), ems=rep(NA,npy),
                    ms=rep(NA,npy), lms=rep(NA,npy), ls=rep(NA,npy),
                    s_intv=rep(NA,npy), s_avg=rep(NA,npy),
                    s_sd=rep(NA,npy), s_mag=rep(NA,npy),
                    s_mag_std=rep(NA,npy),
                    ems_mag=rep(NA,npy), lms_mag=rep(NA,npy),
                    a_avg=rep(NA,npy))
  } else if (isTRUE(sin_cos)) { # if true
    output <- data.frame(yr=rep(NA,npy),
    es=rep(NA,npy), ems=rep(NA,npy),
                    ms=rep(NA,npy), lms=rep(NA,npy), ls=rep(NA,npy),
                    s_intv=rep(NA,npy), s_avg=rep(NA,npy),
                    s_sd=rep(NA,npy), s_mag=rep(NA,npy),
                    s_mag_std=rep(NA,npy),
                    ems_mag=rep(NA,npy), lms_mag=rep(NA,npy),
    a_avg=rep(NA,npy),
    es_sin=rep(NA,npy), es_cos=rep(NA,npy),
    ems_sin=rep(NA,npy), ems_cos=rep(NA,npy),
    ms_sin=rep(NA,npy), ms_cos=rep(NA,npy),
    lms_sin=rep(NA,npy), lms_cos=rep(NA,npy),
    ls_sin=rep(NA,npy), ls_cos=rep(NA,npy))
  }

  for (J in 1:npy) { # Calculate pheno param's for each yr
    output$yr[J] <- J
    wi <- window_idx(ann_cum,npy,J,lcut,hcut) # early, mid, late-S ann_cum idx
    es_idx <- wi[1]
    ls_idx <- wi[5]
    be_idx <- c((spc*(J-1)+1),(spc*J))        # This cycle's beg/end indices
    es2ls <- es_idx:(ls_idx-1)                        # ann_cum idx from es2ls

		# Calculate from VECTOR ANGLES & with DPY (365) divisions
    if (timing == 'from_vecs_integer') {
      ms_ang <- vec_ang(mean(VX[es2ls], na.rm=TRUE), # Avg GS vector angle 
                        mean(VY[es2ls], na.rm=TRUE))
      ms_idx <- which.max(r[es2ls] > ms_ang) + es_idx # Index of MS milestone
      es2ms <- es_idx:(ms_idx-1)                      # ann_cum idx erly to mid
      ms2ls <- ms_idx:(ls_idx-1)                      # ann_cum idx mid to late
      # Angle of early-to-mid season average vector
      ems_ang <- vec_ang(mean(VX[es2ms], na.rm=TRUE),
                         mean(VY[es2ms], na.rm=TRUE))
      # Angle of mid-to-late season average vector
      lms_ang <- vec_ang(mean(VX[ms2ls], na.rm=TRUE),
                         mean(VY[ms2ls], na.rm=TRUE))
    	ms <- rad2d(ms_ang, dpc=dpy)        # DOY for mean vector between ES & LS
			ems <- rad2d(ems_ang, dpc=dpy)       # DOY for mean vector between ES & MS
	    lms <- rad2d(lms_ang, dpc=dpy)       # DOY for mean vector between MS & LS

		# Calculate from VECTOR ANGLES & with DPC (divisions
		#  per cycle) divisions. In the case of 8-day MODIS
		#  NDVI, this means that the output timing dates will
		#  only fall on one of the 46 8-day time points.
    } else if (timing == 'from_vecs_dpc') {
      ms_ang <- vec_ang(mean(VX[es2ls], na.rm=TRUE), # Avg GS vector angle 
                        mean(VY[es2ls], na.rm=TRUE))
      ms_idx <- which.max(r[es2ls] > ms_ang) + es_idx # Index of MS milestone
      es2ms <- es_idx:(ms_idx-1)                      # ann_cum idx erly to mid
      ms2ls <- ms_idx:(ls_idx-1)                      # ann_cum idx mid to late
      # Angle of early-to-mid season average vector
      ems_ang <- vec_ang(mean(VX[es2ms], na.rm=TRUE),
                         mean(VY[es2ms], na.rm=TRUE))
      # Angle of mid-to-late season average vector
      lms_ang <- vec_ang(mean(VX[ms2ls], na.rm=TRUE),
                         mean(VY[ms2ls], na.rm=TRUE))
      ems_idx <- which.max(r[es2ms] > ems_ang) + es_idx # Idx of EMS mlestne
      lms_idx <- which.max(r[ms2ls] > lms_ang) + ms_idx # Idx of LMS mlestne
    	ems <- t[ems_idx]                               # DOY for lcut+50/2
	    ms <- t[ms_idx]                                 # DOY for 50 %tile
			lms <- t[lms_idx]                               # DOY for hcut+50/2

		# Else get indices from PERCENTILES and use only
		#  (dpc divisions per cycle) divisions, such that the
		#  timing indices can only fall on one of those time
		#  points.  For example if dpc=46, then any timing
		#  output would only fall on one of those 46 time
		#  points (spaced roughly 8 days apart) during the
		#  year, as opposed to any of the 365 days.
    } else if (timing == 'from_percentiles_dpc') {
      ems_idx <- wi[2]
      ms_idx <- wi[3]
      lms_idx <- wi[4]
      es2ms <- es_idx:(ms_idx-1)                      # ann_cum idx erly to mid
      ms2ls <- ms_idx:(ls_idx-1)                      # ann_cum idx mid to late
    	ems <- t[ems_idx]                               # DOY for lcut+50/2
	    ms <- t[ms_idx]                                 # DOY for 50 %tile
			lms <- t[lms_idx]                               # DOY for hcut+50/2
    }
    es <- t[es_idx]                                   # DOY lcut, 15 %tile
    ls <- t[ls_idx]                                   # DOY for hcut
    if (yr_type == 'cal_yr') {
      # Timing variables relative to the calendar year
      output$es[J] <- as.integer(ceiling((es +        # DOY for ES milestone
                                          av_doy) %% dpy))
      output$ems[J] <- as.integer(ceiling((ems +      # DOY for EMS milestone
                                           av_doy) %% dpy))
      output$ms[J] <- as.integer(ceiling((ms +        # DOY for MS milestone
                                          av_doy) %% dpy))
      output$lms[J] <- as.integer(ceiling((lms +      # DOY for MLS milestone
                                           av_doy) %% dpy))
      output$ls[J] <- as.integer(ceiling((ls +        # DOY for LS milestone
                                          av_doy) %% dpy))
      if (isTRUE(sin_cos)) {
        # Sine, cosine timing variables relative to the calendar year
        output$es_sin[J] <- sin(r[es_idx] + av_ang)   # sin rad.ang. for ES
        output$es_cos[J] <- cos(r[es_idx] + av_ang)   # cos rad.ang. for ES
  			if (all(timing == 'from_vecs_integer')) {
 					output$ems_sin[J] <- sin(ems_ang + av_ang)  # sin rad.ang. for EMS
					output$ems_cos[J] <- cos(ems_ang + av_ang)  # cos rad.ang. for EMS
					output$ms_sin[J] <- sin(ms_ang + av_ang)    # sin rad.ang. for MS
					output$ms_cos[J] <- cos(ms_ang + av_ang)    # cos rad.ang. for MS
					output$lms_sin[J] <- sin(lms_ang + av_ang)  # sin rad.ang. for LMS
        	output$lms_cos[J] <- cos(lms_ang + av_ang)  # cos rad.ang. for LMS
				} else {
 					output$ems_sin[J] <- sin(r[ems_idx] + av_ang) # sin rad.ang. for EMS
					output$ems_cos[J] <- cos(r[ems_idx] + av_ang) # cos rad.ang. for EMS
					output$ms_sin[J] <- sin(r[ms_idx] + av_ang)   # sin rad.ang. for MS
					output$ms_cos[J] <- cos(r[ms_idx] + av_ang)   # cos rad.ang. for MS
					output$lms_sin[J] <- sin(r[lms_idx] + av_ang) # sin rad.ang. for LMS
        	output$lms_cos[J] <- cos(r[lms_idx] + av_ang) # cos rad.ang. for LMS
				}
        output$ls_sin[J] <- sin(r[ls_idx] + av_ang)   # sin rad.ang. for LS
        output$ls_cos[J] <- cos(r[ls_idx] + av_ang)   # cos rad.ang. for LS
      }
    } else if (yr_type == 'rot_yr') {
      # Timing variables relative to the rotated year
      output$es[J] <- es %% dpy                       # DOY for ES milestone
      output$ems[J] <- ems %% dpy                     # DOY for EMS milestone
      output$ms[J] <- ms %% dpy                       # DOY for MS milestone
      output$lms[J] <- lms %% dpy                     # DOY for MLS milestone
      output$ls[J] <- ls %% dpy                       # DOY for LS milestone
      if (isTRUE(sin_cos)) {
        # Sine, cosine timing vars relative to the rotated yr
        output$es_sin[J] <- sin(r[es_idx])            # sin rad.ang. for ES
        output$es_cos[J] <- cos(r[es_idx])            # cos rad.ang. for ES
  			if (all(timing == 'from_vecs_integer')) {
 					output$ems_sin[J] <- sin(ems_ang)           # sin rad.ang. for EMS
					output$ems_cos[J] <- cos(ems_ang)           # cos rad.ang. for EMS
					output$ms_sin[J] <- sin(ms_ang)             # sin rad.ang. for MS
					output$ms_cos[J] <- cos(ms_ang)             # cos rad.ang. for MS
					output$lms_sin[J] <- sin(lms_ang)           # sin rad.ang. for LMS
        	output$lms_cos[J] <- cos(lms_ang)           # cos rad.ang. for LMS
				} else {
					output$ems_sin[J] <- sin(r[ems_idx])        # sin rad.ang. for EMS
					output$ems_cos[J] <- cos(r[ems_idx])        # cos rad.ang. for EMS
					output$ms_sin[J] <- sin(r[ms_idx])          # sin rad.ang. for MS
					output$ms_cos[J] <- cos(r[ms_idx])          # cos rad.ang. for MS
	        output$lms_sin[J] <- sin(r[lms_idx])        # sin rad.ang. for LMS
        	output$lms_cos[J] <- cos(r[lms_idx])        # cos rad.ang. for LMS
				}
        output$ls_sin[J] <- sin(r[ls_idx])            # sin rad.ang. for LS
        output$ls_cos[J] <- cos(r[ls_idx])            # cos rad.ang. for LS
      }
    }
    output$s_intv[J] <- ls - es                       # Days in the grw season
    v_mu <- mean(v[es2ls], na.rm=TRUE)        # Mean for Seasn.
    output$s_avg[J] <- v_mu
    output$s_sd[J] <- sd(v[es2ls])            # Std. dev. for Seasn.
    output$a_avg[J] <- mean(v[be_idx[1]:be_idx[2]], na.rm=TRUE) # Full yr mean
    output$s_mag[J] <- vec_mag(mean(VX[es2ls], na.rm=TRUE), # Avg GS vector length
                               mean(VY[es2ls], na.rm=TRUE))
    # s_mag standardized by mean NDVI during the growing season
    output$s_mag_std[J] <- output$s_mag[J] /
                           mean(v[es2ls], na.rm=TRUE)
    # Magnitude of avg vec between ES & MS thresholds
    output$ems_mag[J] <- vec_mag(mean(VX[es2ms], na.rm=TRUE),
                                 mean(VY[es2ms], na.rm=TRUE))
    # Magnitude of avg vec between MS & LS thresholds
    output$lms_mag[J] <- vec_mag(mean(VX[ms2ls], na.rm=TRUE),
                                 mean(VY[ms2ls], na.rm=TRUE))
  }

  if (!isTRUE(return_vecs)) { # if false
    return(output)
  }  else if (isTRUE(return_vecs)) { # if true
    # If vector components requested then return by combining as list object
    output <- list('metrics' <- output,
                   'component_vectors' <- data.frame(VX=VX, VY=VY),
                   'average_vectors' <- data.frame(rv_idx=rv_idx,
                                                   rv_ang=rv_ang, rv_doy=rv_doy,
                                                   rv_mag=rv_mag, av_idx=av_idx,
                                                   av_ang=av_ang, av_doy=av_doy))
    return(output)
  }
}
