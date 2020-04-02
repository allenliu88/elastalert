FROM alpine:3.10 as py-ea
ARG ELASTALERT_VERSION=v0.2.1
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev python3 libffi-dev gcc musl-dev wget curl && \
ln -s /usr/bin/python3 /usr/bin/python && \
# Install pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
python3 get-pip.py && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# see: https://github.com/Yelp/elastalert/issues/1654
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    sed -i 's/elasticsearch>=7.0.0/elasticsearch==7.5.1/g' setup.py && \
    sed -i 's/elasticsearch>=7.0.0/elasticsearch==7.5.1/g' requirements.txt

RUN mkdir ~/.pip
COPY ./config/pip.conf ~/.pip/
COPY ./config/.pydistutils.cfg ~/


RUN pip install -r requirements.txt && \
    python3 setup.py install

FROM node:alpine3.10
LABEL maintainer="BitSensor <dev@bitsensor.io>"
# Set timezone for this container
ENV TZ Etc/UTC

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update --no-cache curl tzdata python2 make libmagic

COPY --from=py-ea /usr/lib/python3.7/site-packages /usr/lib/python3.7/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

USER node

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
