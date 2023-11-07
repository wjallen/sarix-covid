# current date
TODAY_DATE = $(shell date +'%Y-%m-%d')

sarix: cache-data fit-sarix-components combine-by-location build-sarix-ensemble plot-sarix

cache-data:
	Rscript code/cache_data.R

fit-sarix-components:
	python3 code/run_all_models_one_date_by_loc.py --forecast_date $(TODAY_DATE)

combine-by-location:
	Rscript code/combine_forecasts_by_location.R

build-sarix-ensemble:
	Rscript code/build_sarix_ensemble.R

plot-sarix:
	Rscript code/plot_sarix_forecasts.R

