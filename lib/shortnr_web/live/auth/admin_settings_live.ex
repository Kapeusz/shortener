defmodule ShortnrWeb.Auth.AdminSettingsLive do
  use ShortnrWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Settings disabled
      <:subtitle>Contact an administrator if you need assistance.</:subtitle>
    </.header>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
