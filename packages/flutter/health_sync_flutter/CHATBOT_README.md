# HealthSync AI Chatbot

AI-powered chatbot for querying and understanding health data from HealthSync SDK.

## Overview

The HealthSync AI Chatbot provides a conversational interface for users to interact with their health data. Powered by OpenAI's ChatGPT, it can answer questions, provide insights, and help users understand their health metrics from connected sources like Google Health Connect, Fitbit, and more.

## Features

- **Natural Language Queries**: Ask questions in plain English about your health data
- **Real-Time Streaming**: Get responses as they're generated for a better UX
- **Health Data Context**: Automatically includes relevant health data in prompts
- **Smart Caching**: Caches health context for 5 minutes to reduce API calls
- **Conversation History**: Maintains context across multiple messages
- **Beautiful UI**: Pre-built Material 3 chat interface
- **Secure API Key Storage**: Uses FlutterSecureStorage for API key management

## Installation

The chatbot module is included in the `health_sync_flutter` package. Add the required dependencies:

```yaml
dependencies:
  health_sync_flutter: ^1.0.0

  # Additional dependencies for chatbot
  http: ^1.1.0
  uuid: ^4.0.0
  flutter_secure_storage: ^9.0.0
```

## Quick Start

### 1. Setup OpenAI API Key

Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys).

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

// Save API key securely
await storage.write(key: 'openai_api_key', value: 'sk-...');
```

### 2. Initialize the Chatbot

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

// Create chatbot configuration
final config = ChatbotConfig(
  apiKey: 'your-openai-api-key',
  model: 'gpt-4o-mini', // Cost-effective model
  temperature: 0.7,
  enableStreaming: true,
  includeHealthContext: true,
  healthContextDays: 7,
);

// Create health context builder (connects to Health Connect)
final healthContextBuilder = HealthContextBuilder(
  healthConnectPlugin: healthConnectPlugin,
);

// Create chat service
final chatService = ChatService(
  config: config,
  healthContextBuilder: healthContextBuilder,
);
```

### 3. Use the Pre-Built UI

```dart
import 'package:flutter/material.dart';

class MyChatScreen extends StatelessWidget {
  final ChatService chatService;

  const MyChatScreen({required this.chatService});

  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      chatService: chatService,
      title: 'Health Assistant',
    );
  }
}
```

### 4. Or Build Custom UI

```dart
// Send a message
await chatService.sendMessage('How many steps did I walk today?');

// Listen to messages stream
chatService.messagesStream.listen((messages) {
  // Update UI with messages
  print('${messages.length} messages in conversation');
});

// Clear conversation
chatService.clearHistory();

// Refresh health data context
chatService.refreshHealthContext();
```

## Configuration Options

```dart
ChatbotConfig(
  // Required
  apiKey: 'sk-...',

  // OpenAI Model (default: gpt-4o-mini)
  model: 'gpt-4o-mini',  // or gpt-4, gpt-3.5-turbo, etc.

  // Response creativity (0.0 - 2.0, default: 0.7)
  temperature: 0.7,

  // Max tokens in response (default: null = no limit)
  maxTokens: 1000,

  // Enable streaming responses (default: true)
  enableStreaming: true,

  // Custom system prompt (default: health assistant prompt)
  systemPrompt: 'You are a helpful health assistant...',

  // Include health data in queries (default: true)
  includeHealthContext: true,

  // Days of health data to include (default: 7)
  healthContextDays: 7,

  // Max conversation messages to send (default: 10)
  maxConversationHistory: 10,

  // OpenAI API base URL (default: https://api.openai.com/v1)
  baseUrl: 'https://api.openai.com/v1',

  // Request timeout in seconds (default: 30)
  timeoutSeconds: 30,
)
```

## Example Queries

The chatbot can answer questions like:

- "How many steps did I walk today?"
- "What's my average heart rate this week?"
- "Show me my sleep patterns for the last 7 days"
- "How active was I yesterday?"
- "Did I burn more calories today or yesterday?"
- "What was my best day for steps this week?"
- "Am I sleeping enough?"
- "How does my heart rate compare to normal?"

## Health Data Context

The chatbot automatically includes relevant health data in its prompts. Here's what gets included:

```
USER HEALTH DATA (Last 7 days):

Steps:
  Total: 45,234 steps
  Daily Average: 6,462 steps
  Best Day: 2024-01-10 - 9,842 steps
  Days Tracked: 7

Heart Rate:
  Average: 72 bpm
  Range: 58 - 145 bpm
  Readings: 842

Sleep:
  Total Sleep: 48.5 hours
  Average: 6.9 hours/night
  Nights Tracked: 7

... (other data types)
```

## Customizing Data Context

You can customize which data types are included:

```dart
final healthContextBuilder = HealthContextBuilder(
  healthConnectPlugin: healthConnectPlugin,
);

// Build custom context
final context = await healthContextBuilder.buildContext(
  days: 14,  // 14 days instead of 7
  dataTypes: [
    HealthDataType.steps,
    HealthDataType.heartRate,
    HealthDataType.sleep,
    // Add only the types you want
  ],
);
```

## Custom System Prompt

Customize the chatbot's behavior with a custom system prompt:

```dart
final config = ChatbotConfig(
  apiKey: apiKey,
  systemPrompt: '''
You are a fitness coach assistant integrated with HealthSync SDK.
Your goal is to motivate users and help them achieve their fitness goals.

- Be encouraging and positive
- Give actionable advice
- Celebrate achievements
- Provide context on how their metrics compare to health guidelines
- Focus on progress and trends rather than single data points

Always remind users that you're not a doctor and they should consult
healthcare professionals for medical advice.
''',
);
```

## Cost Optimization

### Use Cost-Effective Models

```dart
final config = ChatbotConfig(
  apiKey: apiKey,
  model: 'gpt-4o-mini',  // ~15x cheaper than gpt-4
  maxTokens: 500,        // Limit response length
);
```

### Cache Health Context

The chatbot automatically caches health context for 5 minutes to reduce duplicate fetches:

```dart
// First query - fetches health data
await chatService.sendMessage('How many steps today?');

// Within 5 minutes - uses cached health data
await chatService.sendMessage('What about my heart rate?');

// Force refresh
chatService.refreshHealthContext();
await chatService.sendMessage('Show me updated data');
```

### Limit Conversation History

```dart
final config = ChatbotConfig(
  apiKey: apiKey,
  maxConversationHistory: 5,  // Only send last 5 exchanges
);
```

## Error Handling

```dart
try {
  await chatService.sendMessage('How many steps today?');
} on OpenAIException catch (e) {
  // Handle OpenAI-specific errors
  print('OpenAI Error (${e.statusCode}): ${e.message}');

  if (e.statusCode == 401) {
    print('Invalid API key');
  } else if (e.statusCode == 429) {
    print('Rate limit exceeded');
  } else if (e.statusCode == 500) {
    print('OpenAI server error');
  }
} catch (e) {
  // Handle other errors
  print('Error: $e');
}
```

## Streaming Responses

Enable streaming for real-time responses:

```dart
final config = ChatbotConfig(
  apiKey: apiKey,
  enableStreaming: true,  // Enable streaming
);

// Listen to messages stream
chatService.messagesStream.listen((messages) {
  final lastMessage = messages.last;

  if (lastMessage.status == ChatMessageStatus.sending) {
    // Message is being streamed
    print('Assistant is typing: ${lastMessage.content}');
  } else if (lastMessage.status == ChatMessageStatus.sent) {
    // Message complete
    print('Assistant finished: ${lastMessage.content}');
  }
});
```

## Security Best Practices

### 1. Never Hardcode API Keys

```dart
// ❌ BAD - Don't do this
final config = ChatbotConfig(
  apiKey: 'sk-hardcoded-key-in-source',
);

// ✅ GOOD - Store securely
const storage = FlutterSecureStorage();
final apiKey = await storage.read(key: 'openai_api_key');
final config = ChatbotConfig(apiKey: apiKey!);
```

### 2. Use Environment Variables (Development)

```dart
// In your environment config
const apiKey = String.fromEnvironment('OPENAI_API_KEY');
```

### 3. Proxy Through Your Backend (Production)

For production apps, consider proxying OpenAI requests through your backend:

```dart
final config = ChatbotConfig(
  apiKey: 'your-backend-token',
  baseUrl: 'https://your-backend.com/api/chat',  // Your proxy
);
```

## Cost Estimates

Based on OpenAI pricing (as of 2024):

| Model | Input | Output | Typical Query Cost |
|-------|-------|--------|-------------------|
| gpt-4o-mini | $0.15/1M tokens | $0.60/1M tokens | ~$0.001-0.003 |
| gpt-4o | $2.50/1M tokens | $10.00/1M tokens | ~$0.02-0.06 |
| gpt-3.5-turbo | $0.50/1M tokens | $1.50/1M tokens | ~$0.002-0.005 |

With typical health context (~500 tokens) + query (~50 tokens) + response (~200 tokens), expect:
- **gpt-4o-mini**: ~$0.001 per query (~1,000 queries per $1)
- **gpt-4o**: ~$0.025 per query (~40 queries per $1)

## Advanced Usage

### Custom Message Rendering

```dart
StreamBuilder<List<ChatMessage>>(
  stream: chatService.messagesStream,
  builder: (context, snapshot) {
    final messages = snapshot.data ?? [];

    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        // Custom rendering based on role
        if (message.role == ChatMessageRole.user) {
          return MyCustomUserBubble(message: message);
        } else {
          return MyCustomAssistantBubble(message: message);
        }
      },
    );
  },
)
```

### Message Persistence

```dart
// Save conversation
final messages = chatService.messages;
final json = messages.map((m) => m.toJson()).toList();
await storage.write(
  key: 'chat_history',
  value: jsonEncode(json),
);

// Restore conversation (requires custom implementation)
// The ChatService doesn't currently support restoring history
// You would need to extend it or rebuild messages manually
```

## Troubleshooting

### "Invalid API Key" Error

- Verify your API key is correct
- Check if the key has proper permissions
- Ensure the key hasn't expired

### "Rate Limit Exceeded" Error

- You've exceeded OpenAI's rate limits
- Wait and retry
- Consider upgrading your OpenAI plan

### No Health Data in Context

- Ensure Health Connect permissions are granted
- Check that health data exists for the requested time period
- Verify `includeHealthContext: true` in config

### Slow Responses

- Use `gpt-4o-mini` instead of `gpt-4o`
- Reduce `healthContextDays` (less data to send)
- Reduce `maxConversationHistory`
- Enable `enableStreaming: true` for perceived speed

## Complete Example

See `test-app/lib/chatbot_screen.dart` for a complete implementation with:
- API key management
- Health Connect integration
- Pre-built UI
- Error handling
- Settings dialog

## API Reference

### ChatService

```dart
class ChatService {
  // Constructor
  ChatService({
    required ChatbotConfig config,
    HealthContextBuilder? healthContextBuilder,
  });

  // Send a message
  Future<void> sendMessage(String content);

  // Stream of messages
  Stream<List<ChatMessage>> get messagesStream;

  // Current messages
  List<ChatMessage> get messages;

  // Clear conversation
  void clearHistory();

  // Refresh health context cache
  void refreshHealthContext();

  // Dispose resources
  void dispose();
}
```

### ChatMessage

```dart
class ChatMessage {
  final String id;
  final String content;
  final ChatMessageRole role;  // user, assistant, system
  final DateTime timestamp;
  final ChatMessageStatus status;  // sending, sent, error
  final String? error;
}
```

### HealthContextBuilder

```dart
class HealthContextBuilder {
  // Constructor
  HealthContextBuilder({
    HealthConnectPlugin? healthConnectPlugin,
  });

  // Build health data context
  Future<String> buildContext({
    required int days,
    List<HealthDataType>? dataTypes,
  });
}
```

## License

MIT License - Part of HealthSync SDK

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/healthsync-sdk/issues)
- Documentation: [Main README](../../../README.md)
- Examples: [test-app/lib/chatbot_screen.dart](../../../test-app/lib/chatbot_screen.dart)
