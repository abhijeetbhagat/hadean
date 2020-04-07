_ = """
From the H264-201610 standard:

leadingZeroBits = −1
for( b = 0; !b; leadingZeroBits++ )
  b = read_bits( 1 )

The variable codeNum is then assigned as follows:
codeNum = 2^leadingZeroBits − 1 + read_bits( leadingZeroBits )
"""

defmodule Hadean.Parsers.ExGolombDecoder do
  def read_ue(<<1::size(1)>>) do
    {0, ""}
  end

  def read_ue(<<slice_data::bitstring>>) do
    <<b::size(1), slice_data::bitstring>> = slice_data
    loop(b, 0, slice_data)
  end

  defp loop(0, leading_zero_bit, slice_data) do
    <<b::size(1), slice_data::bitstring>> = slice_data
    loop(b, leading_zero_bit + 1, slice_data)
  end

  defp loop(1, leading_zero_bit, slice_data) do
    <<n_bits::size(leading_zero_bit), slice_data::bitstring>> = slice_data
    {(:math.pow(2, leading_zero_bit) |> round) - 1 + n_bits, slice_data}
  end
end
