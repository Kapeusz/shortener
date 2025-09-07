defmodule ShortnrWeb.Admin.TargetMapLive do
  use ShortnrWeb, :live_view

  alias Shortnr.Metrics.Geo, as: MetricsGeo

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    locations = MetricsGeo.recent_locations(slug, 200)
    marker_count = count_markers(locations)

    if connected?(socket), do: Phoenix.PubSub.subscribe(Shortnr.PubSub, "geo:#{slug}")

    {:ok,
     socket
     |> assign(:page_title, "Locations: #{slug}")
     |> assign(:slug, slug)
     |> assign(:locations, encode_locations(locations))
     |> assign(:marker_count, marker_count)
     |> assign(
       :gmap_key,
       System.get_env("GOOGLE_MAPS_API_KEY") || ""
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:geo, %{lat: lat, lng: lng}}, socket) do
    socket = push_event(socket, "add-marker", %{lat: lat, lng: lng})
    {:noreply, update(socket, :marker_count, &(&1 + 1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>Locations for {@slug}</.header>
    <%= if @gmap_key == "" do %>
      <p class="text-sm text-red-600">GOOGLE_MAPS_API_KEY is not set; map cannot load.</p>
    <% end %>

    <div
      id="map"
      phx-hook="GoogleMap"
      data-markers={@locations}
      data-api-key={@gmap_key}
      class="w-full h-96 rounded border"
    >
    </div>
    <p class="mt-2 text-xs text-zinc-600">Markers found: {@marker_count}</p>
    """
  end

  defp encode_locations(list) do
    markers =
      for rl <- list do
        case rl.geom do
          %Geo.Point{coordinates: {lng, lat}} -> %{lat: lat, lng: lng}
          _ -> nil
        end
      end
      |> Enum.reject(&is_nil/1)

    Jason.encode!(markers)
  end

  defp count_markers(list) do
    Enum.count(list, fn rl -> match?(%Geo.Point{}, rl.geom) end)
  end
end
