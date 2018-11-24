Flow.from_enumerable(1..10_000)
|> Flow.partition()
|> Flow.map(&%{v: &1, w: &1 * 2})
|> Flow.into_specs([{{Brink.Producer, [stream: "brink", maxlen: 20_000]}, []}])

# Surely there's a better way?
Process.sleep(3_000)
