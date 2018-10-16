defmodule Chord.Supervisor do
	use Supervisor
	
	def start_link(numNodes, numRequests, failNodes, app) do
		Supervisor.start_link(__MODULE__, {numNodes, numRequests, failNodes, app}, name: {:global, :supervisor})
	end

	def init({numNodes, numRequests, failNodes, app}) do
		collector = Supervisor.child_spec({Chord.Collector, {numNodes, numRequests, failNodes, app}}, restart: :transient)

		requesters = Enum.reduce(numNodes..1, [], fn(x, acc) ->
			[Supervisor.child_spec({Chord.Requester, x}, id: {Chord.Requester, x}, restart: :transient) | acc] end)

		nodes = Enum.reduce(numNodes..1, [], fn(x, acc) -> 
			[Supervisor.child_spec({Chord.Node, {x, numNodes}}, id: {Chord.Node, x}, restart: :transient) | acc] end)

		children = [collector | nodes ++ requesters]
		Supervisor.init(children, strategy: :one_for_one)
	end
end