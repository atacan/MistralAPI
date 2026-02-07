// Source:
//  - https://docs.mistral.ai/getting-started/models/compare?models=voxtral-mini-transcribe-26-02,voxtral-mini-transcribe-25-07,voxtral-small-25-07
//  - https://mistral.ai/pricing#api
public enum MistralModelID {
    public enum Transcription {
        /// Voxtral Mini Transcribe (voxtral-mini-latest via audio/transcriptions), with an efficient transcription only service.
        public static let voxtralMiniLatest = "voxtral-mini-latest"
        /// Voxtral Mini Transcribe (voxtral-mini-2507 via audio/transcriptions), with an efficient transcription only service.
        public static let voxtralMini2507 = "voxtral-mini-2507"
        /// Voxtral Mini Transcribe 2 (voxtral-mini-2602 via audio/transcriptions), with an efficient transcription only service.
        public static let voxtralMini2602 = "voxtral-mini-2602"
    }
    public enum Chat {
        /// Voxtral Small (voxtral-small-latest) with audio input for chat use cases.
        public static let voxtralSmallLatest = "voxtral-small-latest"
        /// Voxtral Mini (voxtral-mini-latest) with audio input for chat use cases
        public static let voxtralMiniLatest = "voxtral-mini-latest"
        /// Voxtral Mini (voxtral-mini-2507) with audio input for chat use cases
        public static let voxtralMini2507 = "voxtral-mini-2507"
        /// Voxtral Mini (voxtral-mini-2602) with audio input for chat use cases
        public static let voxtralMini2602 = "voxtral-mini-2602"
    }
}
