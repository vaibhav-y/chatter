defmodule TwitterClient.SocketClient do
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient

  def start_link do
    GenSocketClient.start_link(
          __MODULE__,
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          "ws://localhost:4000/socket/websocket"
        )
  end

  def register(pid, user_handle) do
    send pid, {:register, user_handle}
  end

  def follow(pid, src_handle, target_handle) do
    send pid, {:follow, src_handle, target_handle}
  end

  def tweet(pid, ahandle, message) do
    send pid, {:tweet, ahandle, message}
  end

  def retweet(pid, user_handle, tweet_id) do
    send pid, {:retweet, user_handle, tweet_id}
  end

  def query_tag(pid, user_handle, tag) do
    send pid, {:query_tag, user_handle, tag}
  end

  def init(url) do
    {:connect, url, [], %{first_join: true}}
  end

  def handle_connected(transport, state) do
    Logger.info("connected")
    GenSocketClient.join(transport, "user:*")
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.error("disconnected: #{inspect reason}")
    Process.send_after(self(), :connect, :timer.seconds(1))
    {:ok, state}
  end

  def handle_joined(topic, _payload, _transport, state) do
    Logger.info("joined the topic #{topic}")
    if state.first_join do
      {:ok, %{state | first_join: false}}
    else
      {:ok, state}
    end
  end

  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("join error on the topic #{topic}: #{inspect payload}")
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("disconnected from the topic #{topic}: #{inspect payload}")
    Process.send_after(self(), {:join, topic}, :timer.seconds(2))
    {:ok, state}
  end

  def handle_info(:connect, _transport, state) do
    Logger.info("connecting")
    {:connect, state}
  end

  def handle_info({:register, user_handle}, transport, state) do
    this = self()
    GenSocketClient.push(transport, "user:*", "create_user", %{handle: user_handle})
    {:ok, state}
  end

  def handle_info({:follow, src_handle, target_handle}, transport, state) do
    GenSocketClient.push(transport, "user:*", "follow", %{src: src_handle, tgt: target_handle})
    {:ok, state}
  end

  def handle_info({:tweet, author, message}, transport, state) do
    GenSocketClient.push(transport, "user:*", "new_tweet", %{author: author, content: message})
    {:ok, state}
  end

  def handle_info({:retweet, author, id}, transport, state) do
    GenSocketClient.push(transport, "user:*", "retweet", %{author: author, id: id})
    {:ok, state}
  end

  def handle_info({:query_tag, user_handle, tag}, transport, state) do
    GenSocketClient.push(transport, "user:*", "query_tag", %{tag: tag, handle: user_handle})
    {:ok, state}
  end

  def handle_message("user:*", "new_follower", %{"handle" => handle, "id" => id}, _transport, state) do
    Logger.info("\nUser @#{handle}(id=#{id}) started following you!\n")
    {:ok, state}
  end

  def handle_message("user:*", "new_tweet", %{"author" => author, "content" => text, "id" => id}, _transport, state) do
    Logger.info("\n@#{author} tweeted(id=#{id}): #{text}\n")
    {:ok, state}
  end

  def handle_message("user:*", "retweet", %{"handle" => uhandle, "tweet" => tweet}, _transport, state) do
    Logger.info("\nUser @#{uhandle} retweeted your tweet(id=#{Map.get(tweet, "id")}): #{Map.get(tweet, "text")}\n")
    {:ok, state}
  end

  def handle_message("user:*", "query_tag", %{"tweets" => msgs}, _transport, state) do
    Logger.info("\n#{inspect(msgs)}\n")
    {:ok, state}
  end

  # Kept to display Unhandled / misc messages
  def handle_message(topic, event, payload, _transport, state) do
    Logger.warn("message on topic #{topic}: #{event} #{inspect payload}")
    {:ok, state}
  end

  def handle_reply(topic, _ref, payload, _transport, state) do
    Logger.warn("reply on topic #{topic}: #{inspect payload}")
    {:ok, state}
  end

  def handle_info(message, _transport, state) do
    Logger.warn("Unhandled message #{inspect message}")
    {:ok, state}
  end
end
