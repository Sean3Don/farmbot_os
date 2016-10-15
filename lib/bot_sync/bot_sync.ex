defmodule BotSync do
  use GenServer
  require Logger
  def init(_args) do
    {:ok, %{token: nil, resources: nil }}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_cast(_, %{token: nil, resources: _}) do
    Logger.debug("Don't have a token yet.")
    spawn fn -> try_to_get_token end
    {:noreply, %{token: nil, resources: nil}}
  end

  def handle_cast(:sync, %{token: token, resources: _}) do
    server = Map.get(token, "unencoded") |> Map.get("iss")
    auth = Map.get(token, "encoded")

    case HTTPotion.get "#{server}/api/sync",
    [headers: ["Content-Type": "application/json",
               "Authorization": "Bearer " <> auth]] do

     %HTTPotion.Response{body: body,
                         headers: _headers,
                         status_code: 200} ->
       RPCMessageHandler.log("Synced")
       {:noreply, %{token: token, resources: Poison.decode!(body)}}
     error ->
       Logger.debug("Couldn't get resources: #{error}")
       RPCMessageHandler.log("Couldn't sync: #{error}")
       {:noreply, %{token: token, resources: %{}}}
    end
  end

  def handle_call({:token, token}, _from, %{token: _, resources: _}) do
    {:reply, :ok, %{token: token, resources: nil}}
  end

  def handle_call(_,_from, %{token: nil, resources: _}) do
    Logger.debug("Please make sure you have a token first.")
    {:reply, :no_token, %{token: nil, resources: nil}}
  end

  def handle_call({:save_sequence, seq}, _from, %{token: token, resources: resources}) do
    new_resources = Map.put(resources, "sequences", [seq | Map.get(resources, "sequences")] )
    {:reply, :ok, %{token: token, resources: new_resources}}
  end

  def handle_call(:fetch, _from, %{token: token, resources: resources}) do
    {:reply, resources, %{token: token, resources: resources}}
  end

  def handle_call({:get_sequence, id}, _from, %{token: token, resources: resources}) do
    sequences = Map.get(resources, "sequences")
    got = Enum.find(sequences, fn(sequence) -> Map.get(sequence, "id") == id end)
    {:reply, got, %{token: token, resources: resources}}
  end

  def handle_call(:get_sequences, _from, %{token: token, resources: resources}) do
    sequences = Map.get(resources, "sequences")
    {:reply, sequences, %{token: token, resources: resources}}
  end

  def handle_call({:get_regimen, id}, _from, %{token: token, resources: resources}) do
    regimens = Map.get(resources, "regimens")
    got = Enum.find(regimens, fn(regimen) -> Map.get(regimen, "id") == id end)
    {:reply, got, %{token: token, resources: resources}}
  end

  def handle_call(:get_regimens, _from, %{token: token, resources: resources}) do
    regimens = Map.get(resources, "regimens")
    {:reply, regimens, %{token: token, resources: resources}}
  end


  def sync do
    GenServer.cast(__MODULE__, :sync)
  end

  def fetch do
    GenServer.call(__MODULE__, :fetch)
  end

  def get_sequence(id) when is_integer(id) do
    GenServer.call(__MODULE__, {:get_sequence, id})
  end

  def get_sequences do
    GenServer.call(__MODULE__, :get_sequences)
  end

  def get_regimen(id) when is_integer(id) do
    GenServer.call(__MODULE__, {:get_regimen, id})
  end

  def get_regimens do
    GenServer.call(__MODULE__, :get_regimens)
  end

  def try_to_get_token do
    case Auth.get_token do
      nil -> try_to_get_token
      {:error, reason} -> {:error, reason}
      token -> GenServer.call(__MODULE__, {:token, token})
    end
  end
end
