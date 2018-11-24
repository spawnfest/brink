FROM beardedeagle/alpine-elixir-builder:1.7
COPY config ./config
COPY rel ./rel
COPY mix.exs .
COPY mix.lock .
COPY lib ./lib
RUN export MIX_ENV=prod && \
    mix deps.get && \
    mix release
