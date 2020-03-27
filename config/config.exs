use Mix.Config

config :logger, level: :debug

config :hadean,
  default_rtsp_port: 554,
  rtp_udp_port_start: 35501
