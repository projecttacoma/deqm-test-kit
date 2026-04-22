ARG RUBY_VERSION=3.3-debian13

FROM dhi.io/ruby:${RUBY_VERSION}-dev AS build

ENV INSTALL_PATH=/opt/inferno \
    APP_ENV=production \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR ${INSTALL_PATH}

COPY *.gemspec ./
COPY Gemfile* ./

RUN gem install bundler && \
    bundle config set --local deployment 'true' && \
    bundle install

COPY . .

FROM dhi.io/ruby:${RUBY_VERSION} AS runtime

ENV INSTALL_PATH=/opt/inferno \
    APP_ENV=production \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR ${INSTALL_PATH}

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build ${INSTALL_PATH} ${INSTALL_PATH}

EXPOSE 4567
CMD ["bundle", "exec", "puma"]