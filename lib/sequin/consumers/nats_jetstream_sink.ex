defmodule Sequin.Consumers.NatsJetstreamSink do
  @moduledoc false
  use Ecto.Schema
  use TypedEctoSchema

  import Ecto.Changeset

  alias Sequin.Encrypted.Field, as: EncryptedField

  @derive {Jason.Encoder, only: [:host, :port, :stream_name, :domain]}
  @derive {Inspect, except: [:password, :jwt, :nkey_seed]}
  @primary_key false
  typed_embedded_schema do
    field :type, Ecto.Enum, values: [:nats_jetstream], default: :nats_jetstream
    field :host, :string
    field :port, :integer
    field :username, :string
    field :password, EncryptedField
    field :jwt, EncryptedField
    field :nkey_seed, EncryptedField
    field :tls, :boolean, default: false
    field :stream_name, :string
    field :domain, :string
    field :publish_timeout_ms, :integer, default: 5_000
    field :connection_id, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :host,
      :port,
      :username,
      :password,
      :jwt,
      :nkey_seed,
      :tls,
      :stream_name,
      :domain,
      :publish_timeout_ms
    ])
    |> validate_required([:host, :port])
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> validate_number(:publish_timeout_ms, greater_than: 0, less_than_or_equal_to: 60_000)
    |> validate_length(:stream_name, max: 255)
    |> validate_format(:stream_name, ~r/^[a-zA-Z0-9_-]+$/,
      message: "must contain only alphanumeric characters, hyphens, and underscores"
    )
    |> put_connection_id()
  end

  defp put_connection_id(changeset) do
    case get_field(changeset, :connection_id) do
      nil -> put_change(changeset, :connection_id, Ecto.UUID.generate())
      _ -> changeset
    end
  end

  def connection_opts(%__MODULE__{} = sink) do
    %{
      host: sink.host,
      port: sink.port,
      username: sink.username,
      password: sink.password,
      jwt: sink.jwt,
      nkey_seed: sink.nkey_seed,
      tls: sink.tls
    }
  end

  def ipv6?(%__MODULE__{} = sink) do
    case :inet.getaddr(to_charlist(sink.host), :inet) do
      {:ok, _} -> false
      {:error, _} -> true
    end
  end
end
