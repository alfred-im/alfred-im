# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV XMPP_PORT=8080
ENV MATRIX_PORT=8081

COPY bridge-xmpp/requirements.txt bridge-xmpp-requirements.txt
COPY bridge-matrix/requirements.txt bridge-matrix-requirements.txt
RUN pip install --no-cache-dir -r bridge-xmpp-requirements.txt -r bridge-matrix-requirements.txt

COPY bridge-xmpp/ bridge-xmpp/
COPY bridge-matrix/ bridge-matrix/
COPY scripts/start-bridges.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080 8081

CMD ["/bin/sh", "/start.sh"]
