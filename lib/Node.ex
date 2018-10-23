defmodule Chord.Node do
	use GenServer

	# Client Side
	def start_link({x, num_nodes}) do
		key = Chord.Encoder.encode_node(x)
		args = %{id: x, key: key, m: 16, pre: nil, suc: [key], isuc: key, finger: Map.new, failed: false, dtime: Kernel.trunc((num_nodes - 1)/200) + 1, fnodes: Map.new}
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

	def get_failed(n, ref) do
		GenServer.cast({:global, n}, {:get_failed, ref})
	end

	def stop_stabilize(n) do
		GenServer.cast({:global, n}, {:stop_stabilize})
	end

	def loop_stabilize(n) do
		GenServer.cast({:global, n}, {:loop_stabilize})
	end

	def loop_stabilize_p2(n, x) do
		GenServer.cast({:global, n}, {:loop_stabilize_p2, x})
	end

	def loop_check_failed(n) do
		GenServer.cast({:global, n}, {:loop_check_failed})
	end

	def loop_check_failed_p2(n, failed) do
		GenServer.cast({:global, n}, {:loop_check_failed_p2, failed})
	end

	def request_sucessor_list(n, ref) do
		GenServer.cast({:global, n}, {:request_sucessor_list, ref})
	end

	def update_sucessor_list(n, suc_list) do
		GenServer.cast({:global, n}, {:update_sucessor_list, suc_list})
	end

	def loop_fix_finger(n) do
		GenServer.cast({:global, n}, {:loop_fix_finger})
	end

	def loop_fix_finger_p2(n, newk, res) do
		GenServer.cast({:global, n}, {:loop_fix_finger_p2, newk, res})
	end

	def acc_fail_nodes(n, fail_nodes) do
		GenServer.cast({:global, n}, {:acc_fail_nodes, fail_nodes})
	end

	def print_state(n) do
		GenServer.cast({:global, n}, {:print_state})
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
		#loop_check_failed(k)
		if state[:stop_stabilize] != true do
			schedule_work(state[:dtime])
		end
		{:noreply, state}
	end

	defp schedule_work(dtime) do
		Process.send_after(self(), :work, dtime)
	end

	def handle_cast({:acc_fail_nodes, fail_nodes}, state) do
		{:noreply, Map.put(state, :fnodes, fail_nodes)}
	end

	def handle_cast({:join, n0}, state) do
		k = state[:key]
		find_successor(n0, k, {k, :join, 0})
		{:noreply, state}
	end

	def handle_cast({:join_p2, res}, state) do
		#loop_stabilize(state[:key])
		#loop_fix_finger(state[:key])
		{:noreply, Map.put(state, :suc, [res])}
	end

	def handle_cast({:notify, x}, state) do
		pre = state[:pre]
		if pre == nil || Chord.Arithmatic.in_between(x, pre, state[:key]) do
			{:noreply, Map.put(state, :pre, x)}
		else
			{:noreply, state}
		end
	end

	def handle_cast({:print_state}, state) do
		IO.inspect(state)
		{:noreply, state}
	end

	def handle_cast({:loop_stabilize}, state) do
		get_predecessor(List.first(state[:suc]), state[:key])
		{:noreply, state}
	end

	def handle_cast({:loop_stabilize_p2, x}, state) do
		[suc | remain] = state[:suc]
		key = state[:key]
		nsuc = if x != nil && Chord.Arithmatic.in_between(x, key, suc), do: x, else: suc
		request_sucessor_list(nsuc, state[:key])
		notify(nsuc, key)

		{:noreply, Map.put(state, :isuc, nsuc)}
	end

	def handle_cast({:request_sucessor_list, ref}, state) do
		suc_list = [state[:key] | List.delete(state[:suc], state[:key])]
		suc_list = 
		if length(suc_list) > 20 do
			suc_list |> Enum.reverse() |> tl() |> Enum.reverse()
		else
			suc_list
		end
		update_sucessor_list(ref, suc_list)
		{:noreply, state}
	end

	def handle_cast({:update_sucessor_list, suc_list}, state) do
		#IO.inspect {state[:key],suc_list}
		if (List.first(suc_list) != state[:isuc]) do
			{:noreply, state}
		else
			{:noreply, Map.put(state, :suc, suc_list)}
		end
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

	def handle_cast({:loop_check_failed}, state) do
		if state[:pre] != nil do
			get_failed(state[:pre], state[:key])
		end
		{:noreply, state}
	end

	def handle_cast({:loop_check_failed_p2, failed}, state) do
		if failed do
			{:noreply, Map.put(state, :pre, nil)}
		else
			{:noreply, state}
		end
	end

	def handle_cast({:stop_stabilize}, state) do
		{:noreply, Map.put(state, :stop_stabilize, true)}
	end

	def handle_cast({:set_failed}, state) do
		{:noreply, Map.put(state, :failed, true)}
	end

	def handle_cast({:find_successor, key, ref}, state) do
		skey = state[:key]
		fnodes = state[:fnodes]
		suc = closest_running_sucessor(state[:suc], fnodes)
		unless state[:failed] do
			{referer, return_type, pdata} = ref
			#if return_type != :fix, do: IO.inspect ref
			if return_type == :request, do: Chord.Collector.node_access
			if Chord.Arithmatic.in_between_with_r(key, skey, suc) do
				found_successor(skey, suc, ref)
				{:noreply, state}
			else
				{:ok, res} = closest_preceding_node(key, skey, state[:finger], Chord.Encoder.bit_length,
													state[:suc], return_type, fnodes)
				#if return_type == :request, do: IO.inspect {skey, first_ok}
				if res != nil do
					if res != skey do
						find_successor(res, key, ref)
					else
						found_successor(skey, suc, ref)
					end
				else
					find_successor(suc, key, ref)
				end
				{:noreply, state}
			end
		else
			IO.inspect state
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

	def handle_cast({:get_failed, ref}, state) do
		loop_check_failed_p2(ref, state[:failed])
		{:noreply, state}
	end

	def closest_running_sucessor(suc, fnodes) do
		[x | nsuc] = suc
		if fnodes[x] do
			closest_running_sucessor(nsuc, fnodes)
		else
			x
		end
	end

	def closest_preceding_node(key, n, finger, m, suc, return_type, fnodes) when suc == [], do: {:ok, n}
	def closest_preceding_node(key, n, finger, m, suc, return_type, fnodes) do
		x = List.last(suc)
		nsuc = suc |> Enum.reverse() |> tl() |> Enum.reverse()
		{nsuc, x, isnil} = cond do
			x == n && length(nsuc) > 0 -> {nsuc |> Enum.reverse() |> tl() |> Enum.reverse(), List.last(nsuc), false}
			x == n && length(nsuc) == 0 -> {nsuc, x, true}
			true -> {nsuc, x, false}	
		end 
		if isnil || (m < 0 && suc == []) do
			{:ok, nil}
		else
			if m < 0 || Chord.Arithmatic.in_between(finger[m], n, x) do
				if m > 0 && finger[m] == nil do
					closest_preceding_node(key, n, finger, m-1, suc, return_type, fnodes)
				else
					if Chord.Arithmatic.in_between(x, n, key) do
						if fnodes[x] do
							closest_preceding_node(key, n, finger, m, nsuc, return_type, fnodes)
						else
							{:ok, x}
						end
					else
						closest_preceding_node(key, n, finger, m, nsuc, return_type, fnodes)
					end
				end
			else
				if finger[m] != nil && Chord.Arithmatic.in_between(finger[m], n, key) do
					if fnodes[finger[m]] do
						closest_preceding_node(key, n, finger, m-1, suc, return_type, fnodes)
					else
						{:ok, finger[m]}
					end
				else
					closest_preceding_node(key, n, finger, m-1, suc, return_type, fnodes)
				end
			end
		end
	end

	def handle_call({:get_pre}, _, state) do
		#IO.inspect state
		{:reply, state[:pre], state}
	end

	def handle_call({:check_failed}, from, state) do
		#IO.inspect state
		spawn_link fn ->
			GenServer.reply(from, state[:failed])
		end
		{:noreply, state}
	end
end