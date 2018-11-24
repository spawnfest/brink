defmodule Brink.Producer do
  use GenStage

  @moduledoc """
  The Brink.Producer is a GenStage consumer that produces events to a Redis
  Stream. It can be used, with one or more processes, as a sink for
  Flow.into_stages/Flow.into_specs .
  """

  def init(options) do
    {:consumer, :some_kind_of_state}
  end

  def handle_events(things, from, state) do
    {:noreply, [], state}
  end

  @doc """

  """
  def hello do
    :world
  end
end
