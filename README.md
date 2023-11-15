
<!-- README.md is generated from README.Rmd. Please edit that file -->

# sarix-covid

<!-- badges: start -->
<!-- badges: end -->

Seasonal Auto-Regressive Integrated models with eXogenous predictors for
forecasting Covid-19 hospitalizations

## setup

1.  Install the following R packages from the CRAN Repository:

``` r
install.packages(c("dplyr", "lubridate", "readr", "ggplot2"))
```

2.  Install the [covidData](https://github.com/reichlab/covidData) R
    package.
3.  Install the
    [hubEnsembles](https://github.com/Infectious-Disease-Modeling-Hubs/hubEnsembles)
    R package.
4.  Install the
    [covidHubUtils](https://github.com/reichlab/covidHubUtils) R
    package.
5.  Install the sarix python module:
    - clone [the sarix repository](https://github.com/elray1/sarix) and
      from within that directory, run `pip3 install -e .`

## workflow

1.  run `make sarix` in root directory
2.  submit forecast submission file from
    `weekly-submission/sarix-forecasts/hosps/UMass-sarix/` to the
    COVID-19 Forecast Hub as a PR.
3.  commit and push the generated CSV file and the PDF of plots from the
    sarix model.
