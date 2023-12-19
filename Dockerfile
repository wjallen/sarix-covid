FROM rocker/r-ver:4.3

# install the `gh` GitHub CLI binary
# RUN apt update && apt install -y curl gpg
# RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg;
# RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null;
# RUN apt update && apt install -y gh;

# install general OS utilities
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    git

# install OS binaries required by R libraries - via rocker-versioned2/scripts/install_tidyverse.sh
RUN apt-get install -y --no-install-recommends \
    libxml2-dev \
    libcairo2-dev \
    libgit2-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libxtst6 \
    libcurl4-openssl-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    unixodbc-dev

# install R libraries from CRAN
RUN Rscript -e "install.packages(c('devtools', 'dplyr', 'ggplot2', 'lubridate', 'readr', 'tidyr'))"

# install R libraries from reichlab
RUN Rscript -e "install.packages('here')"
RUN Rscript -e "devtools::install_github('reichlab/covidHubUtils')"
RUN Rscript -e "devtools::install_github('reichlab/covidData')"
RUN Rscript -e "devtools::install_github('reichlab/hubEnsembles')"

# install required Python libraries
RUN apt-get install -y python3-pip
RUN apt-get update
RUN pip3 install numpy pandas scipy numpyro

# install GDAL. version via https://www.reddit.com/r/django/comments/wbw9rl/comment/ii9anl6/?utm_medium=android_app&utm_source=share&context=3
RUN apt-get install -y libgdal-dev
RUN pip install GDAL==3.2.2.1

WORKDIR /app

# # clone https://github.com/reichlab/container-utils. ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
# ADD "https://api.github.com/repos/reichlab/container-utils/commits?per_page=1" latest_commit
# RUN git clone https://github.com/reichlab/container-utils.git

# the ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
ADD "https://api.github.com/repos/elray1/sarix/commits?per_page=1" latest_commit
RUN pip3 install git+https://github.com/elray1/sarix.git

COPY code ./code
COPY data ./data
COPY makefile .
COPY run-sarix.sh .

CMD ["bash", "/app/run-sarix.sh"]
