defmodule Hadean.Commands.Options do
  def create(url, cseq_num) do
    "OPTIONS #{url} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\n\r\n"
  end
end
