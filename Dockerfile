FROM python:3.14

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

CMD ["sh", "-c", "python manage.py migrate && python manage.py runserver 0.0.0.0:5000"]
