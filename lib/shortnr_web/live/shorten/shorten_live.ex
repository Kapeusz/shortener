defmodule ShortnrWeb.Shorten.ShortenLive do
  use ShortnrWeb, :live_view

  alias Shortnr.Urls

  defmodule Form do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :long_url, :string
    end

    def changeset(attrs \\ %{}), do: changeset(%__MODULE__{}, attrs)

    def changeset(%__MODULE__{} = form, attrs) do
      form
      |> cast(attrs, [:long_url])
      |> validate_required([:long_url])
      |> validate_change(:long_url, fn :long_url, value ->
        uri = URI.parse(value)

        cond do
          is_nil(uri.scheme) or uri.scheme not in ["http", "https"] ->
            [long_url: "must start with http or https"]

          is_nil(uri.host) or uri.host == "" ->
            [long_url: "must include a host"]

          true ->
            []
        end
      end)
    end
  end

  def mount(_params, _session, socket) do
    changeset = Form.changeset(%{})
    urls = Urls.list_urls()
    base_url = ShortnrWeb.Endpoint.url()

    if connected?(socket), do: Phoenix.PubSub.subscribe(Shortnr.PubSub, "redirects")

    {:ok,
     socket
     |> assign(:page_title, "Shorten URL")
     |> assign(:changeset, changeset)
     |> assign(:base_url, base_url)
     |> assign(:urls, urls)}
  end

  def handle_event("validate", %{"url" => url_params}, socket) do
    changeset =
      url_params
      |> Form.changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"url" => url_params}, socket) do
    case Urls.create_shortened_url(%{long_url: Map.get(url_params, "long_url")}) do
      {:ok, _url} ->
        urls = Urls.list_urls()
        changeset = Form.changeset(%{})

        {:noreply,
         socket
         |> put_flash(:info, "Short URL created")
         |> assign(:changeset, changeset)
         |> assign(:urls, urls)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, to_string(reason))}
    end
  end

  # Live update redirect counts when redirects happen
  def handle_info({:redirect, %{slug: slug}}, socket) do
    urls =
      Enum.map(socket.assigns.urls, fn u ->
        if u.shortened_url == slug, do: %{u | redirect_count: u.redirect_count + 1}, else: u
      end)

    {:noreply, assign(socket, :urls, urls)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-semibold text-zinc-900">Shorten URL</h1>
        <.link
          navigate={~p"/admins/metrics"}
          class="inline-flex items-center rounded-md bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-sm font-semibold text-white"
        >
          View Metrics
        </.link>
      </div>

      <div class="bg-white rounded-lg border p-4">
        <.simple_form :let={f} for={@changeset} as={:url} phx-change="validate" phx-submit="save">
          <.input
            field={f[:long_url]}
            type="url"
            label="Long URL"
            placeholder="https://example.com/very/long/path"
            required
          />
          <:actions>
            <.button type="submit">Save</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <h2 class="text-lg font-medium text-zinc-900 mb-2">Existing URLs</h2>
        <.table id="urls" rows={@urls}>
          <:col :let={u} label="Shortened">
            <.link href={~p"/#{u.shortened_url}"} class="font-mono text-indigo-600 hover:underline">
              {@base_url}/{u.shortened_url}
            </.link>
          </:col>
          <:col :let={u} label="Long URL">{u.long_url}</:col>
          <:col :let={u} label="Redirects">{u.redirect_count}</:col>
          <:col :let={u} label="Created At">
            {Calendar.strftime(u.inserted_at, "%Y-%m-%d %H:%M")}
          </:col>
        </.table>
      </div>
    </div>
    """
  end
end
