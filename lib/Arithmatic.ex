defmodule Chord.Arithmatic do
	require Integer

	def pow(_, 0), do: 1
	def pow(x, n) when Integer.is_odd(n), do: x * pow(x, n - 1)
	def pow(x, n) do
		result = pow(x, div(n, 2))
		result * result
	end

	def in_between(x, a, b) do
		cond do
			a < b && x > a && x < b -> true
			a >= b && (x > a || x < b) -> true
			true -> false
		end
	end

	def in_between_with_r(x, a, b) do
		cond do
			a < b && x > a && x <= b -> true
			a >= b && (x > a || x <= b) -> true
			true -> false
		end
	end

	def in_between_with_l(x, a, b) do
		cond do
			a < b && x >= a && x < b -> true
			a >= b && (x >= a || x < b) -> true
			true -> false
		end
	end

	def in_between_with_lr(x, a, b) do
		cond do
			a < b && x > a && x <= b -> true
			a > b && (x > a || x <= b) -> true
			a == b && x == a -> true
			true -> false
		end
	end

end