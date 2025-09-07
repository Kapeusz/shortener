defmodule ShortnrWeb.RedirectController do
  use ShortnrWeb, :controller
  alias Shortnr.Urls

  def show(conn, %{"slug" => slug}) do
    case Urls.get_active_by_slug(slug) do
      nil ->
        conn
        |> put_flash(:error, "Link not found or expired")
        |> redirect(to: "/")

      url ->
        publish_redirect_event(conn, slug)

        if Application.get_env(:shortnr, :geo_capture, true) do
          render(conn, :geo_capture, slug: slug, long_url: url.long_url)
        else
          redirect(conn, external: url.long_url)
        end
    end
  end

  defp publish_redirect_event(conn, slug) do
    ua = get_req_header(conn, "user-agent") |> List.first()
    ip = remote_ip_string(conn)

    Phoenix.PubSub.broadcast(
      Shortnr.PubSub,
      "redirects",
      {:redirect, %{slug: slug, user_agent: ua, ip: ip, at: DateTime.utc_now()}}
    )
  end

  @spec remote_ip_string(Plug.Conn.t()) :: String.t() | nil
  defp remote_ip_string(conn) do
    case conn.remote_ip do
      {_, _, _, _} = tuple -> tuple |> :inet.ntoa() |> to_string()
      {_, _, _, _, _, _, _, _} = tuple -> tuple |> :inet.ntoa() |> to_string()
    end
  end
end
