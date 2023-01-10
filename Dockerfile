FROM alpine:3.17.1

RUN apk update
RUN apk upgrade
RUN apk add --no-cache bash openssh-client curl git

RUN adduser --uid 1000 --disabled-password stroom

ADD scripts /stroom
RUN chown -R stroom:stroom /stroom
RUN chmod -R 700 /stroom
RUN chmod 500 /stroom/checkin-stroom-config.sh

USER stroom

CMD [ "/stroom/checkin-stroom-config.sh" ]