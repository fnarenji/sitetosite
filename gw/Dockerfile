FROM alpine:edge

RUN apk add --update strongswan vim iptables zsh
# RUN apk add --update iputils net-tools

ADD . /app
WORKDIR /app

CMD ./startup.sh
