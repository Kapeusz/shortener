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

  @impl true
  def mount(params, _session, socket) do
    changeset = Form.changeset(%{})
    base_url = ShortnrWeb.Endpoint.url()

    if connected?(socket), do: Phoenix.PubSub.subscribe(Shortnr.PubSub, "redirects")

    socket =
      socket
      |> assign(:page_title, "Shorten URL")
      |> assign(:changeset, changeset)
      |> assign(:base_url, base_url)
      |> assign(:page, 1)
      |> assign(:per_page, 10)

    {:ok, handle_params(params, nil, socket) |> elem(1)}
  end

  @impl true
  def handle_event("validate", %{"url" => url_params}, socket) do
    changeset =
      url_params
      |> Form.changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"url" => url_params}, socket) do
    case Urls.create_shortened_url(%{long_url: Map.get(url_params, "long_url")}) do
      {:ok, _url} ->
        page = Urls.paginate_urls(socket.assigns.page, socket.assigns.per_page)
        changeset = Form.changeset(%{})

        {:noreply,
         socket
         |> put_flash(:info, "Short URL created")
         |> assign(:changeset, changeset)
         |> assign(:urls, page.entries)
         |> assign(:meta, %{page: page.page_number, per_page: page.page_size, total_pages: page.total_pages, total_count: page.total_entries})}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, to_string(reason))}
    end
  end

  # Live update redirect counts when redirects happen
  @impl true
  def handle_info({:redirect, %{slug: slug}}, socket) do
    urls =
      Enum.map(socket.assigns.urls, fn u ->
        if u.shortened_url == slug, do: %{u | redirect_count: u.redirect_count + 1}, else: u
      end)

    {:noreply, assign(socket, :urls, urls)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page_no = params["page"] |> to_int(1)
    per_page = socket.assigns.per_page
    page = Urls.paginate_urls(page_no, per_page)
    meta = %{page: page.page_number, per_page: page.page_size, total_pages: page.total_pages, total_count: page.total_entries}
    {:noreply, assign(socket, urls: page.entries, meta: meta, page: page.page_number)}
  end

  defp to_int(nil, default), do: default
  defp to_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  @impl true
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
          <:col :let={u} label="Long URL">
            <span class="break-all">{u.long_url}</span>
          </:col>
          <:col :let={u} label="Redirects">{u.redirect_count}</:col>
          <:col :let={u} label="Created At">
            {Calendar.strftime(u.inserted_at, "%Y-%m-%d %H:%M")}
          </:col>
        </.table>
        <div class="flex items-center justify-between mt-3 text-sm">
          <%= if @meta && @meta.page > 1 do %>
            <.link patch={~p"/shorten?#{[page: @meta.page - 1]}"} class="text-indigo-600 hover:underline">Previous</.link>
          <% else %>
            <span class="text-zinc-400">Previous</span>
          <% end %>
          <span class="text-zinc-600">Page {@meta && @meta.page} of {@meta && @meta.total_pages}</span>
          <%= if @meta && @meta.page < @meta.total_pages do %>
            <.link patch={~p"/shorten?#{[page: @meta.page + 1]}"} class="text-indigo-600 hover:underline">Next</.link>
          <% else %>
            <span class="text-zinc-400">Next</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
