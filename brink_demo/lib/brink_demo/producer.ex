defmodule BrinkDemo.Producer do
  use Flow

  def start_link(options) do
    redis_uri = Keyword.fetch!(options, :redis_uri)
    stream = Keyword.fetch!(options, :stream)

    Stream.repeatedly(&:rand.uniform/0)
    |> Flow.from_enumerable()
    |> Flow.map(
      &%{now: DateTime.to_unix(DateTime.utc_now(), :millisecond), value: round(&1 * 10_000)}
    )
    |> Flow.into_specs([
      {{Brink.Producer, [redis_uri: redis_uri, stream: stream, maxlen: 20_000]}, []}
    ])
  end
end
