defmodule Phoenix.Controller.FlashTest do
  use ExUnit.Case, async: true
  use RouterHelper
  alias Phoenix.Controller.Flash

  import Phoenix.Controller

  defmodule FlashEndpoint do
    def config(:secret_key_base), do: "abc123"
    def config(:live_view), do: [signing_salt: "liveview_salt456"]
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "flash is persisted when status is a redirect" do
    for status <- 300..308 do
      conn = conn() |> fetch_flash()
                             |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert get_flash(conn, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(recycle_cookies: conn) |> fetch_flash()
      assert get_flash(conn, :notice) == "elixir"
    end
  end

  test "flash is not persisted when status is not redirect" do
    for status <- [299, 309, 200, 404] do
      conn = conn() |> fetch_flash()
                             |> put_flash(:notice, "elixir") |> send_resp(status, "ok")
      assert get_flash(conn, :notice) == "elixir"
      assert get_resp_header(conn, "set-cookie") != []
      conn = conn(recycle_cookies: conn) |> fetch_flash()
      assert get_flash(conn, :notice) == nil
    end
  end

  test "flash does not write to session when it is empty and no session exists" do
    conn =
      conn()
      |> fetch_flash()
      |> clear_flash()
      |> send_resp(302, "ok")

    assert get_resp_header(conn, "set-cookie") == []
  end

  test "flash writes to session when it is empty and a previous session exists" do
    persisted_flash_conn =
      conn()
      |> fetch_flash()
      |> put_flash(:info, "existing")
      |> send_resp(302, "ok")

    conn =
      conn(recycle_cookies: persisted_flash_conn)
      |> fetch_flash()
      |> clear_flash()
      |> send_resp(200, "ok")

    assert ["_app=" <> _] = get_resp_header(conn, "set-cookie")
  end

  test "get_flash/1 raises ArgumentError when flash not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn() |> get_flash()
    end
  end

  test "get_flash/1 returns the map of messages" do
    conn = conn() |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert get_flash(conn) == %{"notice" => "hi"}
  end

  test "get_flash/2 returns the message by key" do
    conn = conn() |> fetch_flash([]) |> put_flash(:notice, "hi")
    assert get_flash(conn, :notice) == "hi"
    assert get_flash(conn, "notice") == "hi"
  end

  test "get_flash/2 returns nil for missing key" do
    conn = conn() |> fetch_flash([])
    assert get_flash(conn, :notice) == nil
    assert get_flash(conn, "notice") == nil
  end

  test "put_flash/3 raises ArgumentError when flash not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn() |> put_flash(:error, "boom!")
    end
  end

  test "put_flash/3 adds the key/message pair to the flash" do
    conn =
      conn()
      |> fetch_flash([])
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    assert get_flash(conn, :error) == "oh noes!"
    assert get_flash(conn, "error") == "oh noes!"
    assert get_flash(conn, :notice) == "false alarm!"
    assert get_flash(conn, "notice") == "false alarm!"
  end

  test "clear_flash/1 clears the flash messages" do
    conn =
      conn()
      |> fetch_flash([])
      |> put_flash(:error, "oh noes!")
      |> put_flash(:notice, "false alarm!")

    refute get_flash(conn) == %{}
    conn = clear_flash(conn)
    assert get_flash(conn) == %{}
  end

  test "fetch_flash/2 raises ArgumentError when session not previously fetched" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/") |> fetch_flash([])
    end
  end

  test "fetch based on the cookie" do
    flash = Flash.sign_token(FlashEndpoint, "liveview_salt456", %{notice: "hi"})
    conn = conn(flash_cookie: flash) |> fetch_flash()
    assert get_flash(conn, :notice) == "hi"
    assert get_flash(conn, "notice") == "hi"
  end

  defp conn(opts \\ []) do
    conn = conn(:get, "/")

    conn = case opts[:recycle_cookies] do
      nil -> conn
      old_conn -> conn |> recycle_cookies(old_conn)
    end

    conn = case opts[:flash_cookie] do
      nil -> conn
      token -> conn |> put_req_cookie("__phoenix_flash___", token <> "; max-age=60000; path=/")
    end

    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, FlashEndpoint)
    |> with_session()
  end

end
