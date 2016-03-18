FROM      ubuntu
MAINTAINER Massimo Danieli "massimo@massimodanieli.com"



RUN apt-get update
RUN apt-get install -y python-cairo collectd-core libgcrypt11 python-virtualenv build-essential python-dev supervisor sudo

RUN adduser --system --group --no-create-home collectd && adduser --system --home /opt/graphite graphite

RUN sudo -u graphite virtualenv --system-site-packages ~graphite/env

RUN echo "django \n \
  python-memcached \n \
  django-tagging \n \
  twisted==11.1.0 \n \
  gunicorn \n \
  whisper==0.9.12 \n \
  carbon==0.9.12 \n \
  graphite-web==0.9.12" > /tmp/graphite_reqs.txt

RUN sudo -u graphite HOME=/opt/graphite /bin/sh -c ". ~/env/bin/activate && pip install -r /tmp/graphite_reqs.txt"

ADD collectd/collectd.conf /etc/collectd/
ADD supervisor/ /etc/supervisor/conf.d/
ADD graphite/local_settings.py /opt/graphite/webapp/graphite/
ADD graphite/wsgi.py /opt/graphite/webapp/graphite/
ADD graphite/mkadmin.py /opt/graphite/webapp/graphite/
ADD graphite/carbon.conf /opt/graphite/conf/
ADD graphite/storage-schemas.conf /opt/graphite/conf/

RUN cp /opt/graphite/conf/storage-aggregation.conf.example /opt/graphite/conf/storage-aggregation.conf

RUN sed -i "s#^\(SECRET_KEY = \).*#\1\"`python -c 'import os; import base64; print(base64.b64encode(os.urandom(40)))'`\"#" /opt/graphite/webapp/graphite/app_settings.py
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python manage.py migrate --noinput"
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python mkadmin.py"

EXPOSE 8080 25826/udp

CMD exec supervisord -n
