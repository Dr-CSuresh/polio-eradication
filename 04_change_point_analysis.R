# 04_change_point_analysis.R
#
# Project: Polio Eradication



# 1. Load packages 

library(tidyverse)
library(here)
library(strucchange)


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



# 3. Import annual polio trajectory

annual_trajectory <- read_csv(
  here(
    "data",
    "processed",
    "polio_annual_trajectory.csv"
  ),
  show_col_types = FALSE
)


# PREPARE ANALYSIS DATA



# 4. Prepare log-transformed annual case series

change_point_data <- annual_trajectory |>
  select(
    year,
    total_estimated_cases
  ) |>
  mutate(
    
    log10_cases =
      log10(
        total_estimated_cases + 1
      )
  )


change_point_data


# TEST FOR STRUCTURAL CHANGE


# 5. Test whether the trajectory is statistically stable over time

f_statistics <- Fstats(
  log10_cases ~ year,
  data = change_point_data
)


structural_change_test <- sctest(
  f_statistics
)


structural_change_test


# 6. Save structural change test result

structural_change_results <- tibble(
  
  test =
    structural_change_test$method,
  
  statistic =
    unname(
      structural_change_test$statistic
    ),
  
  p_value =
    structural_change_test$p.value
)


structural_change_results


# BREAKPOINT ANALYSIS



# 7. Estimate possible structural breakpoints
# h = 0.15 requires each segment to contain approximately 15% or more of the total observations.

breakpoint_model <- breakpoints(
  log10_cases ~ year,
  data = change_point_data,
  h = 0.15
)


summary(
  breakpoint_model
)


# MODEL SELECTION



# 8. Compare models using Bayesian Information Criterion

bic_values <- AIC(
  breakpoint_model,
  k = log(
    nrow(
      change_point_data
    )
  )
)


bic_table <- tibble(
  
  n_breakpoints =
    as.integer(
      names(
        bic_values
      )
    ),
  
  BIC =
    as.numeric(
      bic_values
    )
)


bic_table


# 9. Select number of breakpoints with lowest BIC

selected_n_breakpoints <- bic_table |>
  slice_min(
    order_by = BIC,
    n = 1,
    with_ties = FALSE
  ) |>
  pull(
    n_breakpoints
  )


selected_n_breakpoints


# SELECT BREAKPOINT MODEL



# 10. Extract selected breakpoint model

selected_breakpoints <- breakpoints(
  breakpoint_model,
  breaks = selected_n_breakpoints
)


selected_breakpoints


# 11. Extract breakpoint positions

breakpoint_indices <- selected_breakpoints$breakpoints


breakpoint_indices <- breakpoint_indices[
  !is.na(
    breakpoint_indices
  )
]


# 12. Convert breakpoint positions to years

if (
  length(
    breakpoint_indices
  ) > 0
) {
  
  breakpoint_table <- tibble(
    
    breakpoint_number =
      seq_along(
        breakpoint_indices
      ),
    
    break_after_year =
      change_point_data$year[
        breakpoint_indices
      ],
    
    next_segment_start =
      change_point_data$year[
        breakpoint_indices + 1
      ]
  )
  
} else {
  
  breakpoint_table <- tibble(
    
    breakpoint_number =
      integer(),
    
    break_after_year =
      numeric(),
    
    next_segment_start =
      numeric()
  )
}


breakpoint_table


# BREAKPOINT CONFIDENCE INTERVALS



# 13. Estimate confidence intervals for selected breakpoints

if (
  selected_n_breakpoints > 0
) {
  
  breakpoint_confidence_intervals <- confint(
    breakpoint_model,
    breaks = selected_n_breakpoints
  )
  
  print(
    breakpoint_confidence_intervals
  )
}


# CREATE SEGMENTS



# 14. Assign each year to its selected trajectory segment

if (
  selected_n_breakpoints > 0
) {
  
  segment_factor <- breakfactor(
    breakpoint_model,
    breaks = selected_n_breakpoints
  )
  
} else {
  
  segment_factor <- factor(
    rep(
      "segment1",
      nrow(
        change_point_data
      )
    )
  )
}


change_point_data <- change_point_data |>
  mutate(
    segment = segment_factor
  )


change_point_data


# SEGMENT-SPECIFIC TRENDS



# 15. Fit separate log-linear trends within each segment

segment_trends <- change_point_data |>
  group_by(
    segment
  ) |>
  group_modify(
    ~ {
      
      model <- lm(
        log10_cases ~ year,
        data = .x
      )
      
      slope <-
        coef(
          model
        )[["year"]]
      
      tibble(
        
        start_year =
          min(
            .x$year
          ),
        
        end_year =
          max(
            .x$year
          ),
        
        n_years =
          nrow(
            .x
          ),
        
        slope_log10 =
          slope,
        
        annual_percent_change =
          (
            10^slope -
              1
          ) *
          100,
        
        r_squared =
          summary(
            model
          )$r.squared
      )
    }
  ) |>
  ungroup()


segment_trends


# FITTED VALUES



# 16. Generate fitted values for each segment

fitted_segments <- change_point_data |>
  group_by(
    segment
  ) |>
  group_modify(
    ~ {
      
      model <- lm(
        log10_cases ~ year,
        data = .x
      )
      
      .x |>
        mutate(
          
          fitted_log10 =
            predict(
              model
            ),
          
          fitted_cases =
            10^fitted_log10 -
            1
        )
    }
  ) |>
  ungroup()


# PLOT BREAKPOINT MODEL



# 17. Plot observed and fitted trajectory

plot_breakpoints <- fitted_segments |>
  ggplot(
    aes(
      x = year,
      y = total_estimated_cases
    )
  ) +
  geom_line(
    linewidth = 0.7
  ) +
  geom_point(
    size = 1.6
  ) +
  geom_line(
    aes(
      y = fitted_cases,
      group = segment
    ),
    linewidth = 1.1,
    linetype = "dashed"
  ) +
  geom_vline(
    data = breakpoint_table,
    aes(
      xintercept = break_after_year
    ),
    linetype = "dotted"
  ) +
  scale_y_log10() +
  labs(
    title = "Structural changes in the global polio trajectory",
    subtitle = "Breakpoints selected using Bayesian Information Criterion",
    x = "Year",
    y = "Estimated cases (log scale)",
    caption = "Dashed lines represent segment-specific log-linear trends."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_breakpoints


ggsave(
  here(
    "plots",
    "06_polio_change_point_analysis.png"
  ),
  plot_breakpoints,
  width = 10,
  height = 6,
  dpi = 300
)


# BIC PLOT



# 18. Plot BIC across candidate breakpoint models

plot_bic <- bic_table |>
  ggplot(
    aes(
      x = n_breakpoints,
      y = BIC
    )
  ) +
  geom_line() +
  geom_point(
    size = 2
  ) +
  labs(
    title = "Model selection for polio trajectory breakpoints",
    subtitle = "Lower BIC indicates stronger support for the model",
    x = "Number of structural breakpoints",
    y = "Bayesian Information Criterion"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_bic


ggsave(
  here(
    "plots",
    "07_breakpoint_model_selection.png"
  ),
  plot_bic,
  width = 8,
  height = 5,
  dpi = 300
)


# SAVE OUTPUTS



write_csv(
  structural_change_results,
  here(
    "tables",
    "polio_structural_change_test.csv"
  )
)


write_csv(
  bic_table,
  here(
    "tables",
    "polio_breakpoint_bic.csv"
  )
)


write_csv(
  breakpoint_table,
  here(
    "tables",
    "polio_selected_breakpoints.csv"
  )
)


write_csv(
  segment_trends,
  here(
    "tables",
    "polio_segment_trends.csv"
  )
)


write_csv(
  fitted_segments,
  here(
    "data",
    "processed",
    "polio_change_point_fitted.csv"
  )
)



message(
  "Polio change-point analysis complete."
)