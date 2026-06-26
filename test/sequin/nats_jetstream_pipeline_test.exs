defmodule Sequin.Runtime.NatsJetstreamPipelineTest do
  use Sequin.DataCase, async: true

  alias Sequin.Consumers
  alias Sequin.Error
  alias Sequin.Factory.ConsumersFactory
  alias Sequin.Runtime.SinkPipeline
  alias Sequin.Sinks.NatsJetstreamMock

  describe "message handling" do
    setup do
      stub(NatsJetstreamMock, :ensure_stream, fn _sink -> :ok end)

      consumer =
        ConsumersFactory.insert_sink_consumer!(
          type: :nats_jetstream,
          sink: %{
            type: :nats_jetstream,
            host: "localhost",
            port: 4222,
            stream_name: "sequin"
          }
        )

      {:ok, %{consumer: consumer}}
    end

    test "successfully publishes event messages to NATS JetStream", %{consumer: consumer} do
      expect(NatsJetstreamMock, :send_messages, fn _consumer, messages ->
        assert length(messages) == 1
        message = hd(messages)
        assert String.ends_with?(message.routing_info.subject, "insert")
        :ok
      end)

      event =
        ConsumersFactory.consumer_event(
          consumer_id: consumer.id,
          action: :insert
        )

      ref = send_test_event(consumer, event)

      assert_receive {:ack, ^ref, [%{data: %{data: %{action: :insert}}}], []}, 1_000

      refute Consumers.reload(event)
    end

    @tag capture_log: true
    test "handles NATS JetStream publish failures", %{consumer: consumer} do
      expect(NatsJetstreamMock, :send_messages, fn _consumer, _messages ->
        {:error, Error.service(service: :nats, code: "publish_error", message: "JetStream publish failed")}
      end)

      event =
        ConsumersFactory.consumer_event(
          consumer_id: consumer.id,
          action: :insert
        )

      ref = send_test_event(consumer, event)

      assert_receive {:ack, ^ref, [], [_failed]}, 2_000
    end

    test "batches multiple messages together", %{consumer: consumer} do
      consumer = %{consumer | batch_size: 2}

      expect(NatsJetstreamMock, :send_messages, fn _consumer, messages ->
        assert length(messages) == 2

        assert Enum.map(messages, fn message ->
                 message.routing_info.subject |> String.split(".") |> List.last()
               end) == ["insert", "update"]

        :ok
      end)

      event1 =
        ConsumersFactory.consumer_event(
          consumer_id: consumer.id,
          action: :insert
        )

      event2 =
        ConsumersFactory.consumer_event(
          consumer_id: consumer.id,
          action: :update
        )

      ref = send_test_batch(consumer, [event1, event2])

      assert_receive {:ack, ^ref,
                      [
                        %{data: %{data: %{action: :insert}}},
                        %{data: %{data: %{action: :update}}}
                      ], []},
                     1_000
    end
  end

  defp send_test_event(consumer, event) do
    start_supervised!(
      {SinkPipeline,
       [
         consumer_id: consumer.id,
         producer: Broadway.DummyProducer,
         test_pid: self()
       ]}
    )

    Broadway.test_message(
      SinkPipeline.via_tuple(consumer.id),
      event,
      metadata: %{topic: "test_topic", headers: []}
    )
  end

  defp send_test_batch(consumer, events) do
    start_supervised!(
      {SinkPipeline,
       [
         consumer_id: consumer.id,
         producer: Broadway.DummyProducer,
         test_pid: self()
       ]}
    )

    Broadway.test_batch(
      SinkPipeline.via_tuple(consumer.id),
      events,
      metadata: %{topic: "test_topic", headers: []}
    )
  end
end
