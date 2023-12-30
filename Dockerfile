FROM alpine:3.19.0

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        bash \
        openssh-client \
        curl \
        git \
        jq

RUN adduser --uid 1000 --disabled-password stroom

ADD scripts /stroom
RUN chown -R stroom:stroom /stroom
RUN chmod -R 700 /stroom
RUN chmod 500 /stroom/sync-stroom-config.sh

USER stroom

CMD [ "/stroom/sync-stroom-config.sh" ]