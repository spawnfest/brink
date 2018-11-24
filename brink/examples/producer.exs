Flow.from_enumerable(1..10_000)
|> Flow.partition()
|> Flow.map(&%{v: &1, w: &1 * 2})
|> Flow.into_specs([{{Brink.Producer, [redis_uri: "redis://127.0.0.1:6379"]}, []}])

# Surely there's a better way?
Process.sleep(10_000)
