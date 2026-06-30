# Event Ingestion Pipeline

## Problem/Feature Description

Your team operates a data platform that receives real-time events from third-party partners — webhook deliveries, IoT sensor readings, and user activity streams — all arriving through a shared message bus. Over the past month, two production incidents were traced back to the same root cause: malformed payloads from a misbehaving partner brought down a processing worker because unhandled errors propagated as exceptions, crashing the process. Worse, there was no record of which messages were rejected or why, making post-incident forensics nearly impossible.

You have been asked to rebuild the event ingestion layer using Broadway. The new pipeline must be resilient: bad messages must not crash workers, rejected messages must be tracked with enough structured context to support later replay or investigation, and the pipeline process itself must be owned by the application supervision tree so it restarts cleanly after any failure. The events being consumed have a known schema (each message is a JSON-like map with required string fields `"event_type"` and `"source_id"`, plus an integer `"timestamp"`); anything that deviates must be rejected before it reaches the batch stage.

## Output Specification

Write the following files:

- `lib/my_app/event_pipeline.ex` — the Broadway pipeline module implementing the full Broadway behaviour, including message processing and batching.
- `lib/my_app/application.ex` — the OTP Application module that adds the pipeline to the supervision tree.
- `test/my_app/event_pipeline_test.exs` — an ExUnit test file that exercises at least a valid-message path and a malformed-message path.

The test file should demonstrate how to push test messages into the pipeline and assert on the outcomes.
