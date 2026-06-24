FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PORT=8080

COPY bridge-xmpp/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bridge-xmpp/ .

EXPOSE 8080

CMD ["python", "main.py"]
