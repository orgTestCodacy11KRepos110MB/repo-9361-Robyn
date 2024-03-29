# Copyright (c) Meta Platforms, Inc. and its affiliates.

# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

robyn_pareto <- function(InputCollect, OutputModels,
                         pareto_fronts = "auto",
                         min_candidates = 100,
                         calibration_constraint = 0.1,
                         quiet = FALSE,
                         calibrated = FALSE,
                         ...) {
  hyper_fixed <- attr(OutputModels, "hyper_fixed")
  OutModels <- OutputModels[unlist(lapply(OutputModels, function(x) "resultCollect" %in% names(x)))]

  resultHypParam <- bind_rows(lapply(OutModels, function(x) {
    mutate(x$resultCollect$resultHypParam, trial = x$trial)
  }))

  xDecompAgg <- bind_rows(lapply(OutModels, function(x) {
    mutate(x$resultCollect$xDecompAgg, trial = x$trial)
  }))

  if (calibrated) {
    resultCalibration <- bind_rows(lapply(OutModels, function(x) {
      x$resultCollect$liftCalibration %>%
        mutate(trial = x$trial) %>%
        rename(rn = .data$liftMedia)
    }))
  } else {
    resultCalibration <- NULL
  }

  if (!hyper_fixed) {
    df_names <- if (calibrated) {
      c("resultHypParam", "xDecompAgg", "resultCalibration")
    } else {
      c("resultHypParam", "xDecompAgg")
    }
    for (df in df_names) {
      assign(df, get(df) %>% mutate(
        iterations = (.data$iterNG - 1) * OutputModels$cores + .data$iterPar
      ))
    }
  } else if (hyper_fixed & calibrated) {
    df_names <- "resultCalibration"
    for (df in df_names) {
      assign(df, get(df) %>% mutate(
        iterations = (.data$iterNG - 1) * OutputModels$cores + .data$iterPar
      ))
    }
  }

  # If recreated model, inherit bootstrap results
  if (length(unique(xDecompAgg$solID)) == 1 & !"boot_mean" %in% colnames(xDecompAgg)) {
    bootstrap <- attr(OutputModels, "bootstrap")
    if (!is.null(bootstrap)) {
      xDecompAgg <- left_join(xDecompAgg, bootstrap, by = c("rn" = "variable"))
    }
  }

  xDecompAggCoef0 <- xDecompAgg %>%
    filter(.data$rn %in% InputCollect$paid_media_spends) %>%
    group_by(.data$solID) %>%
    summarise(coef0 = min(.data$coef, na.rm = TRUE) == 0)

  if (!hyper_fixed) {
    mape_lift_quantile10 <- quantile(resultHypParam$mape, probs = calibration_constraint, na.rm = TRUE)
    nrmse_quantile90 <- quantile(resultHypParam$nrmse, probs = 0.90, na.rm = TRUE)
    decomprssd_quantile90 <- quantile(resultHypParam$decomp.rssd, probs = 0.90, na.rm = TRUE)
    resultHypParam <- left_join(resultHypParam, xDecompAggCoef0, by = "solID") %>%
      mutate(
        mape.qt10 =
          .data$mape <= mape_lift_quantile10 &
            .data$nrmse <= nrmse_quantile90 &
            .data$decomp.rssd <= decomprssd_quantile90
      )

    resultHypParamPareto <- filter(resultHypParam, .data$mape.qt10 == TRUE)
    px <- rPref::low(resultHypParamPareto$nrmse) * rPref::low(resultHypParamPareto$decomp.rssd)
    resultHypParamPareto <- rPref::psel(resultHypParamPareto, px, top = nrow(resultHypParamPareto)) %>%
      arrange(.data$iterNG, .data$iterPar, .data$nrmse) %>%
      rename("robynPareto" = ".level") %>%
      select(.data$solID, .data$robynPareto)
    resultHypParam <- left_join(resultHypParam, resultHypParamPareto, by = "solID")
  } else {
    resultHypParam <- mutate(resultHypParam, mape.qt10 = TRUE, robynPareto = 1, coef0 = NA)
  }

  # Calculate combined weighted error scores
  resultHypParam$error_score <- errors_scores(resultHypParam)

  # Bind robynPareto results
  xDecompAgg <- left_join(xDecompAgg, select(resultHypParam, .data$robynPareto, .data$solID), by = "solID")
  decompSpendDist <- bind_rows(lapply(OutModels, function(x) {
    mutate(x$resultCollect$decompSpendDist, trial = x$trial)
  })) %>%
    {
      if (!hyper_fixed) mutate(., solID = paste(.data$trial, .data$iterNG, .data$iterPar, sep = "_")) else .
    } %>%
    left_join(select(resultHypParam, .data$robynPareto, .data$solID), by = "solID")

  # Prepare parallel loop
  if (TRUE) {
    if (check_parallel() & OutputModels$cores > 1) registerDoParallel(OutputModels$cores) else registerDoSEQ()
    if (hyper_fixed) pareto_fronts <- 1
    # Get at least 100 candidates for better clustering
    if (nrow(resultHypParam) == 1) pareto_fronts <- 1
    if ("auto" %in% pareto_fronts) {
      n_pareto <- resultHypParam %>%
        filter(!is.na(.data$robynPareto)) %>%
        nrow()
      if (n_pareto <= min_candidates & nrow(resultHypParam) > 1 & !calibrated) {
        stop(paste(
          "Less than", min_candidates, "candidates in pareto fronts.",
          "Increase iterations to get more model candidates or decrease min_candidates in robyn_output()"
        ))
      }
      auto_pareto <- resultHypParam %>%
        filter(!is.na(.data$robynPareto)) %>%
        group_by(.data$robynPareto) %>%
        summarise(n = n_distinct(.data$solID)) %>%
        mutate(n_cum = cumsum(.data$n)) %>%
        filter(.data$n_cum >= min_candidates) %>%
        slice(1)
      message(sprintf(
        ">> Automatically selected %s Pareto-fronts to contain at least %s pareto-optimal models (%s)",
        auto_pareto$robynPareto, min_candidates, auto_pareto$n_cum
      ))
      pareto_fronts <- as.integer(auto_pareto$robynPareto)
    }
    pareto_fronts_vec <- 1:pareto_fronts

    decompSpendDistPar <- decompSpendDist[decompSpendDist$robynPareto %in% pareto_fronts_vec, ]
    resultHypParamPar <- resultHypParam[resultHypParam$robynPareto %in% pareto_fronts_vec, ]
    xDecompAggPar <- xDecompAgg[xDecompAgg$robynPareto %in% pareto_fronts_vec, ]
    respN <- NULL
  }

  if (OutputModels$cores > 1) {
    resp_collect <- foreach(
      respN = seq_along(decompSpendDistPar$rn), .combine = rbind
    ) %dorng% {
      get_resp <- robyn_response(
        media_metric = decompSpendDistPar$rn[respN],
        select_model = decompSpendDistPar$solID[respN],
        metric_value = decompSpendDistPar$mean_spend[respN],
        dt_hyppar = resultHypParamPar,
        dt_coef = xDecompAggPar,
        InputCollect = InputCollect,
        OutputCollect = OutputModels,
        quiet = quiet
      )$response
      dt_resp <- data.frame(
        mean_response = get_resp,
        rn = decompSpendDistPar$rn[respN],
        solID = decompSpendDistPar$solID[respN]
      )
      return(dt_resp)
    }
    stopImplicitCluster()
    registerDoSEQ()
    getDoParWorkers()
  } else {
    resp_collect <- lapply(seq_along(decompSpendDistPar$rn), function(respN) {
      get_resp <- robyn_response(
        media_metric = decompSpendDistPar$rn[respN],
        select_model = decompSpendDistPar$solID[respN],
        metric_value = decompSpendDistPar$mean_spend[respN],
        dt_hyppar = resultHypParamPar,
        dt_coef = xDecompAggPar,
        InputCollect = InputCollect,
        OutputCollect = OutputModels,
        quiet = quiet
      )$response
      dt_resp <- data.frame(
        mean_response = get_resp,
        rn = decompSpendDistPar$rn[respN],
        solID = decompSpendDistPar$solID[respN]
      )
      return(dt_resp)
    })
    resp_collect <- bind_rows(resp_collect)
  }

  decompSpendDist <- left_join(
    decompSpendDist,
    resp_collect,
    by = c("solID", "rn")
  ) %>%
    mutate(
      roi_mean = .data$mean_response / .data$mean_spend,
      roi_total = .data$xDecompAgg / .data$total_spend,
      cpa_mean = .data$mean_spend / .data$mean_response,
      cpa_total = .data$total_spend / .data$xDecompAgg
    )

  xDecompAgg <- left_join(
    xDecompAgg,
    select(
      decompSpendDist, .data$rn, .data$solID, .data$total_spend, .data$mean_spend,
      .data$spend_share, .data$effect_share, .data$roi_mean, .data$roi_total, .data$cpa_total
    ),
    by = c("solID", "rn")
  )

  # Pareto loop (no plots)
  mediaVecCollect <- list()
  xDecompVecCollect <- list()
  meanResponseCollect <- list()
  plotDataCollect <- list()
  df_caov_pct_all <- dplyr::tibble()

  for (pf in pareto_fronts_vec) {
    plotMediaShare <- filter(
      xDecompAgg,
      .data$robynPareto == pf,
      .data$rn %in% InputCollect$paid_media_spends
    )
    uniqueSol <- unique(plotMediaShare$solID)
    plotWaterfall <- xDecompAgg[xDecompAgg$robynPareto == pf, ]
    dt_mod <- InputCollect$dt_mod
    dt_modRollWind <- InputCollect$dt_modRollWind
    if (!quiet & length(unique(xDecompAgg$solID)) > 1) {
      message(sprintf(">> Pareto-Front: %s [%s models]", pf, length(uniqueSol)))
    }

    # To recreate "xDecompVec", "xDecompVecImmediate", "xDecompVecCarryover" for each model
    temp <- OutputModels[names(OutputModels) %in% paste0("trial", 1:OutputModels$trials)]
    xDecompVecImmCarr <- bind_rows(lapply(temp, function(x) x$resultCollect$xDecompVec)) %>%
      mutate(solID = paste(.data$trial, .data$iterNG, .data$iterPar, sep = "_")) %>%
      filter(.data$solID %in% uniqueSol)

    # Calculations for pareto AND pareto plots
    for (sid in uniqueSol) {
      # parallelResult <- foreach(sid = uniqueSol) %dorng% {
      if (!quiet & length(unique(xDecompAgg$solID)) > 1) {
        lares::statusbar(which(sid == uniqueSol), length(uniqueSol), type = "equal")
      }

      ## 1. Spend x effect share comparison
      temp <- plotMediaShare[plotMediaShare$solID == sid, ] %>%
        tidyr::gather(
          "variable", "value",
          c("spend_share", "effect_share", "roi_total", "cpa_total")
        ) %>%
        select(c("rn", "nrmse", "decomp.rssd", "rsq_train", "variable", "value")) %>%
        mutate(rn = factor(.data$rn, levels = sort(InputCollect$paid_media_spends)))
      plotMediaShareLoopBar <- filter(temp, .data$variable %in% c("spend_share", "effect_share"))
      plotMediaShareLoopLine <- filter(temp, .data$variable == ifelse(
        InputCollect$dep_var_type == "conversion", "cpa_total", "roi_total"
      ))
      line_rm_inf <- !is.infinite(plotMediaShareLoopLine$value)
      ySecScale <- max(plotMediaShareLoopLine$value[line_rm_inf]) /
        max(plotMediaShareLoopBar$value) * 1.1
      plot1data <- list(
        plotMediaShareLoopBar = plotMediaShareLoopBar,
        plotMediaShareLoopLine = plotMediaShareLoopLine,
        ySecScale = ySecScale
      )

      ## 2. Waterfall
      plotWaterfallLoop <- plotWaterfall %>%
        filter(.data$solID == sid) %>%
        arrange(.data$xDecompPerc) %>%
        mutate(
          end = 1 - cumsum(.data$xDecompPerc),
          start = lag(.data$end),
          start = ifelse(is.na(.data$start), 1, .data$start),
          id = row_number(),
          rn = as.factor(.data$rn),
          sign = as.factor(ifelse(.data$xDecompPerc >= 0, "Positive", "Negative"))
        ) %>%
        select(
          .data$id, .data$rn, .data$coef,
          .data$xDecompAgg, .data$xDecompPerc,
          .data$start, .data$end, .data$sign
        )
      plot2data <- list(plotWaterfallLoop = plotWaterfallLoop)

      ## 3. Adstock rate
      dt_geometric <- weibullCollect <- wb_type <- NULL
      resultHypParamLoop <- resultHypParam[resultHypParam$solID == sid, ]
      get_hp_names <- !endsWith(names(InputCollect$hyperparameters), "_penalty")
      get_hp_names <- names(InputCollect$hyperparameters)[get_hp_names]
      hypParam <- resultHypParamLoop[, get_hp_names]
      if (InputCollect$adstock == "geometric") {
        hypParam_thetas <- unlist(hypParam[paste0(InputCollect$all_media, "_thetas")])
        dt_geometric <- data.frame(channels = InputCollect$all_media, thetas = hypParam_thetas)
      }
      if (InputCollect$adstock %in% c("weibull_cdf", "weibull_pdf")) {
        shapeVec <- unlist(hypParam[paste0(InputCollect$all_media, "_shapes")])
        scaleVec <- unlist(hypParam[paste0(InputCollect$all_media, "_scales")])
        wb_type <- substr(InputCollect$adstock, 9, 11)
        weibullCollect <- list()
        n <- 1
        for (v1 in seq_along(InputCollect$all_media)) {
          dt_weibull <- data.frame(
            x = 1:InputCollect$rollingWindowLength,
            decay_accumulated = adstock_weibull(
              1:InputCollect$rollingWindowLength,
              shape = shapeVec[v1],
              scale = scaleVec[v1],
              type = wb_type
            )$thetaVecCum,
            type = wb_type,
            channel = InputCollect$all_media[v1]
          ) %>%
            mutate(halflife = which.min(abs(.data$decay_accumulated - 0.5)))
          max_non0 <- max(which(dt_weibull$decay_accumulated > 0.001))
          dt_weibull$cut_time <- floor(max_non0 + max_non0 / 3)
          weibullCollect[[n]] <- dt_weibull
          n <- n + 1
        }
        weibullCollect <- bind_rows(weibullCollect)
        weibullCollect <- filter(weibullCollect, .data$x <= max(weibullCollect$cut_time))
      }

      plot3data <- list(
        dt_geometric = dt_geometric,
        weibullCollect = weibullCollect,
        wb_type = toupper(wb_type)
      )

      ## 4. Spend response curve
      dt_transformPlot <- select(dt_mod, .data$ds, all_of(InputCollect$all_media)) # independent variables
      dt_transformSpend <- cbind(dt_transformPlot[, "ds"], InputCollect$dt_input[, c(InputCollect$paid_media_spends)]) # spends of indep vars
      dt_transformSpendMod <- dt_transformPlot[InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich, ]
      # update non-spend variables
      # if (length(InputCollect$exposure_vars) > 0) {
      #   for (expo in InputCollect$exposure_vars) {
      #     sel_nls <- ifelse(InputCollect$modNLSCollect[channel == expo, rsq_nls > rsq_lm], "nls", "lm")
      #     dt_transformSpendMod[, (expo) := InputCollect$yhatNLSCollect[channel == expo & models == sel_nls, yhat]]
      #   }
      # }
      dt_transformAdstock <- dt_transformPlot
      dt_transformSaturation <- dt_transformPlot[
        InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich,
      ]

      m_decayRate <- list()
      for (med in seq_along(InputCollect$all_media)) {
        med_select <- InputCollect$all_media[med]
        m <- dt_transformPlot[, med_select][[1]]
        # Adstocking
        if (InputCollect$adstock == "geometric") {
          theta <- hypParam[paste0(InputCollect$all_media[med], "_thetas")][[1]]
          x_list <- adstock_geometric(x = m, theta = theta)
        } else if (InputCollect$adstock == "weibull_cdf") {
          shape <- hypParam[paste0(InputCollect$all_media[med], "_shapes")][[1]]
          scale <- hypParam[paste0(InputCollect$all_media[med], "_scales")][[1]]
          x_list <- adstock_weibull(x = m, shape = shape, scale = scale, type = "cdf")
        } else if (InputCollect$adstock == "weibull_pdf") {
          shape <- hypParam[paste0(InputCollect$all_media[med], "_shapes")][[1]]
          scale <- hypParam[paste0(InputCollect$all_media[med], "_scales")][[1]]
          x_list <- adstock_weibull(x = m, shape = shape, scale = scale, type = "pdf")
        }
        m_adstocked <- x_list$x_decayed
        dt_transformAdstock[med_select] <- m_adstocked
        m_adstockedRollWind <- m_adstocked[
          InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich
        ]
        ## Saturation
        alpha <- hypParam[paste0(InputCollect$all_media[med], "_alphas")][[1]]
        gamma <- hypParam[paste0(InputCollect$all_media[med], "_gammas")][[1]]
        dt_transformSaturation[med_select] <- saturation_hill(
          x = m_adstockedRollWind, alpha = alpha, gamma = gamma
        )
      }
      dt_transformSaturationDecomp <- dt_transformSaturation
      for (i in 1:InputCollect$mediaVarCount) {
        coef <- plotWaterfallLoop$coef[plotWaterfallLoop$rn == InputCollect$all_media[i]]
        dt_transformSaturationDecomp[InputCollect$all_media[i]] <- coef *
          dt_transformSaturationDecomp[InputCollect$all_media[i]]
      }
      dt_transformSaturationSpendReverse <- dt_transformAdstock[
        InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich,
      ]

      ## Reverse MM fitting
      # dt_transformSaturationSpendReverse <- copy(dt_transformAdstock[, c("ds", InputCollect$all_media), with = FALSE])
      # for (i in 1:InputCollect$mediaVarCount) {
      #   chn <- InputCollect$paid_media_vars[i]
      #   if (chn %in% InputCollect$paid_media_vars[InputCollect$exposure_selector]) {
      #     # Get Michaelis Menten nls fitting param
      #     get_chn <- dt_transformSaturationSpendReverse[, chn, with = FALSE]
      #     Vmax <- InputCollect$modNLSCollect[channel == chn, Vmax]
      #     Km <- InputCollect$modNLSCollect[channel == chn, Km]
      #     # Reverse exposure to spend
      #     dt_transformSaturationSpendReverse[, (chn) := mic_men(x = .SD, Vmax = Vmax, Km = Km, reverse = TRUE), .SDcols = chn] # .SD * Km / (Vmax - .SD) exposure to spend, reverse Michaelis Menthen: x = y*Km/(Vmax-y)
      #   } else if (chn %in% InputCollect$exposure_vars) {
      #     coef_lm <- InputCollect$modNLSCollect[channel == chn, coef_lm]
      #     dt_transformSaturationSpendReverse[, (chn) := .SD / coef_lm, .SDcols = chn]
      #   }
      # }
      # dt_transformSaturationSpendReverse <- dt_transformSaturationSpendReverse[InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich]

      dt_scurvePlot <- tidyr::gather(
        dt_transformSaturationDecomp, "channel", "response",
        2:ncol(dt_transformSaturationDecomp)
      ) %>%
        mutate(spend = tidyr::gather(
          dt_transformSaturationSpendReverse, "channel", "spend",
          2:ncol(dt_transformSaturationSpendReverse)
        )$spend)

      # Remove outlier introduced by MM nls fitting
      dt_scurvePlot <- dt_scurvePlot[dt_scurvePlot$spend >= 0, ]

      dt_scurvePlotMean <- dt_transformSpend %>%
        slice(InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich) %>%
        select(-.data$ds) %>%
        dplyr::summarise_all(function(x) ifelse(is.na(mean(x[x > 0])), 0, mean(x[x > 0]))) %>%
        tidyr::gather("channel", "mean_spend") %>%
        mutate(mean_spend_scaled = 0, mean_response = 0, next_unit_response = 0)

      for (med in 1:InputCollect$mediaVarCount) {
        get_med <- InputCollect$paid_media_spends[med]
        get_spend_mm <- get_spend <- dt_scurvePlotMean$mean_spend[dt_scurvePlotMean$channel == get_med]
        m <- dt_transformAdstock[[get_med]][
          InputCollect$rollingWindowStartWhich:InputCollect$rollingWindowEndWhich
        ]
        # m <- m[m > 0] # remove outlier introduced by MM nls fitting
        alpha <- hypParam[which(paste0(get_med, "_alphas") == names(hypParam))][[1]]
        gamma <- hypParam[which(paste0(get_med, "_gammas") == names(hypParam))][[1]]
        get_response <- saturation_hill(x = m, alpha = alpha, gamma = gamma, x_marginal = get_spend_mm)
        get_response_marginal <- saturation_hill(x = m, alpha = alpha, gamma = gamma, x_marginal = get_spend_mm + 1)

        coef <- plotWaterfallLoop$coef[plotWaterfallLoop$rn == get_med]
        dt_scurvePlotMean$mean_spend_scaled[
          dt_scurvePlotMean$channel == get_med
        ] <- get_spend_mm
        dt_scurvePlotMean$mean_response[
          dt_scurvePlotMean$channel == get_med
        ] <- get_response * coef
        dt_scurvePlotMean$next_unit_response[
          dt_scurvePlotMean$channel == get_med
        ] <- get_response_marginal * coef - (get_response * coef)
      }
      dt_scurvePlotMean$solID <- sid

      # Exposure response curve
      plot4data <- list(
        dt_scurvePlot = dt_scurvePlot,
        dt_scurvePlotMean = dt_scurvePlotMean
      )

      ## 5. Fitted vs actual
      col_order <- c("ds", "dep_var", InputCollect$all_ind_vars)
      dt_transformDecomp <- select(
        dt_modRollWind, .data$ds, .data$dep_var,
        any_of(c(InputCollect$prophet_vars, InputCollect$context_vars))
      ) %>%
        bind_cols(select(dt_transformSaturation, all_of(InputCollect$all_media))) %>%
        select(all_of(col_order))
      xDecompVec <- xDecompAgg %>%
        filter(.data$solID == sid) %>%
        select(.data$solID, .data$rn, .data$coef) %>%
        tidyr::spread(.data$rn, .data$coef)
      if (!("(Intercept)" %in% names(xDecompVec))) xDecompVec[["(Intercept)"]] <- 0
      xDecompVec <- select(xDecompVec, c("solID", "(Intercept)", col_order[!(col_order %in% c("ds", "dep_var"))]))
      intercept <- xDecompVec$`(Intercept)`
      xDecompVec <- data.frame(mapply(
        function(scurved, coefs) scurved * coefs,
        scurved = select(dt_transformDecomp, -.data$ds, -.data$dep_var),
        coefs = select(xDecompVec, -.data$solID, -.data$`(Intercept)`)
      ))
      xDecompVec <- mutate(xDecompVec,
        intercept = intercept,
        depVarHat = rowSums(xDecompVec) + intercept, solID = sid
      )
      xDecompVec <- bind_cols(select(dt_transformDecomp, .data$ds, .data$dep_var), xDecompVec)
      xDecompVecPlot <- select(xDecompVec, .data$ds, .data$dep_var, .data$depVarHat) %>%
        rename("actual" = "dep_var", "predicted" = "depVarHat")
      xDecompVecPlotMelted <- tidyr::gather(
        xDecompVecPlot,
        key = "variable", value = "value", -.data$ds
      )
      rsq <- filter(xDecompAgg, .data$solID == sid) %>%
        pull(.data$rsq_train) %>%
        .[1]
      plot5data <- list(xDecompVecPlotMelted = xDecompVecPlotMelted, rsq = rsq)

      ## 6. Diagnostic: fitted vs residual
      plot6data <- list(xDecompVecPlot = xDecompVecPlot)

      ## 7. Immediate vs carryover response
      temp <- filter(xDecompVecImmCarr, .data$solID == sid)
      vec_collect <- list(
        xDecompVec = select(temp, -dplyr::ends_with("_MDI"), -dplyr::ends_with("_MDC")),
        xDecompVecImmediate = select(temp, -dplyr::ends_with("_MDC"), -all_of(InputCollect$all_media)),
        xDecompVecCarryover = select(temp, -dplyr::ends_with("_MDI"), -all_of(InputCollect$all_media))
      )
      this <- gsub("_MDI", "", colnames(vec_collect$xDecompVecImmediate))
      colnames(vec_collect$xDecompVecImmediate) <- colnames(vec_collect$xDecompVecCarryover) <- this
      df_caov <- vec_collect$xDecompVecCarryover %>%
        group_by(.data$solID) %>%
        summarise(across(InputCollect$all_media, sum))
      df_total <- vec_collect$xDecompVec %>%
        group_by(.data$solID) %>%
        summarise(across(InputCollect$all_media, sum))
      df_caov_pct <- bind_cols(
        select(df_caov, .data$solID),
        select(df_caov, -.data$solID) / select(df_total, -.data$solID)
      ) %>%
        pivot_longer(cols = InputCollect$all_media, names_to = "rn", values_to = "carryover_pct")
      df_caov_pct[is.na(as.matrix(df_caov_pct))] <- 0
      df_caov_pct_all <- bind_rows(df_caov_pct_all, df_caov_pct)
      # Gather everything in an aggregated format
      xDecompVecImmeCaov <- bind_rows(
        select(vec_collect$xDecompVecImmediate, c("ds", InputCollect$all_media, "solID")) %>%
          mutate(type = "Immediate"),
        select(vec_collect$xDecompVecCarryover, c("ds", InputCollect$all_media, "solID")) %>%
          mutate(type = "Carryover")
      ) %>%
        pivot_longer(cols = InputCollect$all_media, names_to = "rn") %>%
        select(c("solID", "type", "rn", "value")) %>%
        group_by(.data$solID, .data$rn, .data$type) %>%
        summarise(response = sum(.data$value), .groups = "drop_last") %>%
        mutate(percentage = .data$response / sum(.data$response)) %>%
        replace(., is.na(.), 0) %>%
        left_join(df_caov_pct, c("solID", "rn"))
      if (length(unique(xDecompAgg$solID)) == 1) {
        xDecompVecImmeCaov$solID <- OutModels$trial1$resultCollect$resultHypParam$solID
      }
      plot7data <- xDecompVecImmeCaov

      ## 8. Bootstrapped ROI/CPA with CIs
      # plot8data <- "Empty" # Filled when running robyn_onepagers() with clustering data

      # Gather all results
      mediaVecCollect <- bind_rows(mediaVecCollect, list(
        mutate(dt_transformPlot, type = "rawMedia", solID = sid),
        mutate(dt_transformSpend, type = "rawSpend", solID = sid),
        mutate(dt_transformSpendMod, type = "predictedExposure", solID = sid),
        mutate(dt_transformAdstock, type = "adstockedMedia", solID = sid),
        mutate(dt_transformSaturation, type = "saturatedMedia", solID = sid),
        mutate(dt_transformSaturationSpendReverse, type = "saturatedSpendReversed", solID = sid),
        mutate(dt_transformSaturationDecomp, type = "decompMedia", solID = sid)
      ))
      xDecompVecCollect <- bind_rows(xDecompVecCollect, xDecompVec)
      meanResponseCollect <- bind_rows(meanResponseCollect, dt_scurvePlotMean)
      plotDataCollect[[sid]] <- list(
        plot1data = plot1data,
        plot2data = plot2data,
        plot3data = plot3data,
        plot4data = plot4data,
        plot5data = plot5data,
        plot6data = plot6data,
        plot7data = plot7data
        # plot8data = plot8data
      )
    }
  } # end pareto front loop

  meanResponseCollect <- rename(meanResponseCollect, "rn" = "channel")
  xDecompAgg <- left_join(xDecompAgg, select(
    meanResponseCollect, .data$rn, .data$solID, .data$mean_response, .data$next_unit_response
  ),
  by = c("rn", "solID")
  )

  pareto_results <- list(
    pareto_solutions = unique(xDecompVecCollect$solID),
    pareto_fronts = pareto_fronts,
    resultHypParam = resultHypParam,
    xDecompAgg = xDecompAgg,
    resultCalibration = resultCalibration,
    mediaVecCollect = mediaVecCollect,
    xDecompVecCollect = xDecompVecCollect,
    plotDataCollect = plotDataCollect,
    df_caov_pct_all = df_caov_pct_all
  )

  # if (check_parallel()) stopImplicitCluster()
  # close(pbplot)

  return(pareto_results)
}
