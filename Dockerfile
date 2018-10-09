FROM ruby:2.4

WORKDIR /tmp

COPY Gemfile /tmp/Gemfile

RUN bundle install

RUN mkdir /app

COPY ./* /app/

WORKDIR /app

CMD [ "bundle exec ruby auc.rb" ]