defmodule Chord do
	def main(args) do
		unless length(args) == 2 || (length(args) == 4 && Enum.at(args,2) == "-f") do
			IO.puts "Usage: ./chord numNodes numRequests [-f failNodes]"
		else
			numNodes    = Enum.at(args,0) |> String.to_integer()
			numRequests = Enum.at(args,1) |> String.to_integer()
			failNodes   = if length(args) == 4, do: Enum.at(args,3) |> String.to_integer(), else: 0

			Chord.Supervisor.start_link(numNodes, numRequests, failNodes, self())
			Chord.Collector.simulate
			receive do
				:finish -> IO.puts("Chord Finished.")
			end
		end
	end
end
