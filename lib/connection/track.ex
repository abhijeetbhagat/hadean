defmodule Hadean.Connection.Track do
  @type t :: %__MODULE__{
          type: :audio | :video | :unknown,
          fmtp: binary(),
          id: integer(),
          codec: binary() | nil,
          rtp_type: integer()
        }
  defstruct type: :unknown,
            fmtp: <<>>,
            id: 0,
            codec: nil,
            rtp_type: 0
end
