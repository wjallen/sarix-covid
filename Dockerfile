FROM rocker/tidyverse

#RUN apt update && apt install -y curl gpg
#RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg;
#RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null;
#RUN apt update && apt install -y gh;

RUN Rscript -e "install.packages('here')"
RUN Rscript -e "devtools::install_github('reichlab/covidHubUtils')"
RUN Rscript -e "devtools::install_github('reichlab/covidData')"
RUN Rscript -e "devtools::install_github('reichlab/hubEnsembles')"

RUN apt-get update
RUN apt-get install -y python3-pip
RUN pip3 install numpy pandas scipy

# downgrade numpyro from 0.13.2:
# RUN pip3 install numpyro==0.11.0

# use my fork, which has debug printing. the ADD is a hack ala https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands
# RUN pip3 install git+https://github.com/elray1/sarix.git
# ADD "https://api.github.com/repos/matthewcornell/sarix/commits?per_page=1" latest_commit
# RUN pip3 install git+https://github.com/matthewcornell/sarix.git
# ADD "https://api.github.com/repos/elray1/sarix/commits?per_page=1" latest_commit

# https://stackoverflow.com/questions/35154219/rebuild-docker-image-from-specific-step
ARG REBUILD_ID=unknown
RUN pip3 install git+https://github.com/elray1/sarix.git@debug_freeze

WORKDIR /app

COPY code ./code
COPY data ./data
COPY makefile .
COPY run-sarix.sh .

CMD ["bash", "/app/run-sarix.sh"]
