defmodule Sequin.Runtime.Routing.Consumers.NatsJetstream do
  @moduledoc false
  use Sequin.Runtime.Routing.RoutedConsumer

  alias Sequin.Runtime.Routing.Consumers.Nats

  @primary_key false
  @derive {Jason.Encoder, only: [:subject]}
  typed_embedded_schema do
    field :subject, :string
    field :headers, :map
  end

  defdelegate changeset(struct, params), to: Nats
  defdelegate route(action, record, changes, metadata), to: Nats
end
