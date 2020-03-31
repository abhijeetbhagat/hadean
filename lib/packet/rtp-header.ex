use Bitwise

defmodule Hadean.Packet.RTPPacketHeader do
  defstruct version: 0,
            padding: false,
            extension: false,
            cc: 0,
            marker: false,
            payload_type: 0,
            seq_num: 0,
            timestamp: 0,
            # synchronization source identifier
            ssrc: 0,
            # contributing source identifiers
            csrcs: [],
            profile_specific_ext_hdr_id: 0,
            ext_hdr_len: 0

  def parse_packet(rtp_data) do
    <<
      packet_header::integer-8,
      marker_payload_type::integer-8,
      seq_num::integer-16,
      timestamp::integer-32,
      ssrc::integer-32,
      rest::binary
    >> = rtp_data

    version =
      case packet_header &&& 0x80 do
        0 -> 1
        _ -> 2
      end

    padding = (packet_header &&& 0x20) > 0
    extension = (packet_header &&& 0x10) > 0
    cc = packet_header &&& 0xF
    marker = (marker_payload_type &&& 0x80) > 0
    payload_type = marker_payload_type &&& 0x7F

    header = %Hadean.Packet.RTPPacketHeader{
      version: version,
      padding: padding,
      extension: extension,
      cc: cc,
      marker: marker,
      payload_type: payload_type,
      seq_num: seq_num,
      timestamp: timestamp,
      ssrc: ssrc
    }

    {header, rest}
  end
end
