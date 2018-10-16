defmodule Chord.Requester do
	use GenServer

	def start_link(x) do
		key = Chord.Encoder.encode_node(x)
		GenServer.start_link(__MODULE__, {x, key, 0, Map.new}, name: {:global, {:requester, x}})
	end

	def start_request(x, num_requests, pos \\ 1) do
		GenServer.cast({:global, {:requester, x}}, {:start_request, num_requests, pos})
	end

	def receive_suc(x, pos, res) do
		GenServer.cast({:global, {:requester, x}}, {:receive_suc, pos, res})
	end

	def init(args) do
		{:ok, args}
	end

	def handle_info({:next_request, num_request, pos}, {id, key, num, received}) do
		start_request(id, num_request, pos)
		{:noreply, {id, key, num, received}}
	end

	def handle_cast({:start_request, num_request, pos}, {id, key, num, received}) when pos > num_request, do: {:noreply, {id, key, num, received}}
	def handle_cast({:start_request, num_request, pos}, {id, key, num, received}) do
		Chord.Node.find_successor(key, Chord.Encoder.encode_message(pos), {id, :request, pos})
		Process.send_after(self(), {:next_request, num_request, pos + 1}, 1000)
		{:noreply, {id, key, num_request, received}}
	end

	def handle_cast({:receive_suc, pos, res}, {id, key, num, received}) do
		nre = Map.put(received, pos, res)
		#IO.inspect({id, pos, res})
		if map_size(nre) == num do
			Chord.Collector.finish(id)
			{:noreply, {id, key, 0, Map.new}}
		else
			{:noreply, {id, key, num, nre}}
		end
	end
end