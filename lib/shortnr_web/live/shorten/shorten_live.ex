defmodule ShortnrWeb.Shorten.ShortenLive do
  use ShortnrWeb, :live_view

  alias Shortnr.Urls
  alias Shortnr.Urls.Url

  def mount(_params, _session, socket) do
    changeset = Url.changeset(%Url{}, %{})
    urls = Urls.list_urls()

    {:ok,
     socket
     |> assign(:page_title, "Shorten URL")
     |> assign(:changeset, changeset)
     |> assign(:urls, urls)}
  end

  def handle_event("validate", %{"url" => url_params}, socket) do
    changeset =
      %Url{}
      |> Urls.change_url(url_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"url" => url_params}, socket) do
    case Urls.create_url(url_params) do
      {:ok, _url} ->
        urls = Urls.list_urls()
        changeset = Urls.change_url(%Url{})

        {:noreply,
         socket
         |> put_flash(:info, "URL created")
         |> assign(:changeset, changeset)
         |> assign(:urls, urls)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <.header>Create Shortened URL</.header>

    <.simple_form :let={f} for={@changeset} as={:url} phx-change="validate" phx-submit="save">
      <.input
        field={f[:long_url]}
        type="url"
        label="Long URL"
        placeholder="https://example.com/very/long/path"
        required
      />
      <.input
        field={f[:shortened_url]}
        type="text"
        label="Shortened Slug"
        placeholder="e.g. exmpl"
        required
      />
      <:actions>
        <.button type="submit">Save</.button>
      </:actions>
    </.simple_form>

    <.header class="mt-10">Existing URLs</.header>
    <.table id="urls" rows={@urls}>
      <:col :let={u} label="Shortened">{u.shortened_url}</:col>
      <:col :let={u} label="Long URL">{u.long_url}</:col>
      <:col :let={u} label="Redirects">{u.redirect_count}</:col>
      <:col :let={u} label="Created At">{Calendar.strftime(u.inserted_at, "%Y-%m-%d %H:%M")}</:col>
    </.table>
    """
  end
end
