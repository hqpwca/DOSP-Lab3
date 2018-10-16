defmodule Chord.Collector do
	use GenServer

	def start_link({num_nodes, num_requests, num_failed, app}) do
		args = %{n: num_nodes, nr: num_requests, total_hops: 0, nf: num_failed, deamon: app, }
		GenServer.start_link(__MODULE__, args, name: {:global, :collector})
	end

	def node_access do
		GenServer.cast({:global, :collector}, {:node_access})
	end

	def simulate do
		GenServer.cast({:global, :collector}, {:simulate})
	end

	def check_result(message_id, node_key) do
		GenServer.cast({:global, :collector}, {:check_result, message_id, node_key})
	end

	def finish(id) do
		GenServer.cast({:global, :collector}, {:finished, id})
	end

	def finish(id, step) do
		GenServer.cast({:global, :collector}, {:finished, id, step})
	end

	#Server Side
	def init(args) do
		ans1 = Enum.reduce(1..args[:n], [], fn(x, acc) -> [Chord.Encoder.encode_node(x) | acc] end)
		ans1 = Enum.sort(ans1)
		ans1 = ans1 ++ ans1
		#ans2 = Enum.reduce(1..args[:nr], [], fn(x, acc) -> [{:message, x, Chord.Encoder.encode_message(x)} | acc] end)
		ans2 = Enum.reduce(1..args[:nr], [], fn(x, acc) ->
			[{x, Enum.find(ans1, fn(y) -> Chord.Encoder.encode_message(x) < y end)} | acc] 
		end)
		result = ans2 |> Map.new
		#IO.inspect result
		
		{:ok, Map.merge(args, %{result: result, correct: 0, wrong: 0})}
	end

	def handle_cast({:simulate}, state) do
		dtime = Kernel.trunc((state[:n] - 1) / 50) + 1
		IO.puts "Start joining nodes, about to take #{dtime * state[:n] / 1000}s"
		Enum.each(2..state[:n], fn(x) -> 
			if x/state[:n] >= 0.2 && (x-1)/state[:n] < 0.2, do: IO.puts "20% Joining Finished."
			if x/state[:n] >= 0.4 && (x-1)/state[:n] < 0.4, do: IO.puts "40% Joining Finished."
			if x/state[:n] >= 0.6 && (x-1)/state[:n] < 0.6, do: IO.puts "60% Joining Finished."
			if x/state[:n] >= 0.8 && (x-1)/state[:n] < 0.8, do: IO.puts "80% Joining Finished."
			Chord.Node.join(Chord.Encoder.encode_node(x), Chord.Encoder.encode_node(x-1))
			Process.sleep(dtime)
		end)
		running = MapSet.new(1..state[:n])
		IO.puts "Finished joining nodes, waiting for stabilize."

		Process.sleep(Kernel.trunc(state[:n] * dtime / 5) + 1)

		fail_list = 
			if state[:nf] > 0 do
				Enum.take_random(1..state[:n], state[:nf])
			else
				nil
			end
		
		if fail_list != nil do
			IO.puts("Closing failed nodes.")
			fail_list = Enum.sort(fail_list)
			Enum.each(fail_list, fn(x) -> Chord.Node.set_failed(Chord.Encoder.encode_node(x)) end)
			Enum.each(fail_list, fn(x) -> MapSet.delete(running, x) end)
			IO.puts("Failed nodes closed complete.")
		end

		IO.puts("Start requesting.")
		Enum.each(1..state[:n], fn(x) -> if fail_list == nil || x not in fail_list, do: Chord.Requester.start_request(x, state[:nr]) end)
		{:noreply, Map.put(state, :running_nodes, running)}
	end

	def handle_cast({:finished, id, step}, state) do
		if state[:running_nodes] == nil do
			Process.sleep(1000)
			finish(id)
			{:noreply, state}
		else
			new_running = MapSet.delete(state[:running_nodes], id)
			#IO.puts("Node No.#{id} finished.")
			if Enum.empty?(new_running) do
				IO.puts("Finished Step ##{step}, Correct: #{state[:correct]}, Wrong: #{state[:wrong]}")
				running = MapSet.new(1..state[:n])
				{:noreply, Map.put(state, :running_nodes, running)}
			else
				{:noreply, Map.put(state, :running_nodes, new_running)}
			end
		end
	end

	def handle_cast({:check_result, message_id, node_key}, state) do
		result = state[:result]
		#IO.inspect {message_id, result[:message_id], node_key}
		if result[message_id] == node_key do
			{:noreply, Map.put(state, :correct, state[:correct] + 1)}
		else
			{:noreply, Map.put(state, :wrong, state[:wrong] + 1)}
		end
	end

	def handle_cast({:finished, id}, state) do
		if state[:running_nodes] == nil do
			Process.sleep(1000)
			finish(id)
			{:noreply, state}
		else
			new_running = MapSet.delete(state[:running_nodes], id)
			#IO.puts("Node No.#{id} finished.")
			if Enum.empty?(new_running) do
				IO.puts("Finished Step ##{state[:nr]}, Correct: #{state[:correct]}, Wrong: #{state[:wrong]}")
				IO.puts("Average Hops each request: #{state[:total_hops] / state[:n] / state[:nr]}")
				send(state[:deamon], :finish)
			end
			{:noreply, Map.put(state, :running_nodes, new_running)}
		end
	end

	def handle_cast({:node_access}, state) do
		{:noreply, Map.put(state, :total_hops, state[:total_hops] + 1)}
	end
end