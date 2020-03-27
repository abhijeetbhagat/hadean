defmodule Hadean.Connection.SocketPairGenerator do
  use GenServer

  def init(rtp_port) do
    {:ok, rtp_port}
  end

  def start_link() do
    rtp_port = Application.fetch_env!(:hadean, :rtp_udp_port_start)
    GenServer.start_link(__MODULE__, rtp_port, name: __MODULE__)
  end

  def handle_call(:get, _from, state) do
    {rtp_socket, rtcp_socket, next_rtp_port} = get_adjacent_sock_pairs(state)
    {:reply, {rtp_socket, rtcp_socket}, next_rtp_port}
  end

  def get_adjacent_sock_pairs(port) when port >= 65536 or port < 0 do
    {nil, nil, 0}
  end

  def get_adjacent_sock_pairs(rtp_start) do
    case {:gen_udp.open(rtp_start, [:binary, active: false]),
          :gen_udp.open(rtp_start + 1, [:binary, active: false])} do
      # we have adjacent socket pairs; set the next rtp port and return the pair
      {{:ok, rtp_socket}, {:ok, rtcp_socket}} ->
        {rtp_socket, rtcp_socket, rtp_start + 2}

      # we have an rtcp socket failure; discard the current pair of ports and start again
      {{:ok, rtp_socket}, {:error, _}} ->
        :gen_udp.close(rtp_socket)
        get_adjacent_sock_pairs(rtp_start + 2)

      # rtp socket failure; check if the next port is available and swap sockets if yes;
      # else, start again
      {{:error, _}, {:ok, rtcp_socket}} ->
        case check(:gen_udp.open(rtp_start + 2, [:binary, active: false])) do
          nil ->
            :gen_udp.close(rtcp_socket)

          rtp_socket ->
            {rtcp_socket, rtp_socket, rtp_start + 3}
        end

      # no sockets; start again
      {_, _} ->
        get_adjacent_sock_pairs(rtp_start + 2)
    end
  end

  # check overflows

  defp check({:ok, socket}) do
    socket
  end

  defp check({:error, _}) do
    nil
  end

  def get_pair() do
    GenServer.call(__MODULE__, :get)
  end
end
