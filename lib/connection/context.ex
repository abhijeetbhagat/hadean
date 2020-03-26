defmodule Hadean.Connection.ConnectionContext do
  @type t :: %__MODULE__{
          audio_track: Hadean.Connection.Track.t() | nil,
          video_track: Hadean.Connection.Track.t() | nil,
          file: binary(),
          session: integer()
        }

  defstruct audio_track: nil,
            video_track: nil,
            file: <<>>,
            session: 0
end
