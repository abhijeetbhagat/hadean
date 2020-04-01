defmodule Hadean.Codecs.AudioCodecInfo do
  @type t :: %__MODULE__{
          payload_type: integer(),
          mode: :aac | :g711 | :unknown,
          size_length: integer(),
          index_length: integer(),
          index_delta_length: integer()
        }

  defstruct payload_type: 0,
            mode: :unknown,
            size_length: 0,
            index_length: 0,
            index_delta_length: 0
end

defmodule Hadean.Codecs.VideoCodecInfo do
  @type t :: %__MODULE__{
          payload_type: integer(),
          mode: :h264 | :h265 | :unknown,
          sprop_params_set: binary()
        }

  defstruct payload_type: 0,
            mode: :unknown,
            sprop_params_set: <<>>
end
