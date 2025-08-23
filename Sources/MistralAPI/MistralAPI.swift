public enum MistralModelID {
    public enum Transcription {
        /// Voxtral Mini Transcribe (voxtral-mini-latest via audio/transcriptions), with an efficient transcription only service.
        public static let voxtralMiniLatest = "voxtral-mini-latest"
        /// Voxtral Mini Transcribe (voxtral-mini-2507 via audio/transcriptions), with an efficient transcription only service.
        public static let voxtralMini2507 = "voxtral-mini-2507"
    }
    public enum Chat {
        /// Voxtral Small (voxtral-small-latest) with audio input for chat use cases.
        public static let voxtralSmallLatest = "voxtral-small-latest"
        /// Voxtral Mini (voxtral-mini-latest) with audio input for chat use cases
        public static let voxtralMiniLatest = "voxtral-mini-latest"
        /// Voxtral Mini (voxtral-mini-2507) with audio input for chat use cases
        public static let voxtralMini2507 = "voxtral-mini-2507"
    }
}
