import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';
import 'env/env.dart';

// IMPORTANT:
// 1. Ensure your pubspec.yaml includes the dependency:
//    dart_openai: ^5.0.0
// 2. Run "flutter pub get" to install the dependency.
// 3. Replace 'YOUR_API_KEY' below with your actual OpenAI API key.

void main() {
  OpenAI.apiKey = Env.apiKey;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT API (o3-mini)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Stores chat messages with keys 'role' and 'content'
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Sends the user message to OpenAI and adds the assistant's reply.
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // Convert conversation history to a list of OpenAIChatCompletionChoiceMessageModel objects.
      List<OpenAIChatCompletionChoiceMessageModel> chatMessages = _messages.map((msg) {
        return OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(msg['content']!)
          ],
          role: msg['role'] == 'user'
              ? OpenAIChatMessageRole.user
              : OpenAIChatMessageRole.assistant,
        );
      }).toList();
      final response = await OpenAI.instance.chat.create(
        model: "o3-mini",
        messages: chatMessages,
      );

      final assistantMessage = response.choices.first.message;
      String responseText;
      if (assistantMessage.content is List<OpenAIChatCompletionChoiceMessageContentItemModel>) {
        final contentItems = assistantMessage.content as List<OpenAIChatCompletionChoiceMessageContentItemModel>;
        responseText = contentItems.isNotEmpty ? (contentItems.first.text ?? "No response from assistant.") : "No response from assistant.";
      } else if (assistantMessage.content is String) {
        responseText = (assistantMessage.content as String?) ?? "No response from assistant.";
      } else {
        responseText = "No response from assistant.";
      }
      setState(() {
        _messages.add({'role': 'assistant', 'content': responseText});
      });
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $error'});
      });
      _scrollToBottom();
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Builds a widget for an individual chat message.
  Widget _buildMessage(Map<String, dynamic> msg) {
    bool isUser = msg['role'] == 'user';
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(14),
        child: Text(
          msg['content'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ChatGPT API (o3-mini)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Enter your message...',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        _sendMessage(value);
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _sendMessage(_controller.text),
                    child: Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
