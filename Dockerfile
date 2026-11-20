FROM ghcr.io/nemesis-health/nep-r-base:4.3.3
WORKDIR /delivery
COPY . .
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/2026-10-08"
RUN Rscript -e "renv::restore(prompt = FALSE)"
CMD ["Rscript", "run.R"]
