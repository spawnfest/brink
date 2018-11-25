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

# Demo Application
To demonstrate the functionality of Brink, we have set up a demo application.
There is one producer that periodically produces a set of random integers as
events on a Redis Stream indefinitely. There are two consumers, named "alfred"
and "bob", consuming the random integers and outputting them to the console.

## Usage
Clone this repo, then run
```
cd team-brb
docker-compose up
```

Once Redis starts, you will see output in the following format:
```
brink_demo_1_b3f89fe11adf | The time is: 15:35:22.833936.
brink_demo_1_b3f89fe11adf | [["1543160122835-66", ["now", "1543160122744", "value", "6820"]]]
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {0, 8}, 15171, 4995, "1543160124733"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {2, 8}, 15668, 5008, "1543160124722"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {3, 8}, 14917, 4991, "1543160124728"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {1, 8}, 15114, 5010, "1543160124714"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {7, 8}, 16743, 4977, "1543160124739"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {5, 8}, 15100, 4990, "1543160124673"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {6, 8}, 18157, 4998, "1543160124709"}
brink_demo_1_b3f89fe11adf | {:consumer, "alfred", {4, 8}, 16787, 4984, "1543160124709"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {0, 8}, 14525, 4987, "1543160124690"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {2, 8}, 16367, 5020, "1543160124708"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {5, 8}, 16409, 4998, "1543160124655"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {4, 8}, 18071, 4989, "1543160124734"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {6, 8}, 12069, 5013, "1543160124715"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {7, 8}, 16396, 5031, "1543160124745"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {1, 8}, 18926, 4999, "1543160124703"}
brink_demo_1_b3f89fe11adf | {:consumer, "bob", {3, 8}, 14726, 4999, "1543160124740"}
```
These are sets of events being consumed.

## Developing
Until we set up application environment variables and different runtime
environments with mix, running the demo app is tied to `docker-compose`. Since
the `brink` dependency is specified with a relative path, any local changes in
this repo to either the demo app or the Brink library will be rebuilt and run
with
```
docker-compose build && docker-compose up
```

# Features
## Currently Implemented
- `GenStage` behavior implementation
- Seamless integration with `Flow` stages
- `Brink.Producer` and `Brink.Consumer` modules that abstract away Redis calls
and manage Redis client connections
- Usage of Redis consumer groups

## Future Work
- Automated tests :smirk:
- Consumer clusters
