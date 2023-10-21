FROM docker.io/library/ruby:3.2.2 AS UPDATE

ENV NODE_MAJOR 20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

RUN apt-get update
RUN apt-get install -y ca-certificates curl gnupg nodejs supervisor

FROM UPDATE as DEPS

WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock .
RUN bundle install

FROM DEPS as FINAL

RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY . .

CMD ["/usr/bin/supervisord"]
