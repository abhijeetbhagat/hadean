defmodule Hadean.Parsers.SDPParser do
  @spec parse_sdp(binary()) :: Hadean.Connection.ConnectionContext
  def parse_sdp(data) do
    loop(
      String.split(data, "\r\n")
      |> Enum.filter(fn line -> line != "" end),
      %Hadean.Connection.ConnectionContext{}
    )
  end

  defp loop([line | rest], state) do
    # IO.puts("line - #{line}")

    {state, rest} =
      case binary_part(line, 0, 3) do
        "m=a" ->
          {audio_track, rest} = parse_audio_description(line, rest)
          {state |> Map.put(:audio_track, audio_track), rest}

        "m=v" ->
          {video_track, rest} = parse_video_description(line, rest)
          {state |> Map.put(:video_track, video_track), rest}

        "Ses" ->
          {state |> Map.put(:session, parse_session(line)), rest}

        _ ->
          {state, rest}
      end

    loop(rest, state)
  end

  defp loop([], state) do
    state
  end

  defp parse_audio_description(line, lines) do
    [_, _, _, type_num] =
      line
      |> String.split("=")
      |> Enum.at(1)
      |> String.split(" ")

    audio_lines = Enum.take_while(lines, fn line -> String.starts_with?(line, "a=") end)

    track =
      common_parsing_loop(audio_lines, %Hadean.Connection.Track{
        type: :audio,
        rtp_type: String.to_integer(type_num)
      })

    audio_codec_info = parse_fmtp(track.fmtp)

    track = track |> Map.put(:codec_info, audio_codec_info)

    {track, lines |> Enum.drop(length(audio_lines))}
  end

  defp parse_fmtp(line) do
    line
    |> String.split(" ")
    |> Enum.at(1)
    |> String.split(";")
    |> Enum.map(fn prop_val -> String.split(prop_val, "=") |> List.to_tuple() end)
    |> to_audio_codec_info(%Hadean.Codecs.AudioCodecInfo{})
  end

  defp to_audio_codec_info([{prop, val} | tail], codec_info) do
    codec_info =
      case prop do
        "mode" ->
          case val do
            "AAC-hbr" -> codec_info |> Map.put(:mode, :aac)
            _ -> codec_info |> Map.put(:mode, :unknown)
          end

        "sizeLength" ->
          codec_info |> Map.put(:size_length, val |> String.to_integer())

        "indexLength" ->
          codec_info |> Map.put(:index_length, val |> String.to_integer())

        "indexdeltaLength" ->
          codec_info |> Map.put(:index_delta_length, val |> String.to_integer())

        _ ->
          codec_info
      end

    to_audio_codec_info(tail, codec_info)
  end

  defp to_audio_codec_info([], codec_info) do
    codec_info
  end

  defp parse_video_description(line, lines) do
    [_, _, _, type_num] =
      line
      |> String.split("=")
      |> Enum.at(1)
      |> String.split(" ")

    audio_lines = Enum.take_while(lines, fn line -> String.starts_with?(line, "a=") end)

    track =
      common_parsing_loop(audio_lines, %Hadean.Connection.Track{
        type: :video,
        rtp_type: String.to_integer(type_num)
      })

    {track, lines |> Enum.drop(length(audio_lines))}
  end

  defp common_parsing_loop([line | lines], track) do
    track =
      case binary_part(line, 0, 4) do
        "a=fm" ->
          track |> Map.put(:fmtp, line)

        "a=co" ->
          track |> Map.put(:id, String.split(line, ":") |> Enum.at(1))

        _ ->
          track
      end

    common_parsing_loop(lines, track)
  end

  defp common_parsing_loop([], track) do
    track
  end

  defp parse_session(line) do
    line
    |> String.split(";")
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
  end
end
