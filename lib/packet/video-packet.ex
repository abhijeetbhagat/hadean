_ = """
NALU Header
      +---------------+
      |0|1|2|3|4|5|6|7|
      +-+-+-+-+-+-+-+-+
      |F|NRI|  Type   |
      +---------------+

From the T-REC-H.264-201610 doc
Table G-1 – Name association to slice_type for NAL units with nal_unit_type equal to 20
slice_type Name of slice_type
0, 5       EP (P slice in scalable extension)
1, 6       EB (B slice in scalable extension)
2, 7       EI (I slice in scalable extension)


Table 7-6 – Name association to slice_type
slice_type Name of slice_type
0          P (P slice)
1          B (B slice)
2          I (I slice)
3          SP (SP slice)
4          SI (SI slice)
5          P (P slice)
6          B (B slice)
7          I (I slice)
8          SP (SP slice)
9          SI (SI slice)


leadingZeroBits = −1
for( b = 0; !b; leadingZeroBits++ )
b = read_bits( 1 )

The variable codeNum is then assigned as follows:
codeNum = 2^leadingZeroBits − 1 + read_bits( leadingZeroBits )
"""

defmodule Hadean.Packet.VideoPacket do
  defstruct header: nil,
            nalu_type: 0,
            frame_type: nil,
            slice_data: nil

  def parse(header, rtp_data) do
    <<
      nal_header::integer-8,
      slice_data::bitstring
    >> = rtp_data

    <<_::integer-1, _::integer-2, nalu_type::integer-5>> = <<nal_header::integer-8>>

    {_first_mb_in_slice, slice_data} = read_ue(slice_data)
    {frame_type, slice_data} = read_ue(slice_data)

    %Hadean.Packet.VideoPacket{
      header: header,
      nalu_type: nalu_type,
      frame_type: frame_type,
      slice_data: slice_data
    }
  end

  defp read_ue(slice_data) do
    <<b::size(1), slice_data::bitstring>> = slice_data
    loop(b, -1, slice_data)
  end

  defp loop(1, leading_zero_bits, slice_data) when leading_zero_bits == -1 do
    {0, slice_data}
  end

  defp loop(0, -1, slice_data) do
    {0, slice_data}
  end

  defp loop(0, leading_zero_bits, slice_data) do
    IO.puts("extracting #{leading_zero_bits}")
    <<n_bits::size(leading_zero_bits), slice_data::bitstring>> = slice_data
    {:math.pow(2, leading_zero_bits) - 1 + n_bits, slice_data}
  end

  defp loop(1, leading_zero_bits, slice_data) do
    <<b::size(1), slice_data::bitstring>> = slice_data
    loop(b, leading_zero_bits + 1, slice_data)
  end
end
