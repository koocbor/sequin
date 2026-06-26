defmodule Sequin.Sinks.Nats.JetstreamClient do
  @moduledoc false
  @behaviour Sequin.Sinks.NatsJetstream

  alias Sequin.Consumers.NatsJetstreamSink
  alias Sequin.Consumers.SinkConsumer
  alias Sequin.Error
  alias Sequin.NetworkUtils
  alias Sequin.Runtime.Routing.RoutedMessage
  alias Sequin.Sinks.Nats.ConnectionCache
  alias Sequin.Sinks.NatsJetstream

  require Logger

  @impl NatsJetstream
  def send_messages(%SinkConsumer{sink: %NatsJetstreamSink{} = sink} = _consumer, messages) when is_list(messages) do
    with {:ok, connection} <- ConnectionCache.connection(sink) do
      Enum.reduce_while(messages, :ok, fn message, :ok ->
        case publish_message(sink, message, connection) do
          :ok -> {:cont, :ok}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
    end
  end

  @test_timeout 5_000

  @impl NatsJetstream
  def test_connection(%NatsJetstreamSink{} = sink) do
    with :ok <-
           NetworkUtils.test_tcp_reachability(
             sink.host,
             sink.port,
             NatsJetstreamSink.ipv6?(sink),
             to_timeout(second: 10)
           ),
         {:ok, connection} <- ConnectionCache.connection(sink) do
      verify_jetstream_enabled(connection)
    end
  catch
    :exit, error ->
      {:error, to_sequin_error(error)}
  end

  @impl NatsJetstream
  def ensure_stream(%NatsJetstreamSink{} = sink) do
    with {:ok, connection} <- ConnectionCache.connection(sink) do
      ensure_stream_with_connection(connection, sink)
    end
  end

  defp ensure_stream_with_connection(connection, sink) do
    stream_name = sink.stream_name || "SEQUIN"

    case Gnat.Jetstream.API.Stream.info(connection, stream_name) do
      {:ok, _info} ->
        :ok

      {:error, %{"code" => 404}} ->
        body = Jason.encode!(%{name: stream_name, subjects: ["sequin.>"]})

        case Gnat.request(connection, "$JS.API.STREAM.CREATE.#{stream_name}", body, receive_timeout: @test_timeout) do
          {:ok, %{body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"error" => error}} ->
                {:error,
                 Error.service(
                   service: :nats,
                   message: "Failed to create JetStream stream \"#{stream_name}\": #{inspect(error)}"
                 )}

              {:ok, _} ->
                Logger.info("Created JetStream stream \"#{stream_name}\" with subject filter \"sequin.>\"")
                :ok

              {:error, _} ->
                :ok
            end

          {:error, error} ->
            {:error,
             Error.service(
               service: :nats,
               message: "Failed to create JetStream stream \"#{stream_name}\": #{inspect(error)}"
             )}
        end

      {:error, error} ->
        {:error,
         Error.service(
           service: :nats,
           message: "Failed to check JetStream stream \"#{stream_name}\": #{inspect(error)}"
         )}
    end
  end

  defp verify_jetstream_enabled(connection) do
    case Gnat.request(connection, "$JS.API.INFO", "", receive_timeout: @test_timeout) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"error" => %{"description" => desc}}} ->
            {:error, Error.service(service: :nats, message: "JetStream is not enabled: #{desc}")}

          {:ok, _info} ->
            :ok

          {:error, _} ->
            :ok
        end

      {:error, :timeout} ->
        {:error,
         Error.service(
           service: :nats,
           message:
             "Failed to verify JetStream is enabled: no response after #{@test_timeout}ms. Verify JetStream is enabled on your NATS server"
         )}

      {:error, _} ->
        {:error,
         Error.service(
           service: :nats,
           message: "Failed to verify JetStream is enabled. Verify JetStream is enabled on your NATS server"
         )}
    end
  end

  defp publish_message(
         %NatsJetstreamSink{publish_timeout_ms: timeout},
         %RoutedMessage{routing_info: %{subject: subject, headers: headers}, transformed_message: transformed_message},
         connection
       ) do
    list_headers =
      case headers do
        %{} ->
          Map.to_list(headers)

        headers when is_list(headers) ->
          headers

        _ ->
          raise "Invalid headers shape. Only maps and lists of tuples are supported. Got: #{inspect(headers)}"
      end

    opts = [headers: list_headers, receive_timeout: timeout]

    try do
      case Gnat.request(connection, subject, Jason.encode_to_iodata!(transformed_message), opts) do
        {:ok, %{body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"error" => error}} ->
              {:error, Error.service(service: :nats, message: "JetStream publish rejected: #{inspect(error)}")}

            {:ok, _ack} ->
              :ok

            {:error, _} ->
              :ok
          end

        {:error, :timeout} ->
          {:error,
           Error.service(
             service: :nats,
             message: "JetStream publish timed out after #{timeout}ms"
           )}

        {:error, error} ->
          {:error, to_sequin_error(error)}
      end
    catch
      error ->
        {:error, to_sequin_error(error)}
    end
  end

  defp to_sequin_error(error) do
    case error do
      error when is_binary(error) ->
        Error.service(service: :nats, message: "NATS JetStream error: #{error}")

      _ ->
        Error.service(service: :nats, message: "Unknown NATS JetStream error")
    end
  end
end
