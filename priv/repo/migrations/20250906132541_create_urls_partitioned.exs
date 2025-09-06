defmodule Shortnr.Repo.Migrations.CreateUrlsPartitioned do
  use Ecto.Migration

  def change do
    modulus = 32
    # Partitioned parent table (hash partitioning by shortened_url)
    execute(
      """
      CREATE TABLE urls (
        shortened_url text PRIMARY KEY,
        long_url text NOT NULL,
        redirect_count bigint NOT NULL DEFAULT 0,
        expires_at timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
        inserted_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT shortened_url_len CHECK (char_length(shortened_url) BETWEEN 4 AND 32),
        CONSTRAINT shortened_url_charset CHECK (shortened_url ~ '^[A-Za-z0-9_-]+$'),
        CONSTRAINT expires_after_insert CHECK (expires_at > inserted_at)
      ) PARTITION BY HASH (shortened_url);
      """,
      "DROP TABLE IF EXISTS urls CASCADE"
    )

    #  Hash partitions to start with (over-provision to avoid rehashing later)
    for remainder <- 0..(modulus - 1) do
      execute(
        """
        CREATE TABLE urls_p#{remainder}
        PARTITION OF urls
        FOR VALUES WITH (MODULUS #{modulus}, REMAINDER #{remainder})
        WITH (fillfactor = 90);
        """,
        "DROP TABLE IF EXISTS urls_p#{remainder}"
      )
    end

    # Index to help purge or query by expiration
    create index(:urls, [:expires_at])
  end
end
