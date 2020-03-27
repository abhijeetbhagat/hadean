defmodule Hadean.Connection.InterleavedRTPStream do
  defstruct rtsp_socket: nil,
            video_rtp_socket: nil,
            video_rtcp_socket: nil,
            video_rtp_port: 0,
            video_rtcp_port: 0,
            cseq_num: 0,
            video_rtp_streamer_pid: 0,
            video_rtcp_streamer_pid: 0,
            context: nil

  def handle(:setup_audio, state) do
    rtp_port = 35503
    rtcp_port = 35504

    :gen_tcp.send(
      state.rtsp_socket,
      "SETUP #{state.url}/#{state.context.audio_track.id} RTSP/1.0\r\nCSeq: #{state.cseq_num}\r\nUser-Agent: hadean\r\nTransport: RTP/AVP;unicast;client_port=#{
        rtp_port
      }-#{rtcp_port}\r\nSession: #{state.context.session}\r\n\r\n"
    )

    response =
      case(:gen_tcp.recv(state.rtsp_socket, 0)) do
        {:ok, response} -> response
        {:error, reason} -> raise reason
      end

    {server_rtp_port, server_rtcp_port} = SetupResponseParser.parse_server_ports(response)

    {:ok, audio_rtp_socket} = :gen_udp.open(rtp_port, [:binary, active: false])
    {:ok, audio_rtcp_socket} = :gen_udp.open(rtcp_port, [:binary, active: false])

    state =
      state
      |> Map.put(:audio_rtp_socket, audio_rtp_socket)
      |> Map.put(:audio_rtcp_socket, audio_rtcp_socket)

    :gen_udp.send(state.audio_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.audio_rtcp_socket, state.server, server_rtcp_port, "")

    :gen_udp.send(state.audio_rtp_socket, state.server, server_rtp_port, "deadface")
    :gen_udp.send(state.audio_rtcp_socket, state.server, server_rtcp_port, "")

    state
    |> Map.put(:cseq_num, state.cseq_num + 1)
    |> Map.put(:audio_rtp_port, server_rtp_port)
    |> Map.put(:audio_rtcp_port, server_rtcp_port)
  end
end
