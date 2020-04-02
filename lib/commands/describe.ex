defmodule Hadean.Commands.Describe do
  def create(url, cseq_num) do
    "DESCRIBE #{url} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nAccept: application/sdp\r\n\r\n"
  end

  def create(url, cseq_num, auth) do
    "DESCRIBE #{url} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nAccept: application/sdp\r\n#{auth}\r\n\r\n"
  end
end
