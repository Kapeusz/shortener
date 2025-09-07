defmodule ShortnrWeb.Admin.MetricsLive do
  use ShortnrWeb, :live_view

  alias Shortnr.{Repo}
  alias Shortnr.Metrics.{UA, Location}
  alias Shortnr.Metrics.RedirectEvent
  import Ecto.Query

  @max_events 10_000

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Shortnr.PubSub, "redirects")

    {totals, by_browser, by_location} = initial_aggregates()

    {:ok,
     socket
     |> assign(:page_title, "Usage Metrics")
     |> assign(:totals, totals)
     |> assign(:by_browser, by_browser)
     |> assign(:by_location, by_location)
     |> assign(:selected, nil)}
  end

  def handle_info({:redirect, %{slug: slug, user_agent: ua, ip: ip}}, socket) do
    totals = Map.update(socket.assigns.totals, slug, 1, &(&1 + 1))
    by_browser = update_nested(socket.assigns.by_browser, slug, UA.browser(ua))
    by_location = update_nested(socket.assigns.by_location, slug, Location.bucket(ip))
    selected = socket.assigns.selected || slug

    {:noreply,
     assign(socket,
       totals: totals,
       by_browser: by_browser,
       by_location: by_location,
       selected: selected
     )}
  end

  def handle_event("select", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :selected, slug)}
  end

  def render(assigns) do
    ~H"""
    <.header>Real-time Usage Metrics</.header>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <h3 class="font-semibold mb-2">Totals</h3>
        <.table id="totals" rows={Enum.sort_by(@totals, &elem(&1, 1), :desc)}>
          <:col :let={{slug, _cnt}} label="Slug">
            <button
              phx-click="select"
              phx-value-slug={slug}
              class="text-indigo-600 hover:underline font-mono"
            >
              {slug}
            </button>
          </:col>
          <:col :let={{_slug, cnt}} label="Redirects">{cnt}</:col>
        </.table>
      </div>

      <div>
        <%= if @selected do %>
          <h3 class="font-semibold mb-2">Breakdown for {@selected}</h3>
          <div class="mb-3">
            <.link navigate={~p"/admins/targets/#{@selected}"} class="text-indigo-600 hover:underline">
              View locations on map
            </.link>
          </div>
          <div class="mb-4">
            <h4 class="font-medium">Browsers</h4>
            <%= for {label, val} <- top5(@by_browser[@selected]) do %>
              <.bar label={label} value={val} total={total(@by_browser[@selected])} />
            <% end %>
          </div>
          <div>
            <h4 class="font-medium">Addresses</h4>
            <%= for {label, val} <- top5(@by_location[@selected]) do %>
              <.bar label={label} value={val} total={total(@by_location[@selected])} />
            <% end %>
          </div>
        <% else %>
          <p class="text-sm text-zinc-600">Select a slug to see details.</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :total, :integer, required: true

  defp bar(assigns) do
    ~H"""
    <div class="my-1">
      <div class="flex justify-between text-xs">
        <span>{@label}</span>
        <span>{@value}</span>
      </div>
      <div class="w-full bg-zinc-200 h-2 rounded">
        <div class="bg-indigo-500 h-2 rounded" style={"width: #{percent(@value, @total)}%"}></div>
      </div>
    </div>
    """
  end

  defp percent(_v, 0), do: 0
  defp percent(v, t), do: Float.round(v * 100 / t, 1)

  defp initial_aggregates do
    # Pull last @max_events for initial state to avoid scanning entire table
    events =
      Repo.all(
        from e in RedirectEvent,
          order_by: [desc: e.inserted_at],
          limit: ^@max_events
      )

    totals =
      Enum.reduce(events, %{}, fn e, acc -> Map.update(acc, e.shortened_url, 1, &(&1 + 1)) end)

    by_browser =
      Enum.reduce(events, %{}, fn e, acc ->
        update_nested(acc, e.shortened_url, UA.browser(e.user_agent))
      end)

    by_location =
      Enum.reduce(events, %{}, fn e, acc ->
        update_nested(acc, e.shortened_url, Location.bucket(e.ip))
      end)

    {totals, by_browser, by_location}
  end

  defp total(nil), do: 0
  defp total(map) when is_map(map), do: Enum.reduce(map, 0, fn {_k, v}, acc -> acc + v end)

  defp top5(nil), do: []

  defp top5(map) when is_map(map) do
    map |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(5)
  end

  defp update_nested(map, slug, key) do
    nested = Map.get(map, slug) || %{}
    nested = Map.update(nested, key, 1, &(&1 + 1))
    Map.put(map, slug, nested)
  end
end
