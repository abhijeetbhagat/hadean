defmodule Hadean.Packet.RTPPacket do
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
end
