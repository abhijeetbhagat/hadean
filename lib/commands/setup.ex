defmodule Hadean.Commands.Setup do
  def create(url, cseq_num, session, track_id) do
    "SETUP #{url}/#{track_id} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;interleaved=1-0\r\nSession: #{
      session
    }\r\n\r\n"
  end

  def create(url, cseq_num, session, track_id, rtp_port, rtcp_port) do
    "SETUP #{url}/#{track_id} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;client_port=#{
      rtp_port
    }-#{rtcp_port}\r\nSession: #{session}\r\n\r\n"
  end
end
