FROM docker.io/library/ruby:3.2.2

WORKDIR /usr/src/app
ADD . /usr/src/app
RUN bundle install

CMD ["ruby", "app.rb"]
