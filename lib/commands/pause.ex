defmodule Hadean.Commands.Pause do
  def create(url, cseq_num, session) do
    "PAUSE #{url} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\nSession: #{session}\r\n\r\n"
  end

  def create(url, cseq_num, session, auth) do
    "PAUSE #{url} RTSP/1.0\r\nCSeq: #{cseq_num}\r\nUser-Agent: hadean\r\nSession: #{session}\r\n#{
      auth
    }\r\n\r\n"
  end
end
