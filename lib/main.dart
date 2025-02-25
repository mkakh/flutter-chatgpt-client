import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dart_openai/dart_openai.dart';

import 'env/env.dart';

void main() {
  OpenAI.apiKey = Env.apiKey;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT API (o3-mini)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Scrolls the chat list to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Converts the internal message list into a format required by OpenAI.
  List<OpenAIChatCompletionChoiceMessageModel> _buildChatMessages() =>
      _messages.map((msg) {
        return OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                msg['content'] ?? '')
          ],
          role: msg['role'] == 'user'
              ? OpenAIChatMessageRole.user
              : OpenAIChatMessageRole.assistant,
        );
      }).toList();

  // Parses the assistant response content into plain text.
  String _parseAssistantResponse(dynamic content) {
    if (content is List<OpenAIChatCompletionChoiceMessageContentItemModel>) {
      return content.isNotEmpty
          ? (content.first.text ?? "No response from assistant.")
          : "No response from assistant.";
    } else if (content is String) {
      return content;
    } else {
      return "No response from assistant.";
    }
  }

  // Sends a user message to the OpenAI API and updates the chat with the assistant response.
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final chatMessages = _buildChatMessages();
      final response = await OpenAI.instance.chat.create(
        model: "o3-mini",
        messages: chatMessages,
      );
      final assistantMessage = response.choices.first.message;
      final responseText = _parseAssistantResponse(assistantMessage.content);
      setState(() {
        _messages.add({'role': 'assistant', 'content': responseText});
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $error'});
        _isLoading = false;
      });
    } finally {
      _scrollToBottom();
    }
  }

  // Retrieves the file for storing chat history.
  Future<File> _getLocalFile() async {
    Directory directory;
    if (kIsWeb) {
      directory = await getTemporaryDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return File('${directory.path}/chat_history.json');
  }

  // Saves the current chat history to a local file.
  Future<void> _saveHistory() async {
    try {
      final file = await _getLocalFile();
      final jsonStr = json.encode(_messages);
      await file.writeAsString(jsonStr);
      _showSnackBar("Chat history saved successfully");
    } catch (error) {
      _showSnackBar("Failed to save chat history: $error");
    }
  }

  // Loads chat history from a local file.
  Future<void> _loadHistory() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        List<dynamic> loaded = json.decode(jsonStr);
        setState(() {
          _messages
            ..clear()
            ..addAll(loaded.cast<Map<String, dynamic>>());
        });
        _showSnackBar("Chat history loaded successfully");
      } else {
        _showSnackBar("No saved chat history found");
      }
    } catch (error) {
      _showSnackBar("Failed to load chat history: $error");
    } finally {
      _scrollToBottom();
    }
  }

  // Displays a SnackBar with the provided message.
  void _showSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
      );

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Enter your message...',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _sendMessage(_controller.text),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveLoadButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _saveHistory,
            child: const Text("Save"),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _loadHistory,
            child: const Text("Load"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatGPT API (o3-mini)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildChatList()),
            _buildSaveLoadButtons(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUser = message['role'] == 'user';
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          message['content'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
