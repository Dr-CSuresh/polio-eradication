# 05_sustained_zero_and_recurrence.R
#
# Project: Polio Eradication



# 1. Load packages 

library(tidyverse)
library(here)
library(survival)


# 2. Create output directories if required 

if (!dir.exists(here("plots"))) {
  dir.create(
    here("plots"),
    recursive = TRUE
  )
}

if (!dir.exists(here("tables"))) {
  dir.create(
    here("tables"),
    recursive = TRUE
  )
}


# IMPORT DATA



# 3. Import country-level polio data

polio_country <- read_csv(
  here(
    "data",
    "processed",
    "polio_country.csv"
  ),
  show_col_types = FALSE
)


# PREPARE COMPLETE COUNTRY-YEAR SERIES



# 4. Complete missing calendar years within each country's observation period
#
# Missing years remain missing and are not treated as zero.

polio_complete <- polio_country |>
  group_by(
    entity,
    code
  ) |>
  complete(
    year = full_seq(
      year,
      period = 1
    )
  ) |>
  arrange(
    year,
    .by_group = TRUE
  ) |>
  mutate(
    
    case_state =
      case_when(
        
        is.na(estimated_cases) ~
          "missing",
        
        estimated_cases == 0 ~
          "zero",
        
        estimated_cases > 0 ~
          "positive"
      )
  ) |>
  ungroup()


# DEFINE ANALYSIS POPULATION



# 5. Identify countries with at least one positive estimated case

country_origins <- polio_country |>
  filter(
    estimated_cases > 0
  ) |>
  arrange(
    entity,
    year
  ) |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    first_positive_year =
      first(year),
    
    baseline_cases =
      first(estimated_cases),
    
    .groups = "drop"
  )


# 6. Identify final observed year for each country

country_followup <- polio_country |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    last_observed_year =
      max(year),
    
    .groups = "drop"
  )


country_origins <- country_origins |>
  left_join(
    country_followup,
    by = c(
      "entity",
      "code"
    )
  )


# FUNCTION FOR SUSTAINED ZERO



# 7. Create function to derive sustained-zero events

derive_sustained_zero <- function(threshold) {
  
  zero_runs <- polio_complete |>
    inner_join(
      country_origins,
      by = c(
        "entity",
        "code"
      )
    ) |>
    filter(
      year >= first_positive_year
    ) |>
    group_by(
      entity,
      code
    ) |>
    arrange(
      year,
      .by_group = TRUE
    ) |>
    mutate(
      
      run_id =
        cumsum(
          case_state != lag(
            case_state,
            default = ""
          )
        )
    ) |>
    ungroup() |>
    group_by(
      entity,
      code,
      first_positive_year,
      baseline_cases,
      last_observed_year,
      run_id,
      case_state
    ) |>
    summarise(
      
      run_start_year =
        min(year),
      
      run_end_year =
        max(year),
      
      run_length =
        n(),
      
      .groups = "drop"
    )
  
  
  sustained_events <- zero_runs |>
    filter(
      case_state == "zero",
      run_length >= threshold
    ) |>
    group_by(
      entity,
      code
    ) |>
    slice_min(
      order_by = run_start_year,
      n = 1,
      with_ties = FALSE
    ) |>
    ungroup() |>
    transmute(
      
      entity,
      code,
      
      sustained_zero_start_year =
        run_start_year,
      
      sustained_zero_confirmed_year =
        run_start_year +
        threshold -
        1
    )
  
  
  country_origins |>
    left_join(
      sustained_events,
      by = c(
        "entity",
        "code"
      )
    ) |>
    mutate(
      
      zero_threshold =
        threshold,
      
      event =
        !is.na(
          sustained_zero_confirmed_year
        ),
      
      follow_up_end =
        if_else(
          event,
          sustained_zero_confirmed_year,
          last_observed_year
        ),
      
      time_to_event =
        follow_up_end -
        first_positive_year
    )
}


# PRIMARY FIVE-YEAR DEFINITION



# 8. Derive five-year sustained-zero endpoint

sustained_zero_5 <- derive_sustained_zero(
  5
)


sustained_zero_5


# 9. Summarise primary endpoint

sustained_zero_summary <- sustained_zero_5 |>
  summarise(
    
    n_countries =
      n(),
    
    n_reached_sustained_zero =
      sum(event),
    
    percent_reached_sustained_zero =
      100 *
      mean(event),
    
    n_right_censored =
      sum(
        !event
      ),
    
    median_time_to_sustained_zero =
      median(
        time_to_event[event],
        na.rm = TRUE
      )
  )


sustained_zero_summary


# KAPLAN-MEIER ANALYSIS



# 10. Fit Kaplan-Meier time-to-event model

km_model <- survfit(
  Surv(
    time_to_event,
    event
  ) ~ 1,
  data = sustained_zero_5
)


summary(
  km_model
)


# 11. Convert Kaplan-Meier output to table

km_summary <- summary(
  km_model
)


km_table <- tibble(
  
  time =
    km_summary$time,
  
  survival =
    km_summary$surv,
  
  lower =
    km_summary$lower,
  
  upper =
    km_summary$upper
) |>
  mutate(
    
    cumulative_sustained_zero =
      100 *
      (
        1 -
          survival
      ),
    
    cumulative_lower =
      100 *
      (
        1 -
          upper
      ),
    
    cumulative_upper =
      100 *
      (
        1 -
          lower
      )
  )


km_table


# 12. Plot cumulative probability of sustained zero

plot_km <- km_table |>
  ggplot(
    aes(
      x = time,
      y = cumulative_sustained_zero
    )
  ) +
  geom_step(
    linewidth = 0.9
  ) +
  geom_ribbon(
    aes(
      ymin = cumulative_lower,
      ymax = cumulative_upper
    ),
    alpha = 0.2
  ) +
  scale_y_continuous(
    limits = c(
      0,
      100
    )
  ) +
  labs(
    title = "Time to sustained zero estimated polio cases",
    subtitle = "Kaplan-Meier analysis using five consecutive zero-case years",
    x = "Years since first positive estimated case",
    y = "Cumulative probability of sustained zero (%)",
    caption = "Countries not reaching the endpoint by their final observed year are right-censored."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_km


ggsave(
  here(
    "plots",
    "08_time_to_sustained_zero.png"
  ),
  plot_km,
  width = 10,
  height = 6,
  dpi = 300
)


# BASELINE BURDEN GROUPS



# 13. Divide countries into baseline burden groups

sustained_zero_5 <- sustained_zero_5 |>
  mutate(
    
    baseline_burden_group =
      ntile(
        baseline_cases,
        3
      ),
    
    baseline_burden_group =
      factor(
        baseline_burden_group,
        levels = c(
          1,
          2,
          3
        ),
        labels = c(
          "Lower baseline burden",
          "Middle baseline burden",
          "Higher baseline burden"
        )
      )
  )


# 14. Fit Kaplan-Meier model by baseline burden group

km_baseline_model <- survfit(
  Surv(
    time_to_event,
    event
  ) ~ baseline_burden_group,
  data = sustained_zero_5
)


km_baseline_model


# LOG-RANK TEST



# 15. Compare time-to-event distributions between burden groups

logrank_test <- survdiff(
  Surv(
    time_to_event,
    event
  ) ~ baseline_burden_group,
  data = sustained_zero_5
)


logrank_test


logrank_results <- tibble(
  
  test =
    "Log-rank test",
  
  chi_square =
    logrank_test$chisq,
  
  degrees_freedom =
    length(
      logrank_test$n
    ) -
    1,
  
  p_value =
    pchisq(
      logrank_test$chisq,
      df =
        length(
          logrank_test$n
        ) -
        1,
      lower.tail = FALSE
    )
)


logrank_results


# COX PROPORTIONAL HAZARDS MODEL



# 16. Create log2 baseline burden variable

sustained_zero_5 <- sustained_zero_5 |>
  mutate(
    
    log2_baseline_cases =
      log2(
        baseline_cases + 1
      )
  )


# 17. Fit Cox proportional hazards model

cox_model <- coxph(
  Surv(
    time_to_event,
    event
  ) ~ log2_baseline_cases,
  data = sustained_zero_5
)


summary(
  cox_model
)


# 18. Extract Cox model results

cox_model_summary <- summary(
  cox_model
)


cox_confidence <- confint(
  cox_model
)


cox_results <- tibble(
  
  predictor =
    "Doubling of baseline estimated cases",
  
  coefficient =
    coef(
      cox_model
    )[["log2_baseline_cases"]],
  
  hazard_ratio =
    exp(
      coef(
        cox_model
      )[["log2_baseline_cases"]]
    ),
  
  lower_95_ci =
    exp(
      cox_confidence[
        "log2_baseline_cases",
        1
      ]
    ),
  
  upper_95_ci =
    exp(
      cox_confidence[
        "log2_baseline_cases",
        2
      ]
    ),
  
  p_value =
    cox_model_summary$coefficients[
      "log2_baseline_cases",
      "Pr(>|z|)"
    ]
)


cox_results


# PROPORTIONAL HAZARDS ASSUMPTION



# 19. Test proportional hazards assumption

ph_test <- cox.zph(
  cox_model
)


ph_test


ph_results <- as.data.frame(
  ph_test$table
) |>
  rownames_to_column(
    "term"
  ) |>
  as_tibble() |>
  rename(
    p_value = p
  )


ph_results


# ACCELERATED FAILURE-TIME MODELS



# 20. Fit Weibull AFT model

aft_weibull <- survreg(
  Surv(
    time_to_event,
    event
  ) ~ log2_baseline_cases,
  data = sustained_zero_5,
  dist = "weibull"
)


# 21. Fit log-normal AFT model

aft_lognormal <- survreg(
  Surv(
    time_to_event,
    event
  ) ~ log2_baseline_cases,
  data = sustained_zero_5,
  dist = "lognormal"
)


# 22. Fit log-logistic AFT model

aft_loglogistic <- survreg(
  Surv(
    time_to_event,
    event
  ) ~ log2_baseline_cases,
  data = sustained_zero_5,
  dist = "loglogistic"
)


# 23. Fit exponential AFT model

aft_exponential <- survreg(
  Surv(
    time_to_event,
    event
  ) ~ log2_baseline_cases,
  data = sustained_zero_5,
  dist = "exponential"
)


# MODEL COMPARISON



# 24. Compare AFT models using AIC

aft_model_comparison <- tibble(
  
  model = c(
    "Weibull",
    "Log-normal",
    "Log-logistic",
    "Exponential"
  ),
  
  AIC = c(
    AIC(aft_weibull),
    AIC(aft_lognormal),
    AIC(aft_loglogistic),
    AIC(aft_exponential)
  )
) |>
  arrange(AIC)


aft_model_comparison


# 25. Select model with lowest AIC

best_aft_model_name <- aft_model_comparison |>
  slice_min(
    order_by = AIC,
    n = 1,
    with_ties = FALSE
  ) |>
  pull(model)


best_aft_model_name


# 26. Extract selected AFT model

best_aft_model <- switch(
  
  best_aft_model_name,
  
  "Weibull" =
    aft_weibull,
  
  "Log-normal" =
    aft_lognormal,
  
  "Log-logistic" =
    aft_loglogistic,
  
  "Exponential" =
    aft_exponential
)


summary(
  best_aft_model
)


# 27. Calculate AFT time ratio

aft_coefficient <- coef(
  best_aft_model
)[["log2_baseline_cases"]]


aft_standard_error <- summary(
  best_aft_model
)$table[
  "log2_baseline_cases",
  "Std. Error"
]


aft_z <- summary(
  best_aft_model
)$table[
  "log2_baseline_cases",
  "z"
]


aft_p_value <- summary(
  best_aft_model
)$table[
  "log2_baseline_cases",
  "p"
]


aft_lower <- aft_coefficient -
  1.96 *
  aft_standard_error


aft_upper <- aft_coefficient +
  1.96 *
  aft_standard_error


aft_results <- tibble(
  
  model =
    best_aft_model_name,
  
  predictor =
    "Doubling of baseline estimated cases",
  
  coefficient =
    aft_coefficient,
  
  time_ratio =
    exp(
      aft_coefficient
    ),
  
  lower_95_ci =
    exp(
      aft_lower
    ),
  
  upper_95_ci =
    exp(
      aft_upper
    ),
  
  z_statistic =
    aft_z,
  
  p_value =
    aft_p_value
)


aft_results


# SENSITIVITY ANALYSIS



# 28. Compare 3-, 5- and 10-year sustained-zero definitions

sensitivity_data <- map_dfr(
  c(
    3,
    5,
    10
  ),
  derive_sustained_zero
)


sensitivity_summary <- sensitivity_data |>
  group_by(
    zero_threshold
  ) |>
  summarise(
    
    n_countries =
      n(),
    
    n_events =
      sum(event),
    
    percent_reaching_endpoint =
      100 *
      mean(event),
    
    n_right_censored =
      sum(
        !event
      ),
    
    median_time_to_event =
      median(
        time_to_event[event],
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )


sensitivity_summary


# RECURRENCE AFTER SUSTAINED ZERO



# 29. Identify countries reaching five-year sustained zero

recurrence_candidates <- sustained_zero_5 |>
  filter(
    event
  ) |>
  select(
    entity,
    code,
    sustained_zero_start_year,
    sustained_zero_confirmed_year
  )


# 30. Create recurrence follow-up dataset

recurrence_followup <- recurrence_candidates |>
  left_join(
    polio_complete |>
      select(
        entity,
        code,
        year,
        estimated_cases
      ),
    by = c(
      "entity",
      "code"
    )
  ) |>
  filter(
    year >
      sustained_zero_confirmed_year,
    !is.na(
      estimated_cases
    )
  ) |>
  group_by(
    entity,
    code,
    sustained_zero_start_year,
    sustained_zero_confirmed_year
  ) |>
  summarise(
    
    last_post_endpoint_year =
      max(year),
    
    post_endpoint_followup_years =
      n(),
    
    recurrence =
      any(
        estimated_cases > 0
      ),
    
    first_recurrence_year =
      if (
        any(
          estimated_cases > 0
        )
      ) {
        
        min(
          year[
            estimated_cases > 0
          ]
        )
        
      } else {
        
        NA_real_
      },
    
    .groups = "drop"
  ) |>
  mutate(
    
    recurrence_followup_time =
      if_else(
        recurrence,
        
        first_recurrence_year -
          sustained_zero_confirmed_year,
        
        last_post_endpoint_year -
          sustained_zero_confirmed_year
      )
  )


recurrence_followup


# 31. Summarise recurrence

recurrence_summary <- recurrence_followup |>
  summarise(
    
    countries_with_post_endpoint_followup =
      n(),
    
    countries_with_recurrence =
      sum(
        recurrence
      ),
    
    countries_without_recurrence =
      sum(
        !recurrence
      ),
    
    percent_with_recurrence =
      100 *
      mean(
        recurrence
      ),
    
    median_time_to_recurrence =
      median(
        recurrence_followup_time[
          recurrence
        ],
        na.rm = TRUE
      )
  )


recurrence_summary


# 32. List countries with recurrence

recurrence_countries <- recurrence_followup |>
  filter(
    recurrence
  ) |>
  arrange(
    first_recurrence_year
  )


print(
  recurrence_countries,
  n = Inf
)


# RECURRENCE SURVIVAL ANALYSIS



# 33. Fit recurrence-free Kaplan-Meier model

recurrence_km <- survfit(
  Surv(
    recurrence_followup_time,
    recurrence
  ) ~ 1,
  data = recurrence_followup
)


summary(
  recurrence_km
)


# 34. Convert recurrence model to table

recurrence_km_summary <- summary(
  recurrence_km
)


recurrence_km_table <- tibble(
  
  time =
    recurrence_km_summary$time,
  
  recurrence_free_probability =
    recurrence_km_summary$surv,
  
  lower =
    recurrence_km_summary$lower,
  
  upper =
    recurrence_km_summary$upper
)


recurrence_km_table


# 35. Plot recurrence-free probability

plot_recurrence <- recurrence_km_table |>
  ggplot(
    aes(
      x = time,
      y = recurrence_free_probability * 100
    )
  ) +
  geom_step(
    linewidth = 0.9
  ) +
  geom_ribbon(
    aes(
      ymin = lower * 100,
      ymax = upper * 100
    ),
    alpha = 0.2
  ) +
  scale_y_continuous(
    limits = c(
      0,
      100
    )
  ) +
  labs(
    title = "Recurrence after sustained zero estimated polio cases",
    subtitle = "Kaplan-Meier recurrence-free probability after the five-year sustained-zero endpoint",
    x = "Years since sustained-zero confirmation",
    y = "Recurrence-free probability (%)",
    caption = "Countries without recurrence are censored at their final observed year."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_recurrence


ggsave(
  here(
    "plots",
    "09_recurrence_after_sustained_zero.png"
  ),
  plot_recurrence,
  width = 10,
  height = 6,
  dpi = 300
)


# SAVE OUTPUTS



write_csv(
  sustained_zero_5,
  here(
    "data",
    "processed",
    "polio_sustained_zero_5year.csv"
  )
)


write_csv(
  sustained_zero_summary,
  here(
    "tables",
    "polio_sustained_zero_summary.csv"
  )
)


write_csv(
  km_table,
  here(
    "tables",
    "polio_kaplan_meier.csv"
  )
)


write_csv(
  logrank_results,
  here(
    "tables",
    "polio_logrank_test.csv"
  )
)


write_csv(
  cox_results,
  here(
    "tables",
    "polio_cox_model.csv"
  )
)


write_csv(
  ph_results,
  here(
    "tables",
    "polio_proportional_hazards_test.csv"
  )
)


write_csv(
  aft_model_comparison,
  here(
    "tables",
    "polio_aft_model_comparison.csv"
  )
)


write_csv(
  aft_results,
  here(
    "tables",
    "polio_aft_results.csv"
  )
)


write_csv(
  sensitivity_summary,
  here(
    "tables",
    "polio_sustained_zero_sensitivity.csv"
  )
)


write_csv(
  recurrence_followup,
  here(
    "tables",
    "polio_recurrence_followup.csv"
  )
)


write_csv(
  recurrence_summary,
  here(
    "tables",
    "polio_recurrence_summary.csv"
  )
)


write_csv(
  recurrence_countries,
  here(
    "tables",
    "polio_recurrence_countries.csv"
  )
)


write_csv(
  recurrence_km_table,
  here(
    "tables",
    "polio_recurrence_kaplan_meier.csv"
  )
)



message(
  "Polio sustained-zero, survival and recurrence analysis complete."
)
