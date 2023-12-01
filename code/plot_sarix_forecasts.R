library(dplyr)
library(lubridate)
library(readr)
library(tidyr)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)

# The forecast_date is the date of forecast creation.
forecast_date <- args[1]

hosps_path <- "weekly-submission/sarix-forecasts"
plots_path <- file.path("weekly-submission/sarix-plots", forecast_date)
if (!dir.exists(plots_path)) {
  dir.create(plots_path, recursive = TRUE)
}

hosps_truth <- readr::read_csv(paste0("data/jhu_data_cached_", forecast_date, ".csv"))
location_info <- readr::read_csv("data/locations.csv")
truth <- dplyr::bind_rows(
  hosps_truth %>%
    dplyr::transmute(date, location, location_name, value = hosps,
                     target_var = "hosps")
) %>%
  dplyr::filter(date >= "2022-01-01")

model <- "UMass-sarix"
forecasts <- readr::read_csv(
  file.path(hosps_path, model, paste0(forecast_date, "-", model, ".csv"))) %>%
  dplyr::mutate(target_var = "hosps")
forecasts$quantile <- format(forecasts$quantile, digits = 3, nsmall = 3)
point_forecasts <- forecasts %>%
  dplyr::filter(type == "quantile", quantile == "0.500")
interval_forecasts <- dplyr::bind_rows(
  forecasts %>%
    dplyr::filter(quantile %in% c("0.025", "0.975")) %>%
    tidyr::pivot_wider(names_from = "quantile", values_from = "value") %>%
    dplyr::rename("lower" = "0.025", "upper" = "0.975") %>%
    dplyr::mutate(interval_level = "95"),
  forecasts %>%
    dplyr::filter(quantile %in% c("0.250", "0.750")) %>%
    tidyr::pivot_wider(names_from = "quantile", values_from = "value") %>%
    dplyr::rename("lower" = "0.250", "upper" = "0.750") %>%
    dplyr::mutate(interval_level = "50")
) %>%
  dplyr::mutate(interval_level = factor(interval_level, levels = c("95", "50")))

# plot
pdf(file.path(plots_path, paste0(model, ".pdf")), width = 12, height = 8)
for (loc in unique(forecasts$location)) {
  loc_name <- location_info %>%
    dplyr::filter(location == loc) %>%
    dplyr::pull(location_name)
  p <- ggplot() +
    geom_line(
      data = truth %>% filter(location == loc),
      mapping = aes(x = date, y = value)) +
    geom_ribbon(
      data = interval_forecasts %>% filter(location == loc),
      mapping = aes(x = target_end_date, ymin = lower, ymax = upper, fill = interval_level)
    ) +
    geom_line(
      data = point_forecasts %>% filter(location == loc),
      mapping = aes(x = target_end_date, y = value)
    ) +
    facet_wrap( ~ target_var, ncol = 1, scales = "free_y") +
    ggtitle(loc_name)
  print(p)
}
dev.off()

