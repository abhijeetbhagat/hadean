defmodule Hadean.Connection.Track do
  @type t :: %__MODULE__{
          type: :audio | :video | :unknown,
          fmtp: binary(),
          id: integer(),
          codec_info: Hadean.Codecs.AudioCodecInfo.t() | Hadean.Codecs.VideoCodecInfo.t() | nil,
          rtp_type: integer()
        }

  defstruct type: :unknown,
            fmtp: <<>>,
            id: 0,
            codec_info: nil,
            rtp_type: 0
end
