defmodule ShortnrWeb.Auth.AdminSessionController do
  use ShortnrWeb, :controller

  plug ShortnrWeb.Plugs.RateLimit,
       [label: "login", limit: 5, scale_ms: 60_000, by: :ip]
       when action in [:create]

  alias Shortnr.Accounts
  alias ShortnrWeb.AdminAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    # Settings page is disabled; return to home instead.
    |> put_session(:admin_return_to, ~p"/")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"admin" => admin_params}, info) do
    %{"email" => email, "password" => password} = admin_params

    if admin = Accounts.get_admin_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> AdminAuth.log_in_admin(admin, admin_params)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/admins/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AdminAuth.log_out_admin()
  end
end
