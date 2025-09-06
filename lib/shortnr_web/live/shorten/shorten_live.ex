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

  def render(assigns) do
    ~H"""
    <.header>Admin: Create Shortened URL</.header>

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

    <.header class="mt-10">Existing URLs</.header>
    <.table id="urls" rows={@urls}>
      <:col :let={u} label="Shortened">
        <span class="font-mono">{@base_url}/{u.shortened_url}</span>
      </:col>
      <:col :let={u} label="Long URL">{u.long_url}</:col>
      <:col :let={u} label="Redirects">{u.redirect_count}</:col>
      <:col :let={u} label="Created At">{Calendar.strftime(u.inserted_at, "%Y-%m-%d %H:%M")}</:col>
    </.table>
    """
  end
end
