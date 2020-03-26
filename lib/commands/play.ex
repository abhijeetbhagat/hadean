defmodule Hadean.Commands.Play do
  def create(url, cseq_num, session) do
    "PLAY #{url}/trackID=2 RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\nSession: #{
      session
    }\r\nRange: npt=0.000-\r\n\r\n"
  end
end