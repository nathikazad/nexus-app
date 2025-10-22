# Nexus Voice Assistant

A Flutter application that records audio from the microphone and sends it to OpenAI's Realtime API for real-time voice interaction.

## Features

- 🎤 Real-time audio recording
- 🤖 OpenAI Realtime API integration
- 📱 Cross-platform support (iOS, Android, Web)
- 🎯 Voice Activity Detection (VAD)
- 💬 Single conversation transcript with user/agent distinction
- 🔑 Hardcoded API key for easy setup

## Prerequisites

- Flutter SDK (>=3.0.0)
- iOS Simulator (for iOS testing)
- Chrome browser (for web testing)

## Setup

1. **Install dependencies:**
   ```bash
   cd mobile
   flutter pub get
   ```

## Running the App

### iOS Simulator
```bash
flutter run -d ios
```

### Chrome Browser
```bash
flutter run -d chrome
```

### Android (if available)
```bash
flutter run -d android
```

## Usage

1. **Launch the app** on your preferred platform
2. **Click "Connect to OpenAI"** to establish connection
3. **Tap the microphone button** to start recording
4. **Speak into the microphone** - your audio will be streamed to OpenAI in real-time
5. **View the conversation** in the single transcript area with clear user/agent distinction
6. **Tap the stop button** to end recording
7. **Use the clear button** (trash icon) to clear the conversation

## Technical Details

### Audio Configuration
- **Format:** PCM16
- **Sample Rate:** 24kHz
- **Channels:** Mono (1 channel)
- **Bit Rate:** 384kbps

### OpenAI Realtime API
- Uses server-side Voice Activity Detection (VAD)
- Automatic transcription with Whisper-1
- Real-time audio streaming
- Alloy voice for responses

### Cross-Platform Support
- **iOS:** Native audio recording with microphone permissions
- **Web:** Web Audio API integration
- **Android:** Native audio recording (when available)

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── services/
│   ├── audio_service.dart    # Audio recording service
│   └── openai_service.dart   # OpenAI Realtime API integration
└── screens/
    └── voice_assistant_screen.dart  # Main UI
```

## Dependencies

- `openai_realtime_dart`: OpenAI Realtime API client
- `record`: Audio recording functionality
- `permission_handler`: Microphone permissions
- `path_provider`: File system access
- `universal_html`: Web compatibility

## Troubleshooting

### iOS Issues
- Ensure microphone permissions are granted
- Check that iOS Simulator supports audio recording
- Verify Info.plist includes NSMicrophoneUsageDescription

### Web Issues
- Use HTTPS for microphone access (required by browsers)
- Check browser console for permission errors
- Ensure OpenAI API key is valid

### Connection Issues
- Verify OpenAI API key is correct
- Check internet connection
- Ensure OpenAI Realtime API access is enabled

## License

This project is for educational and development purposes.
