use Mix.Config

config :logger, level: :debug

config :hadean,
  default_rtsp_port: 554
  audio_rtp_udp_port: 35501
  audio_rtcp_udp_port: 35502
  video_rtp_udp_port: 35503
  video_rtcp_udp_port: 35504
