FROM ubuntu:20.04

LABEL maintainer="Eugen Ciur <eugen@papermerge.com>"

#
# Builds Papermerge WORKER docker image based on latest release.
# Latest release is given by following URL:
# https://api.github.com/repos/ciur/papermerge/releases/latest
#

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y \
                    build-essential \
                    vim \
                    python3 \
                    python3-pip \
                    python3-venv \
                    virtualenv \
                    poppler-utils \
                    git \
                    imagemagick \
                    locales \
                    tesseract-ocr \
                    tesseract-ocr-deu \
                    tesseract-ocr-eng \
                    tesseract-ocr-fra \
                    tesseract-ocr-rus \
                    tesseract-ocr-ron \
                    tesseract-ocr-spa \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install --upgrade pip

RUN groupadd -g 1002 www
RUN useradd -g www -s /bin/bash --uid 1001 -d /opt/app www


# ensures our console output looks familiar and is not buffered by Docker
ENV PYTHONUNBUFFERED 1

ENV DJANGO_SETTINGS_MODULE config.settings.production
ENV PATH=/opt/app/:/opt/app/.local/bin:$PATH
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN mkdir -p /opt/app && \
if [ -z ${PAPERMERGE_RELEASE+x} ]; then \
    PAPERMERGE_RELEASE=$(curl -sX GET "https://api.github.com/repos/ciur/papermerge/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
fi && \
curl -o \
    /tmp/papermerge.tar.gz -L \
    "https://github.com/ciur/papermerge/archive/${PAPERMERGE_RELEASE}.tar.gz" && \
tar xf \
    /tmp/papermerge.tar.gz -C \
    /opt/app/ --strip-components=1

RUN mkdir -p /opt/media && mkdir -p /opt/etc

RUN mkdir -p /opt/media

COPY config/worker.production.py /opt/etc/production.py
COPY config/papermerge.config.py /opt/etc/papermerge.conf.py
COPY worker.startup.sh /opt/app/startup.sh
RUN chmod +x /opt/app/startup.sh

RUN chown -R www:www /opt/

WORKDIR /opt/app
USER www

ENV VIRTUAL_ENV=/opt/app/.venv
RUN virtualenv $VIRTUAL_ENV -p /usr/bin/python3.8

ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV DJANGO_SETTINGS_MODULE=config.settings.production

RUN ln -s /opt/etc/production.py /opt/app/config/settings/production.py
RUN ln -s /opt/etc/papermerge.conf.py /opt/app/papermerge.conf.py

RUN pip3 install -r requirements/base.txt --no-cache-dir
RUN pip3 install -r requirements/extra/pg.txt --no-cache-dir

CMD ["/opt/app/startup.sh"]