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
"""

defmodule Hadean.Packet.VideoPacket do
  alias Hadean.Parsers.ExGolombDecoder

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

    sl = slice_data
    {_first_mb_in_slice, slice_data} = ExGolombDecoder.read_ue(slice_data)
    {frame_type, _slice_data} = ExGolombDecoder.read_ue(slice_data)

    frame_type =
      case frame_type do
        n when n == 0 or n == 5 -> :i
        n when n == 1 or n == 6 -> :b
        n when n == 2 or n == 7 -> :p
        n when n == 3 or n == 8 -> :sp
        n when n == 4 or n == 9 -> :si
        _ -> :unknown
      end

    %Hadean.Packet.VideoPacket{
      header: header,
      nalu_type: nalu_type,
      frame_type: frame_type,
      slice_data: sl
    }
  end
end
