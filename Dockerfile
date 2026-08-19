# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t bento_manager .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name bento_manager bento_manager

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF bash -ex
  apt-get update -qq
  apt-get install --no-install-recommends -y curl libjemalloc2 sqlite3
  ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so
EOF

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF bash -ex
  apt-get update -qq
  apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config
EOF

# Install Litestream (ADR-0001 決定 5)
# accessory がレプリケーションを担うのとは別に、app イメージにもバイナリを置く。
# 用途は 2 つ: 日次リストア訓練の実行手段と、本番復旧時に
# `kamal app exec` から直接リストアを叩く手段。
#
# バージョンの出所は config/deploy.yml の builder.args。下のデフォルトは
# kamal を通さない `docker build` 用のフォールバック。
#
# アーキテクチャは BuildKit の TARGETARCH から導出する。直書きすると
# config/deploy.yml の builder.arch を変えたときに黙って別アーキのバイナリが入り、
# 気づくのは訓練が Errno::ENOEXEC で落ちる翌朝か、全損復旧の最中になる。
ARG LITESTREAM_VERSION=0.5.16
ARG TARGETARCH
# デリミタを quote するのは、外側の sh が litestream_arch を（未定義なので空文字に）
# 展開してしまうため。quote すれば展開は内側の bash だけが行う。
RUN <<'EOF' bash -ex
  case "${TARGETARCH:-amd64}" in
    amd64) litestream_arch=x86_64 ;;
    arm64) litestream_arch=arm64 ;;
    *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;;
  esac
  curl -fsSL "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${litestream_arch}.tar.gz" \
    | tar -xz -C /usr/local/bin litestream
EOF

# Install JavaScript dependencies
ARG NODE_VERSION=25.2.1
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master

# Install application gems
COPY Gemfile Gemfile.lock vendor ./

RUN --mount=type=cache,target=/root/.gem,sharing=locked \
    --mount=type=cache,target=/tmp/bundle,sharing=locked \
<<EOF bash -ex
  bundle config set path /tmp/bundle
  MAKEFLAGS="-j$(nproc)" bundle install --jobs=$(nproc)
  cp -ar /tmp/bundle /usr/local
EOF
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN <<EOF bash -ex
bundle config set path "${BUNDLE_PATH}"
bundle exec bootsnap precompile -j 1 --gemfile
EOF

# Install node modules
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails
COPY --from=build /usr/local/bin/litestream /usr/local/bin/litestream

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
