defmodule Chord.Node do
	use GenServer

	# Client Side
	def start_link({x, num_nodes}) do
		key = Chord.Encoder.encode_node(x)
		args = %{id: x, key: key, m: 16, pre: nil, suc: key, finger: Map.new, failed: false, dtime: Kernel.trunc((num_nodes - 1)/200) + 1}
		# status: {bits, key, pre, suc, finger, failed}
		GenServer.start_link(__MODULE__, args, name: {:global, key})
	end

	def find_successor(n, key) do
		GenServer.call({:global, n}, {:find_successor, key})
	end

	def find_successor(n, key, ref) do
		GenServer.cast({:global, n}, {:find_successor, key, ref})
	end

	def found_successor(n, res, ref) do
		GenServer.cast({:global, n}, {:found_successor, res, ref})
	end

	def join(n, n0) do
		GenServer.cast({:global, n}, {:join, n0})
	end

	def join_p2(n, res) do
		GenServer.cast({:global, n}, {:join_p2, res})
	end

	def notify(n, p) do
		GenServer.cast({:global, n}, {:notify, p})
	end

	def get_predecessor(n) do
		GenServer.call({:global, n}, {:get_pre})
	end

	def get_predecessor(n, ref) do
		GenServer.cast({:global, n}, {:get_pre, ref})
	end

	def check_failed(n) do
		GenServer.call({:global, n}, {:check_failed})
	end

	def set_failed(n) do
		GenServer.cast({:global, n}, {:set_failed})
	end

	def loop_stabilize(n) do
		GenServer.cast({:global, n}, {:loop_stabilize})
	end

	def loop_stabilize_p2(n, x) do
		GenServer.cast({:global, n}, {:loop_stabilize_p2, x})
	end

	def loop_fix_finger(n) do
		GenServer.cast({:global, n}, {:loop_fix_finger})
	end

	def loop_fix_finger_p2(n, newk, res) do
		GenServer.cast({:global, n}, {:loop_fix_finger_p2, newk, res})
	end

	# Server Side
	def init(args) do
		schedule_work(args[:dtime])
		{:ok, args}
	end

	def handle_info(:work, state) do
		k = state[:key]
		loop_stabilize(k)
		loop_fix_finger(k)
		schedule_work(state[:dtime])
		{:noreply, state}
	end

	defp schedule_work(dtime) do
		Process.send_after(self(), :work, dtime)
	end

	def handle_cast({:join, n0}, state) do
		k = state[:key]
		find_successor(n0, k, {k, :join, 0})
		{:noreply, state}
	end

	def handle_cast({:join_p2, res}, state) do
		#loop_stabilize(state[:key])
		#loop_fix_finger(state[:key])
		{:noreply, Map.put(state, :suc, res)}
	end

	def handle_cast({:notify, x}, state) do
		pre = state[:pre]
		if pre == nil || Chord.Arithmatic.in_between(x, pre, state[:key]) do
			{:noreply, Map.put(state, :pre, x)}
		else
			{:noreply, state}
		end
	end

	def handle_cast({:loop_stabilize}, state) do
		get_predecessor(state[:suc], state[:key])
		{:noreply, state}
	end

	def handle_cast({:loop_stabilize_p2, x}, state) do
		suc = state[:suc]
		key = state[:key]
		nsuc = if x != nil && Chord.Arithmatic.in_between(x, key, suc), do: x, else: suc
		notify(nsuc, key)
		#npre = if state[:pre] == nil || check_failed(state[:pre]), do: nil, else: state[:pre]

		{:noreply, Map.merge(state, %{suc: nsuc})}
	end

	def handle_cast({:loop_fix_finger}, state) do
		m = state[:m]
		key = state[:key]
		newk = if m + 1 >= Chord.Encoder.bit_length, do: 0, else: m + 1
		find_successor(key, key + Chord.Arithmatic.pow(2, newk), {key, :fix, newk})
		{:noreply, Map.put(state, :m, newk)}
	end

	def handle_cast({:loop_fix_finger_p2, newk, res}, state) do
		{:noreply, Map.put(state, :finger, Map.put(state[:finger], newk, res))}
	end

	def handle_cast({:set_failed}, state) do
		{:noreply, Map.put(state, :failed, true)}
	end

	def handle_cast({:find_successor, key, ref}, state) do
		skey = state[:key]
		suc = state[:suc]
		unless state[:failed] do
			{referer, return_type, pdata} = ref
			#if return_type != :fix, do: IO.inspect ref
			if return_type == :request, do: Chord.Collector.node_access
			if Chord.Arithmatic.in_between_with_r(key, skey, suc) do
				found_successor(skey, suc, ref)
				{:noreply, state}
			else
				{:ok, res} = closest_preceding_node(key, skey, state[:finger], Chord.Encoder.bit_length)
				if res != nil do
					find_successor(res, key, ref)
				else
					find_successor(suc, key, ref)
				end
				{:noreply, state}
			end
		else
			{:noreply, state}
		end
	end

	def handle_cast({:found_successor, res, ref}, state) do
		{referer, return_type, pdata} = ref
		case return_type do
			:fix     -> loop_fix_finger_p2(referer, pdata, res)
			:join    -> join_p2(referer, res)
			:request -> Chord.Requester.receive_suc(referer, pdata, res)
			_        -> IO.puts("ref_list error! #{ref}")
		end
		{:noreply, state}
	end

	def handle_cast({:get_pre, ref}, state) do
		#IO.inspect state
		loop_stabilize_p2(ref, state[:pre])
		{:noreply, state}
	end

	def closest_preceding_node(key, n, finger, m) when m < 0, do: {:ok, nil}
	def closest_preceding_node(key, n, finger, m) do
		if finger[m] != nil && Chord.Arithmatic.in_between(finger[m], n, key) do
			{:ok, finger[m]}
		else
			closest_preceding_node(key, n, finger, m-1)
		end
	end

	def handle_call({:get_pre}, _, state) do
		#IO.inspect state
		{:reply, state[:pre], state}
	end

	def handle_call({:check_failed}, _, state) do
		#IO.inspect state
		{:reply, state[:failed], state}
	end
end