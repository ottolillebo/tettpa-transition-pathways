suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(forcats)
  library(ggplot2)
  library(scales)
})

output_dir <- Sys.getenv("TETTPA_OUTPUT_DIR", "outputs")
table_dir <- file.path(output_dir, "tables")
figure_dir <- file.path(output_dir, "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

blue <- "#0072B2"
blue_dark <- "#005A8D"

article_theme <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.caption = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "grey88", linewidth = 0.35),
      panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
      legend.position = "none"
    )
}

save_png <- function(plot, filename, width, height) {
  ggsave(
    file.path(figure_dir, filename),
    plot,
    width = width,
    height = height,
    dpi = 400,
    bg = "white"
  )
}

pathway_summary_12m <- read_csv(file.path(table_dir, "observed_pathways_12m.csv"), show_col_types = FALSE)

p_pathways <- pathway_summary_12m |>
  mutate(
    observed_pathway = factor(
      observed_pathway,
      levels = c(
        "No later PPT case registered",
        "Other later PPT case, no expert assessment",
        "Expert assessment registered"
      )
    ),
    label = sprintf("%.1f%%  (n = %s)", percent, comma(n)),
    label_weight = if_else(observed_pathway == "Expert assessment registered", "bold", "plain")
  ) |>
  ggplot(aes(percent, fct_rev(observed_pathway))) +
  geom_col(width = 0.62, fill = "grey80") +
  geom_col(
    data = ~ filter(.x, observed_pathway == "Expert assessment registered"),
    width = 0.62,
    fill = blue
  ) +
  geom_text(aes(label = label, fontface = label_weight), hjust = -0.08, size = 3.6) +
  scale_x_continuous(
    labels = label_percent(scale = 1, accuracy = 1),
    limits = c(0, 90),
    breaks = seq(0, 80, 20),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    x = "Share of children (n = 905)",
    y = NULL
  ) +
  article_theme() +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 10),
    plot.margin = margin(6, 14, 6, 6)
  )

save_png(p_pathways, "figure2_observed_pathways_12m.png", width = 8, height = 4.2)
save_png(p_pathways, "figure2a_observed_pathways.png", width = 8, height = 4.2)

km_plot_data <- read_csv(file.path(table_dir, "km_plot_data.csv"), show_col_types = FALSE)
km_table <- read_csv(file.path(table_dir, "km_transition_times.csv"), show_col_types = FALSE)

risk_axis <- tibble(
  month = c(0, 6, 12, 18, 24),
  n_risk = c(1468, km_table$n_risk)
)

km_label_data <- km_table |>
  mutate(
    label = percent(cumulative_transition, accuracy = 0.1),
    label_x = months,
    label_y = cumulative_transition + case_when(
      months <= 6 ~ 0.022,
      months <= 12 ~ 0.024,
      months <= 18 ~ 0.022,
      TRUE ~ 0.021
    ),
    hjust = if_else(months >= 24, 1, 0.5)
  )

p_km <- ggplot(km_plot_data, aes(time / 30.4375, estimate)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = blue, alpha = 0.14) +
  geom_segment(
    data = km_table,
    aes(x = months, xend = months, y = 0, yend = cumulative_transition),
    inherit.aes = FALSE,
    linewidth = 0.35,
    linetype = "dotted",
    color = "grey75"
  ) +
  geom_step(color = blue, linewidth = 1) +
  geom_point(
    data = km_table,
    aes(months, cumulative_transition),
    inherit.aes = FALSE,
    color = blue,
    size = 2
  ) +
  geom_label(
    data = km_label_data,
    aes(label_x, label_y, label = label, hjust = hjust),
    inherit.aes = FALSE,
    linewidth = 0,
    label.padding = grid::unit(0.08, "lines"),
    size = 3.3,
    fontface = "bold",
    fill = "white",
    alpha = 0.92,
    color = blue_dark
  ) +
  annotate(
    "text",
    x = risk_axis$month,
    y = -0.055,
    label = comma(risk_axis$n_risk),
    size = 3,
    color = "grey40"
  ) +
  annotate("text", x = -1.05, y = -0.055, label = "At risk", hjust = 1, size = 3, color = "grey40") +
  coord_cartesian(xlim = c(0, 24.7), ylim = c(0, 0.32), clip = "off") +
  scale_x_continuous(breaks = risk_axis$month, labels = risk_axis$month) +
  scale_y_continuous(labels = label_percent(accuracy = 1), breaks = seq(0, 0.30, 0.05)) +
  labs(
    x = "Months since first early-intervention case",
    y = "Cumulative transition probability"
  ) +
  article_theme() +
  theme(
    axis.text.x = element_text(size = 8.5),
    plot.margin = margin(6, 10, 36, 28)
  )

save_png(p_km, "figure3_cumulative_transition.png", width = 8.5, height = 4.8)
save_png(p_km, "figure2b_cumulative_transition.png", width = 8.5, height = 4.8)

message("Rendered Figure 2A and 2B with R to ", normalizePath(figure_dir, winslash = "/", mustWork = TRUE))

km_12m <- km_table$cumulative_transition[km_table$days == 365]

interval_panel <- function(data, x_label, x_limit) {
  data |>
    mutate(
      level_label = paste0(level, "  (n = ", comma(n), ")"),
      estimate_label = percent(estimate, accuracy = 0.1),
      label_x = pmin(pmax(estimate + 0.028, upper + 0.015), x_limit - 0.006),
      label_hjust = if_else(label_x >= x_limit - 0.006, 1, 0)
    ) |>
    ggplot(aes(estimate, reorder(level_label, estimate))) +
    geom_vline(xintercept = km_12m, color = "grey60", linetype = 2) +
    geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.12, orientation = "y", color = "grey35") +
    geom_point(size = 2.2, color = blue) +
    geom_text(
      aes(x = label_x, label = estimate_label, hjust = label_hjust),
      size = 3.1,
      fontface = "bold",
      color = blue_dark
    ) +
    facet_wrap(vars(panel), ncol = 1, scales = "free_y", strip.position = "top") +
    scale_x_continuous(labels = label_percent(accuracy = 1), limits = c(0, x_limit)) +
    labs(x = x_label, y = NULL) +
    article_theme() +
    theme(
      panel.grid.major.y = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0, size = 11),
      strip.background = element_blank(),
      axis.text.y = element_text(size = 9.5),
      plot.margin = margin(6, 16, 6, 6)
    )
}

crude_12m <- read_csv(file.path(table_dir, "crude_12m_transition_probabilities.csv"), show_col_types = FALSE)

crude_figure_data <- crude_12m |>
  filter(variable %in% c("service_tier_main", "presentation_group"), !is.na(estimate)) |>
  mutate(
    panel = recode(
      variable,
      service_tier_main = "Derived service tier",
      presentation_group = "Presenting concern"
    ),
    panel = factor(panel, levels = c("Presenting concern", "Derived service tier"))
  )

p_crude <- interval_panel(
  crude_figure_data,
  x_label = "Unadjusted 12-month transition probability",
  x_limit = 0.68
)

save_png(p_crude, "figure4_crude_12m_probabilities.png", width = 8.5, height = 7.5)
save_png(p_crude, "figure3_unadjusted_probabilities.png", width = 8.5, height = 7.5)

standardized_12m <- read_csv(file.path(table_dir, "standardized_12m_probabilities.csv"), show_col_types = FALSE)

group_counts <- bind_rows(
  crude_12m |>
    filter(variable == "presentation_group") |>
    transmute(variable, level, n),
  crude_12m |>
    filter(variable == "tett_pa") |>
    transmute(variable, level, n)
)

adjusted_figure_data <- standardized_12m |>
  filter(variable %in% c("presentation_group", "tett_pa"), level != "Missing") |>
  left_join(group_counts, by = c("variable", "level")) |>
  mutate(
    panel = recode(
      variable,
      presentation_group = "Presenting concern",
      tett_pa = "District context"
    ),
    panel = factor(panel, levels = c("District context", "Presenting concern"))
  )

p_adjusted <- interval_panel(
  adjusted_figure_data,
  x_label = "Adjusted 12-month transition probability",
  x_limit = 0.68
)

save_png(p_adjusted, "figure5_adjusted_12m_probabilities.png", width = 8.5, height = 7.5)
save_png(p_adjusted, "figure3_standardized_probabilities.png", width = 8.5, height = 7.5)
save_png(p_adjusted, "figure4_adjusted_probabilities.png", width = 8.5, height = 7.5)

message("Rendered Figure 3 and 4 with R to ", normalizePath(figure_dir, winslash = "/", mustWork = TRUE))
