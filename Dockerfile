FROM ruby:3.3.0

RUN bundle config --global frozen 1

WORKDIR /usr/src/app
RUN apt-get update && apt-get install -y vim
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["./entry_point.rb"]