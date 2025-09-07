defmodule ShortnrWeb.Auth.AdminRegistrationLive do
  use ShortnrWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Registration disabled
        <:subtitle>Accounts are provisioned by an administrator.</:subtitle>
      </.header>
      <p class="text-center mt-4">
        <.link navigate={~p"/admins/log_in"} class="font-semibold text-brand hover:underline">
          Log in
        </.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
