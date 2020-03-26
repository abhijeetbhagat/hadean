defmodule HadeanTest do
  use ExUnit.Case
  alias Hadean.Connection.Track
  alias Hadean.Connection.ConnectionContext
  alias Hadean.Parsers.SDPParser

  doctest Hadean.Parsers.SDPParser

  test "sdp parsing" do
    sdp = """
    RTSP/1.0 200 OK
    CSeq: 3
    Server: Wowza Streaming Engine 4.7.5.01 build21752
    Cache-Control: no-cache
    Expires: Wed, 25 Mar 2020 18:58:55 UTC
    Content-Length: 581
    Content-Base: rtsp://wowzaec2demo.streamlock.net:554/vod/mp4:BigBuckBunny_115k.mov/
    Date: Wed, 25 Mar 2020 18:58:55 UTC
    Content-Type: application/sdp
    Session: 1770482999;timeout=60

    v=0
    o=- 1770482999 1770482999 IN IP4 3.84.6.190
    s=BigBuckBunny_115k.mov
    c=IN IP4 3.84.6.190
    t=0 0
    a=sdplang:en
    a=range:npt=0- 596.48
    a=control:*
    m=audio 0 RTP/AVP 96
    a=rtpmap:96 mpeg4-generic/12000/2
    a=fmtp:96 profile-level-id=1;mode=AAC-hbr;sizelength=13;indexlength=3;indexdeltalength=3;config=1490
    a=control:trackID=1
    m=video 0 RTP/AVP 97
    a=rtpmap:97 H264/90000
    a=fmtp:97 packetization-mode=1;profile-level-id=42C01E;sprop-parameter-sets=Z0LAHtkDxWhAAAADAEAAAAwDxYuS,aMuMsg==
    a=cliprect:0,0,160,240
    a=framesize:97 240-160
    a=framerate:24.0
    a=control:trackID=2

    """

    context = SDPParser.parse_sdp(sdp)
    IO.puts(inspect(context))
    assert(context.audio_track.type == :audio)
  end
end
