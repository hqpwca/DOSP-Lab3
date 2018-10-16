defmodule Chord.Encoder do
	def bit_length, do: 32

	def encode_node(id) do
		<<x::32,_::96>> = :crypto.hash(:md5, "node" <> Integer.to_string(id))
		x
	end

	def encode_message(id) do
		<<x::32,_::96>> = :crypto.hash(:md5, "message" <> Integer.to_string(id))
		x
	end
end