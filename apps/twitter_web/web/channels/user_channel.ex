defmodule TwitterWeb.UserChannel do
  use Phoenix.Channel

  alias TwitterEngine.{User, CoreApi, Tweet}
  require Logger

  Phoenix.Channel.intercept ["new_tweet"]

  def join("user:*", _message, socket) do
    {:ok, socket}
  end

  def join(_room, _params, _socket) do
    {:error, "Must join a room related to some user"}
  end

  ##
  # INCOMING SOCKET MESSAGES
  ##
  def handle_in("create_user", %{"handle" => uhandle}, socket) do
    me = self()
    user = %TwitterEngine.User{handle: uhandle, chan: me}
    CoreApi.insert_user(user)
    {:noreply, socket}
  end

  def handle_in("follow", %{"src" => src, "tgt" => tgt}, socket) do
    target = CoreApi.get_user_by_handle(tgt)
    source = CoreApi.get_user_by_handle(src)

    CoreApi.add_follower(target.id, source.id)

    send(target.chan, {:followed_by, source})
    {:noreply, socket}
  end

  def handle_in("new_tweet", %{"author" => author, "content" => msg}, socket) do
    user = CoreApi.get_user_by_handle(author)
    tweet_id = CoreApi.create_tweet(user.id, msg)

    CoreApi.get_followers(user.id)
    |> Enum.map(fn id -> CoreApi.get_user(id) end)
    |> Enum.each(fn user -> send(user.chan, {:new_tweet, author, msg, tweet_id}) end)

    {:noreply, socket}
  end

  ##
  # INFO
  ##
  def handle_info({:followed_by, source}, socket) do
    push socket, "new_follower", %{handle: source.handle, id: source.id}
    {:noreply, socket}
  end

  def handle_info({:new_tweet, author, msg, tweet_id}, socket) do
    push socket, "new_tweet", %{author: author, content: msg, id: tweet_id}
    {:noreply, socket}
  end
end
