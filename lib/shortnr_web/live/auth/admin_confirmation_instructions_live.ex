defmodule ShortnrWeb.Auth.AdminConfirmationInstructionsLive do
  use ShortnrWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Email confirmation disabled
        <:subtitle>Contact an administrator if you need assistance.</:subtitle>
      </.header>
      <p class="text-center mt-4">
        <.link href={~p"/admins/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
