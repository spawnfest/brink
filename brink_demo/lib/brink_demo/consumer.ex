defmodule BrinkDemo.Consumer do
  use Flow

  def start_link(options) do
    redis_uri = Keyword.fetch!(options, :redis_uri)
    stream = Keyword.fetch!(options, :stream)
    group = Keyword.fetch!(options, :group)
    consumer = Keyword.fetch!(options, :consumer)

    {:ok, client} = Redix.start_link(redis_uri)
    Redix.command(client, ["XGROUP", "CREATE", stream, group, "$", "MKSTREAM"])
    Redix.stop(client)

    Flow.from_specs(
      [
        {Brink.Consumer,
         [
           name: :"Blink.Producer-#{consumer}",
           redis_uri: redis_uri,
           stream: stream,
           mode: :group,
           group: group,
           consumer: consumer,
           mode: :group
         ]}
      ],
      window: Flow.Window.periodic(3, :second)
    )
    |> Flow.reduce(fn -> {0, 0, ""} end, fn {_id, %{now: now, value: value}},
                                        {count, total_time, _time} ->
      {count + 1, total_time + elem(Integer.parse(value), 0), now}
    end)
    |> Flow.on_trigger(fn {count, total_time, time}, partition ->
      IO.inspect({:consumer, consumer, partition, count, div(total_time, count), time})
      {[], {0, 0, ""}}
    end)
    |> Flow.start_link()
  end
end
