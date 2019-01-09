## test
dat = subset(data, idtree == "prg_1_0_21998")
size = dat$dbh
time = dat$year
min_dbh = 10
ladder = dat$ladder



correct_size <- function(data,
                         size_col,
                         time_col,
                         status_col,
                         id_col,
                         positive_growth_threshold,
                         negative_growth_threshold,
                         default_POM){

  # Checks and format -------------------------------------------------------
  names(data)[which(names(data)== size_col)] <- "size"
  names(data)[which(names(data)== status_col)] <- "status"
  names(data)[which(names(data)== time_col)] <- "time"
  names(data)[which(names(data)== id_col)] <- "id"

  # Call internals by plot or not -------------------------------------------

  data <- .correct_size_plot(data,
                             positive_growth_threshold,
                             negative_growth_threshold,
                             default_POM)

}


# Internals ---------------------------------------------------------------

.correct_size_plot <- function(data_plot,
                               positive_growth_threshold,
                               negative_growth_threshold,
                               default_POM = 1.3){
  # Compute plot level growth
  data_plot$code_corr <- rep(0,nrow(data_plot))
  size_corr <- data_plot$size



  # # print(data_plot$Circ)
  # data_plot$cresc <- c(NA,diff(data_plot$size))
  # mismatch <- diff(data_plot$id)
  # print(data_plot$cresc)
  # data_plot$cresc[which(mismatch != 0)+1] <- NA

  # Extract ids and loop on indivs

  ids <- unique(data_plot$id)

  for(i in ids){

    tree <- data_plot[which(data_plot$id == i),]


    size <- tree$size
    size_corr <- tree$size_corr
    code_corr <- tree$code_corr
    time <- tree$time
    POM <- tree$POM

    # print(str(tree))
    # print(size_corr)
    res <- .correct_size_tree(size,
                              size_corr,
                              code_corr,
                              time,
                              POM,
                              default_POM,
                              positive_growth_threshold,
                              negative_growth_threshold,
                              i)

    # print(data_plot[which(data_plot$id == i),which(names(data_plot)%in% c("size_corr","code_corr"))])
    # print('data_plot[which(data_plot$id == i),c("size_corr","code_corr")]')
    # print(nrow(data_plot[which(data_plot$id == i),c("size_corr","code_corr")]))

    data_plot[which(data_plot$id == i),c("size_corr","code_corr")] <- res[,c("size_corr","code_corr")]
  }
  return(data_plot)
}


.correct_size_tree <- function(size,
                               size_corr,
                               code_corr,
                               time,
                               POM,
                               default_POM,
                               positive_growth_threshold,
                               negative_growth_threshold,
                               i) {
  # Xsav if for browser() use: save initial value of size
  # Xsav <- size

  # cresc_abs: absolute
  cresc_abs <- rep(0, length(size) - 1)
  cresc <- rep(0, length(size) - 1)


  if (sum(!is.na(size)) > 1) {
    cresc[which(!is.na(size))[-1] - 1] <-
      diff(size[!is.na(size)]) / diff(time[!is.na(size)])
    cresc_abs[which(!is.na(size))[-1] - 1] <- diff(size[!is.na(size)])
  }


  if (length(cresc) > 0) {


    res <- .correct_POM_changes(size,
                         size_corr,
                         code_corr,
                         cresc,
                         time,
                         POM,
                         default_POM,
                         positive_growth_threshold,
                         negative_growth_threshold,
                         i)

    size_corr <- res$size_corr
    code_corr <- res$code_corr

    res <- .correct_abnormal_growth_tree(size,
                                         size_corr,
                                         code_corr,
                                         cresc,
                                         time,
                                         positive_growth_threshold,
                                         negative_growth_threshold,
                                         i)

    size_corr <- res$size_corr
    code_corr <- res$code_corr



    ## replace missing values
    if (any(!is.na(size_corr))) {
      size_corr <- repl_missing(size_corr, time)
    }
    else {
      size_corr = rep(0, length(size_corr))
    }
  }
  return(size)
}



.correct_abnormal_growth_tree <- function(size,
                                          size_corr,
                                          code_corr,
                                          cresc,
                                          time,
                                          positive_growth_threshold,
                                          negative_growth_threshold,
                                          i){
  ####    if there is a DBH change > 5cm/year or < negative_growth_threshold cm   ####
  ### do as many corrections as there are abnormal DBH change values ###
  cresc_abn = sum(abs(cresc) >= positive_growth_threshold | cresc_abs < negative_growth_threshold)
  if (cresc_abn > 0) {
    for (i in 1:cresc_abn) {
      # begin with the census with the highest DBH change
      ab <- which.max(abs(cresc))

      # check if this census is truly abnormal
      if (abs(cresc[ab]) >= positive_growth_threshold | cresc_abs[ab] < negative_growth_threshold) {
        # values surrounding ab
        surround = c(ab - 2, ab - 1, ab + 1, ab + 2)
        # that have a meaning (no NAs or 0 values)
        surround = surround[surround > 0 &
                              surround <= length(cresc)]

        # mean DBH change around ab
        meancresc = max(mean(cresc[surround], na.rm = TRUE), 0)

        # moment of max and min DBH changes around ab (including ab, that should be one of the 2)
        sourround_ab = sort(c(surround, ab))
        up = sourround_ab[which.max(cresc[sourround_ab])]
        down = sourround_ab[which.min(cresc[sourround_ab])]

        if (length(surround) > 0) {
          # 1st case : excessive increase/decrease offset by a similar decrease in dbh, plus 5cm/yr
          # is there a value that could compensate the excessive DBH change?
          # check if removing those values would solve the problem (ie cresc < positive_growth_threshold & cresc_abs > negative_growth_threshold )
          if (isTRUE(down > up & cresc[up] * cresc[down] < 0 &
                     # first an increase and then a decrease in DBH
                     (size[down + 1] - size[up]) / (time[down + 1] - time[up])  < positive_growth_threshold &
                     size[down + 1] - size[up] > negative_growth_threshold) |
              isTRUE(up > down & cresc[up] * cresc[down] < 0 &
                     # first an decrease and then a increase in DBH
                     (size[up + 1] - size[down]) / (time[up + 1] - time[down])  < positive_growth_threshold &
                     size[up + 1] - size[down] > negative_growth_threshold)) {
            # correction: abnormal values are deleted and will be replaced later on (see missing)
            first <- min(up, down) + 1
            last <- max(up, down)
            size[first:last] <- NA
          }


          # 2nd case: abnormal DBH change with no return to initial values
          # we trust the set of measurements with more values
          # if they are the same size, then we trust the last one
          # ladders?
          else {
            if ((sum(!is.na(size[1:ab])) > sum(!is.na(size))/2) | isTRUE(ladder[ab] == 0 & ladder[ab+1] == 1)) {
              size[(ab + 1):length(size)] <-
                size[(ab + 1):length(size)] - cresc_abs[which.max(abs(cresc))] + meancresc *
                diff(time)[ab]
            } else {
              size[1:ab] <-
                size[1:ab] + (size[ab+1]-size[ab]) - meancresc * diff(time)[ab]
            }
          }
        }

        # cresc_abs: absolute annual diameter increment
        cresc <- rep(0, length(size) - 1)
        cresc_abs <- rep(0, length(size) - 1)
        if (sum(!is.na(size)) > 1) {
          cresc[which(!is.na(size))[-1] - 1] <-
            diff(size[!is.na(size)]) / diff(time[!is.na(size)])
          cresc_abs[which(!is.na(size))[-1] - 1] <- diff(size[!is.na(size)])
        }
      }
    }
  }
  # TAG TODO : add code corr
  return(res)
}





.correct_POM_changes <- function(size,
                                 size_corr,
                                 code_corr,
                                 cresc,
                                 time,
                                 POM,
                                 default_POM,
                                 i){
  ignore_negative_POM_changes = F
  code_corr <- rep(0, length(size))
  # Account for explicit POM changes

  if(POM[1] != default_POM){
    ####  WHAT ??? ###
    # How do we convert to dbh #
    warning(paste0("tree ",
                   i,
                   " is first measured with a POM equal to ",
                   POM[1],
                   ", thus translation-based corrections do not give a diameter at breast height for this tree."))
  }

  if(anyNA(POM)){
    POM <- .fill_na_POM(POM)
  }

  if(! all(POM == POM[1])){
    POM_diff <- diff(POM)
    if(!ignore_negative_POM_changes &
       any(POM_diff < 0)){
      msg <- paste0("It seems that you have negative POM changes ",
                    "for individual ",i,
                    " which is supposedly erroneous or abnormal.",
                    " If this is normal, run again with argument ignore_negative_pom_changes set to TRUE")
      stop(msg)
    }

    shifts <- which(!is.na(POM_diff) & POM_diff != 0)
    print("shifts")
    print(shifts)
    for(s in shifts){
      print("shifts numb")
      print(s)
      existing <- c(s-2,s-1,s+1,s+2)
      # print("prob1")
      # print(existing)
      existing <- existing[existing > 0 &
                             existing <= length(cresc) &
                             cresc[existing] > negative_growth_threshold*pi &
                             cresc[existing] < positive_growth_threshold*pi] #Because we don't want to use outlyers to compute expected growth...

      meancresc <- max(mean(cresc[existing], na.rm=TRUE), 0)

      correction <- - (size_corr[s+1] - size_corr[s]) + (meancresc*(time[s+1]-time[s]))

      size_corr[(s+1):length(size_corr)] <- (size_corr[(s+1):length(size_corr)]) + correction
      code_corr[(s+1):length(code_corr)] <- code_corr[(s+1):length(code_corr)]+1
    }
  }
  res <- data.frame("size_corr" = size_corr, "code_corr"=code_corr)
  print(cbind(res,size, POM))
  return(res)
}