library(dplyr)
library(lubridate)
library(readr)


args <- commandArgs(trailingOnly = TRUE)

# The forecast_date is the date of forecast creation.
forecast_date <- args[1]

base_path <- "weekly-submission/sarix-forecasts"

target_var <- "hosps"
target_by_loc_path <- file.path(base_path, paste0(target_var, "-by-loc"))
models <- list.dirs(
    target_by_loc_path,
    full.names = FALSE,
    recursive = FALSE)

for (model in models) {
    files <- list.files(file.path(target_by_loc_path, model))
    date_files <- files[grep(forecast_date, files)]
    date_forecasts <- purrr::map_dfr(
        date_files,
        function(date_file) {
            readr::read_csv(
                file.path(target_by_loc_path, model, date_file),
                col_types = cols(
                    location = col_character(),
                    forecast_date = col_character(),
                    target_end_date = col_character(),
                    target = col_character(),
                    type = col_character(),
                    quantile = col_double(),
                    value = col_double()
                )
            )
        }
    )
    if (nrow(date_forecasts) > 0) {
        save_dir <- file.path(base_path, target_var, model)
        if (!dir.exists(save_dir)) {
            dir.create(save_dir, recursive = TRUE)
        }
        if (!file.exists(file.path(save_dir, paste0(forecast_date, "-", model, ".csv")))) {
            readr::write_csv(
                date_forecasts,
                file.path(save_dir, paste0(forecast_date, "-", model, ".csv"))
            )
        }
    }
}

unlink(target_by_loc_path, recursive = TRUE)
