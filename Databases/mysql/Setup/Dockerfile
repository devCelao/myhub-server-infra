FROM mysql:8.0

COPY ./01-init-database.sh /scripts/01-init-database.sh

RUN chmod +x /scripts/01-init-database.sh

ENTRYPOINT ["/scripts/01-init-database.sh"]
