# Brink
Brink is a producer-consumer library for
[Redis Streams](https://redis.io/topics/streams-intro). It is an implementation
of the [GenStage](https://hexdocs.pm/gen_stage) behavior and is intended to be
used with [Flow](https://hexdocs.pm/flow). It provides an Elixir-friendly
abstraction over Redis Streams that allows events to be produced and consumed
in parallel stages.

Brink sits in the middle of an event chain, between other producers and
consumers.

```
[Producer] --Elixir events--> [Brink (Redis Stream)] --Elixir events--> [Consumer]
```

## Installation

Brink is not yet stable or hosted on Hex, so it should be installed from a local
path like so:

```elixir
def deps do
  [
    {:brink, "~> 0.1", path: "/local/path/to/brink"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
locally with `mix docs`.

## Usage
### Producer
``` elixir
your_function_returning_a_Stream
|> Flow.from_enumerable()
|> Flow.your_flow_functions(...)
|> Flow.into_specs([
     {{Brink.Producer,
       [redis_uri: "redis://localhost:6796",
        stream: "redis-stream-name",
        maxlen: 20_000]}, []}
   ])
```
The Brink producer will first consume the data coming in from the Stream
returned by `your_function_returning_a_Stream` then produce Redis Stream events
from that data.

### Consumer
```elixir
Flow.from_specs(
  [{Brink.Consumer,
    [name: :unique_process_name,
     redis_uri: "redis://localhost:6796",
     stream: "redis-stream-name",
     mode: :single]}]
)
|> your_flow_functions
|> Flow.start_link()
```
The Brink consumer will first consume events from the Redis Stream and then
produce Elixir events for `your_flow_functions` to consume.
