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

	def build_ans(running_nodes) do
		GenServer.cast({:global, :collector}, {:build_ans, running_nodes})
	end

	#Server Side
	def init(args) do
		{:ok, args}
	end

	def handle_cast({:build_ans, running_nodes}, state) do
		ans1 = Enum.reduce(running_nodes, [], fn(x, acc) -> [Chord.Encoder.encode_node(x) | acc] end)
		ans1 = Enum.sort(ans1)
		#IO.inspect ans1
		ans3 = for n <- ans1, do: n + 4294967296
		ans1 = ans1 ++ ans3
		#ans2 = Enum.reduce(1..state[:nr], [], fn(x, acc) -> [{:message, x, Chord.Encoder.encode_message(x)} | acc] end)
		ans2 = Enum.reduce(1..state[:nr], [], fn(x, acc) ->
			[{x, Integer.mod(Enum.find(ans1, fn(y) -> Chord.Encoder.encode_message(x) < y end), 4294967296) } | acc] 
		end)
		result = ans2 |> Map.new
		#IO.inspect result
		
		{:noreply, Map.merge(state, %{result: result, correct: 0, wrong: 0})}
	end

	def handle_cast({:simulate}, state) do
		dtime = 10 * (Kernel.trunc((state[:n] - 1)/200) + 1)
		IO.puts "Start joining nodes, about to take #{dtime * state[:n] / 1000}s"
		Enum.each(2..state[:n], fn(x) -> 
			if x/state[:n] >= 0.2 && (x-1)/state[:n] < 0.2, do: IO.puts "20% Joining Finished."
			if x/state[:n] >= 0.4 && (x-1)/state[:n] < 0.4, do: IO.puts "40% Joining Finished."
			if x/state[:n] >= 0.6 && (x-1)/state[:n] < 0.6, do: IO.puts "60% Joining Finished."
			if x/state[:n] >= 0.8 && (x-1)/state[:n] < 0.8, do: IO.puts "80% Joining Finished."
			Chord.Node.join(Chord.Encoder.encode_node(x), Chord.Encoder.encode_node(x-1))
			Process.sleep(dtime)
		end)
		running = Enum.to_list(1..state[:n])
		IO.puts "Finished joining nodes, waiting for stabilize, about to take #{Kernel.max(2000,Kernel.trunc(dtime * state[:n] / 5))/1000}s"

		Process.sleep(Kernel.max(2000,Kernel.trunc(dtime * state[:n] / 5)))

		IO.puts "Stabilizing Finished."
		Enum.each(1..state[:n], fn(x) -> Chord.Node.stop_stabilize(Chord.Encoder.encode_node(x)) end)

		fail_list = 
			if state[:nf] > 0 do
				Enum.take_random(1..state[:n], state[:nf])
			else
				nil
			end

		running = if fail_list != nil, do: MapSet.new(running -- fail_list), else: MapSet.new(running)
		build_ans(running)

		failed = if fail_list != nil, do: Enum.reduce(fail_list, Map.new, fn(x, acc) -> Map.put(acc, Chord.Encoder.encode_node(x), true) end)
		
		if fail_list != nil do
			IO.puts("Closing failed nodes.")
			fail_list = Enum.sort(fail_list)
			Enum.each(fail_list, fn(x) -> Chord.Node.set_failed(Chord.Encoder.encode_node(x)) end)
			Enum.each(1..state[:n], fn(x) -> Chord.Node.acc_fail_nodes(Chord.Encoder.encode_node(x), failed) end)
			IO.puts("Failed nodes closed complete.")
		end

		#Enum.each(1..state[:n], fn(x) -> Chord.Node.print_state(Chord.Encoder.encode_node(x)) end)

		IO.puts("Start requesting.")
		IO.inspect(running)
		Enum.each(1..state[:n], fn(x) -> if fail_list == nil || x not in fail_list, do: Chord.Requester.start_request(x, state[:nr]) end)
		{:noreply, Map.merge(state, %{running_nodes: running, all_nodes: running})}
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
				running = MapSet.new(state[:all_nodes])
				{:noreply, Map.put(state, :running_nodes, running)}
			else
				{:noreply, Map.put(state, :running_nodes, new_running)}
			end
		end
	end

	def handle_cast({:check_result, message_id, node_key}, state) do
		result = state[:result]
		#IO.inspect {message_id, result[message_id], node_key}
		if result[message_id] == node_key do
			{:noreply, Map.put(state, :correct, state[:correct] + 1)}
		else
			#IO.inspect {message_id, result[message_id], node_key}
			#Chord.Node.print_state(node_key)
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
				IO.puts("Average Hops each request: #{state[:total_hops] / (state[:n]-state[:nf]) / state[:nr]}")
				send(state[:deamon], :finish)
			end
			{:noreply, Map.put(state, :running_nodes, new_running)}
		end
	end

	def handle_cast({:node_access}, state) do
		{:noreply, Map.put(state, :total_hops, state[:total_hops] + 1)}
	end
end