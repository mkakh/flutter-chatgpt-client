import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';
import 'env/env.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// IMPORTANT:
// 1. Ensure your pubspec.yaml includes the dependency:
//    dart_openai: ^5.0.0
//    Also add path_provider (e.g., path_provider: ^2.0.11)
// 2. Run "flutter pub get" to install the dependencies.
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

  Future<File> _getLocalFile() async {
    Directory directory;
    if (kIsWeb) {
      directory = await getTemporaryDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return File('${directory.path}/chat_history.json');
  }

  Future<void> _saveHistory() async {
    try {
      final file = await _getLocalFile();
      final jsonStr = json.encode(_messages);
      await file.writeAsString(jsonStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chat history saved successfully"))
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save chat history: $error"))
      );
    }
  }

  Future<void> _loadHistory() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        List<dynamic> loaded = json.decode(jsonStr);
        setState(() {
          _messages.clear();
          _messages.addAll(loaded.map((m) => m as Map<String, dynamic>));
        });
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Chat history loaded successfully"))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No saved chat history found"))
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load chat history: $error"))
      );
    }
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _saveHistory,
                    child: Text("Save"),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _loadHistory,
                    child: Text("Load"),
                  ),
                ],
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
