# Mistral response fixtures

Except for the two Transcribe 3 checks documented below, `captured-*.json` files
were copied byte for byte, without edits, from
`/Users/atacan/Developer/Repositories/TranscriptionKit/Tests/TranscriptionKitMistralTests/Resources/Responses/`
on 2026-10-25. Their original request/result descriptions are recorded below.
The reproducer is `Tests/TranscriptionKitMistralTests/capture-fixtures.sh` in that
repository. `speech.wav` is the same bundled 4.5-second test clip used by those
requests, copied from its `Resources/speech.wav`.

## Transcribe 3 checks made in this SDK

On 2026-10-25, two explicitly authorized requests uploaded bundled `speech.wav`
(4.5 seconds) to `https://api.mistral.ai/v1/audio/transcriptions` using curl framing.
The responses were saved unedited. Both returned HTTP 200 and their exact requested
model ID. No alternate aliases were checked.

| File | Request | Returned |
| --- | --- | --- |
| `captured-mini-transcribe-3.json` | `model=voxtral-mini-transcribe-3-0`, `file=@speech.wav;type=text/plain;filename=speech.wav` | 200, same model ID, text, empty segments |
| `captured-small-transcribe-3.json` | `model=voxtral-small-transcribe-3-0`, same file part | 200, same model ID, text, empty segments |

The IDs follow the [official audio overview](https://docs.mistral.ai/studio/audio/overview).
To reproduce either request (sends real audio and incurs API usage):

```sh
curl https://api.mistral.ai/v1/audio/transcriptions \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -F model=voxtral-mini-transcribe-3-0 \
  -F 'file=@Tests/MistralAPITests/Resources/speech.wav;type=text/plain;filename=speech.wav'
```

## Legacy SDK fixtures

The exact request/date for the older `sample_*.json` fixtures was not recorded.
`sample_response_with_finish_reason.json` has been restored byte for byte from
before commit `8a8de33`, removing the manually inserted token breakdown.
`sample_response.json` is a 2507 response; `sample_response_with_service_tier.json`
is a latest-model response with usage details. `sample_422_response.json` is the
2025 error saying timestamps and language prediction are incompatible. These are
retained for historical/custom decoding coverage, not represented as new captures.

## Live captures

Captured on 2026-10-25 by the source repository’s `capture-fixtures.sh` from `https://api.mistral.ai`, uploading
`speech.wav` (4.5 s, one speaker) with the file part `text/plain`, as the SDK sends it, or with
Mistral fetching Deepgram's florist call (11.1 s, two speakers) through `file_url`. The source repository’s `statuses.txt`
has each request's HTTP status; the diarize-with-word, comma-separated and `file_url` captures are
from later, filtered runs the same day. (The four `file-url-sdk-body*` lines there are from a run
whose files the bisection replaced: changing the `file_url` part's own headers didn't help.)

| File | Request | Returned |
| --- | --- | --- |
| `captured-2602-segment.json` | `voxtral-mini-2602`, `timestamp_granularities=segment` | Two segments, `speaker_id: null`, `language: null` |
| `captured-2602-word.json` | `timestamp_granularities=word` | 11 chunks of `type: "transcription_segment"`, one per word, with a leading space; no `words` field |
| `captured-2602-segment-word.json` | two `timestamp_granularities` parts, `segment` and `word` | 422: Mistral read the repeated parts as one value, `"segmentword"` |
| `captured-2602-language-segment.json` | `language=en` with `timestamp_granularities=segment` | 200 with segments: the docs' "not compatible" no longer holds for 2602; `language` still `null` |
| `captured-2602-language-en.json` | `language=en`, `temperature=0` | Text only, `segments: []`, `language: null` |
| `captured-2602-diarize-segment-remote.json` | `diarize=true`, `segment`, `file_url` | Four segments with `speaker_1` and `speaker_2` |
| `captured-2602-diarize-remote.json` | `diarize=true`, no timestamps | 422: "When diarize is set to True and streaming is disabled, the timestamp granularity must be set to ['segment']" |
| `captured-2602-diarize-word-remote.json` | `diarize=true`, `word` | 422: the same assertion, "got ['word']" |
| `captured-2602-file-url-text-plain.json` | `file_url` as a `text/plain` form field (curl's framing) | 200: the content type doesn't matter |
| `captured-2602-file-url-bisect-*.json` | Hand-built bodies, boundary `test`, between curl's framing and the SDK's (see the script) | `curl`, `sdk-file-url` and `sdk-others` 200; `trailer` and `sdk` 422 "Either file, file_url or file_id must be provided": with `file_url`, Mistral rejects the CRLF the runtime writes after the closing boundary |
| `captured-latest-context-bias.json` | `voxtral-mini-latest`, two `context_bias` parts | 200, "TranscriptionKit" in the text; `model: "voxtral-mini-latest"` |
| `captured-2602-context-bias-comma.json` | `voxtral-mini-2602`, one part `context_bias=Speechall,TranscriptionKit` | 200, `prompt_tokens` 10 as for the two parts above (the terms count), but the text kept "Transcription Kit": biasing isn't deterministic at the default temperature |
| `captured-2602-context-bias-phrase.json` | `context_bias=Transcription Kit, a Swift package` | 400 code `3051`: items "must not contain commas or whitespace (context_bias_input_method=comma_separated)" |
| `captured-voxtral-mini.json` | `model=voxtral-mini` (the server's provider model name) | 400 `invalid_model` |
| `captured-2507-retired.json` | `model=voxtral-mini-2507` (what the server sends; retired 2026-05-31) | 200, answered by `model: "voxtral-mini-latest"` |
| `captured-error-temperature.json` | `temperature=3` | 422: "Input should be less than or equal to 1.5" |
| `captured-error-unknown-model.json` | `model=voxtral-mini-9999` | 400, `message` a string: "Invalid model: voxtral-mini-9999" |
| `captured-error-401.json` | `Authorization: Bearer invalid` | 401 `{"detail":"Invalid API Key"}` |

Mistral's error bodies include these shapes: `{"object":"error","message":"…"}` (400),
`{"object":"error","message":{"detail":[{"msg":…}]}}` (422, the SDK's `APIError`), `{"object":"error","message":{"message":"…","type":"invalid_request_no_input","code":3050}}`
(422 without detail), and `{"detail":"…"}` (401). Every 400 and 422 body also has `raw_status_code`.

## Synthetic streaming fixture

`synthetic-transcription-stream.sse` is hand-written from the current OpenAPI
schemas, not a live capture. It includes language, text delta, segment, and done
events. The local recording server returns it to both real transports to verify
the request target, explicit stream part, and SSE payload decoding. It does not
prove that Mistral currently emits these exact events.
