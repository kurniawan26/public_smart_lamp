ARG ELIXIR_IMAGE=elixir:1.19.5-otp-28-slim
ARG DEBIAN_IMAGE=debian:bookworm-slim

FROM ${ELIXIR_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git nodejs npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix assets

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM ${DEBIAN_IMAGE} AS runner

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libstdc++6 openssl libncurses6 locales \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PHX_SERVER=true \
    PORT=4000

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/smart_city_lamp ./
COPY --chown=nobody:root docker/entrypoint.sh /app/bin/container-start
RUN chmod 755 /app/bin/container-start

USER nobody

EXPOSE 4000

ENTRYPOINT ["/app/bin/container-start"]
