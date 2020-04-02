_ = """
From https://tools.ietf.org/html/rfc3640#section-2.11 -


+---------+-----------+-----------+---------------+
| RTP     | AU Header | Auxiliary | Access Unit   |
| Header  | Section   | Section   | Data Section  |
+---------+-----------+-----------+---------------+

          <----------RTP Packet Payload----------->

    Figure 1: Data sections within an RTP packet

From https://tools.ietf.org/html/rfc3640#section-3.2.1 -

+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+- .. -+-+-+-+-+-+-+-+-+-+
|AU-headers-length|AU-header|AU-header|      |AU-header|padding|
|                 |   (1)   |   (2)   |      |   (n)   | bits  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+- .. -+-+-+-+-+-+-+-+-+-+

  Figure 2: The AU Header Section

AU-headers-length is a two octet field that specifies the length in bits
of the immediately following AU-headers, excluding the padding bits.

From https://tools.ietf.org/html/rfc3640#section-3.2.1.1 -

      +---------------------------------------+
      |     AU-size                           |
      +---------------------------------------+
      |     AU-Index / AU-Index-delta         |
      +---------------------------------------+
      |     CTS-flag                          |
      +---------------------------------------+
      |     CTS-delta                         |
      +---------------------------------------+
      |     DTS-flag                          |
      +---------------------------------------+
      |     DTS-delta                         |
      +---------------------------------------+
      |     RAP-flag                          |
      +---------------------------------------+
      |     Stream-state                      |
      +---------------------------------------+

   Figure 3: The fields in the AU-header.  If used, the AU-Index field
             only occurs in the first AU-header within an AU Header
             Section; in any other AU-header, the AU-Index-delta field
             occurs instead.
"""

defmodule Hadean.Packet.AudioPacket do
  defstruct header: nil,
            type: :aac,
            raw_data: nil

  def parse(rtp_header, rtp_payload, codec_info) do
    <<_au_headers_length::integer-16, rest::bitstring>> = rtp_payload
    size_length = codec_info.size_length
    index_length = codec_info.index_length
    <<_au_size::size(size_length), _au_index::size(index_length), payload::binary>> = rest

    # TODO abhi: populate the type member with right value
    %__MODULE__{
      header: rtp_header,
      raw_data: payload
    }
  end
end
