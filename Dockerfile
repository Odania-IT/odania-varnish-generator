FROM alpine:3.18
MAINTAINER Mike Petersen <mike@odania-it.de>

RUN apk update && apk add --no-cache ruby ruby-dev varnish vim g++ musl-dev make
COPY . /srv
WORKDIR /srv
RUN gem install bundler --no-ri --no-rdoc
RUN bundle install

CMD ["/srv/run.rb"]
