defmodule RumblWeb.VideoControllerTest do
  use RumblWeb.ConnCase, async: true

  @valid_attrs %{
    url: "http://youtu.be",
    title: "vid",
    description: "a vid"}
  @invalid_attrs %{title: nil, description: nil, url: nil}

  test "requires user authentication on all actions", %{conn: conn} do
    Enum.each([
      get(conn, Routes.video_path(conn, :new)),
      get(conn, Routes.video_path(conn, :index)),
      get(conn, Routes.video_path(conn, :show, "123")),
      get(conn, Routes.video_path(conn, :edit, "123")),
      put(conn, Routes.video_path(conn, :update, "123", %{})),
      post(conn, Routes.video_path(conn, :create, %{})),
      delete(conn, Routes.video_path(conn, :delete, "123")),
    ], fn conn ->
      assert html_response(conn, 302)
      assert conn.halted
    end)
  end

  test "authorizes actions against access by other users", %{conn: conn} do
    owner = user_fixture(username: "owner")
    video = video_fixture(owner, @valid_attrs)
    non_owner = user_fixture(username: "sneaky")
    conn = assign(conn, :current_user, non_owner)

    assert_error_sent :not_found, fn ->
      get(conn, Routes.video_path(conn, :show, video))
    end
    assert_error_sent :not_found, fn ->
      get(conn, Routes.video_path(conn, :edit, video))
    end
    assert_error_sent :not_found, fn ->
      put(conn, Routes.video_path(conn, :update, video, video: @valid_attrs))
    end
    assert_error_sent :not_found, fn ->
      delete(conn, Routes.video_path(conn, :delete, video))
    end
  end

  describe "with a logged-in user" do
    alias Rumbl.Multimedia

    setup %{conn: conn, login_as: username} do
      # `@tag login_as: ...` is only needed because of :login_as here in setup
      # which is used as passing a string/data for user_fixture/1
      user = user_fixture(username: username)
      conn = assign(conn, :current_user, user)

      {:ok, conn: conn, user: user}
    end

    defp video_count, do: Enum.count(Multimedia.list_videos())

    @tag login_as: "user1"
    test "creates user video and redirects", %{conn: conn, user: user} do
      create_conn = post conn, Routes.video_path(conn, :create), video: @valid_attrs
      assert %{id: id} = redirected_params(create_conn) # checks if redirect has params (id)
      assert redirected_to(create_conn) == Routes.video_path(create_conn, :show, id) # checks if redirect url is same

      conn = get conn, Routes.video_path(conn, :show, id)
      assert html_response(conn, 200) =~ "Show Video"
      assert Multimedia.get_video!(id).user_id == user.id
    end

    @tag login_as: "user2"
    test "does not create vid, renders errors when invalid", %{conn: conn} do
      # video_fixture(conn.assigns.current_user)
      count_before = video_count()

      conn = post conn, Routes.video_path(conn, :create), video: @invalid_attrs
      assert html_response(conn, 200) =~ "check the errors"
      assert video_count() == count_before
    end

    @tag login_as: "user2"
    test "lists all user's videos on index", %{conn: conn, user: user} do
      user_video = video_fixture(user, title: "video")
      other_video = video_fixture( user_fixture(username: "other"), title: "another video")

      conn = get conn, Routes.video_path(conn, :index)
      assert html_response(conn, 200) =~ ~r/Listing Videos/
      assert String.contains?(conn.resp_body, user_video.title)
      refute String.contains?(conn.resp_body, other_video.title)
    end
  end

end
