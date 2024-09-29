import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'WebSocket Demo';
    return const MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;

  // List to store chat messages where 0 = sent message, 1 = received message
  final List<Map<int, String>> _messages = [];
  Timer? _pingTimer;
  // ScrollController to control ListView's scroll position
  final ScrollController _scrollController = ScrollController();

  void _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://ws.postman-echo.com/raw'),
      );
      try {
        await _channel.ready;
      } on SocketException catch (e) {
        // Handle the exception.
      } on WebSocketChannelException catch (e) {
        // Handle the exception.
      }
      // Listen to the stream with error handling and connection management
      _channel.stream.timeout(const Duration(seconds: 10), onTimeout: (sink) {
        _showErrorMessage('Connection timed out. Retrying...');
        _retryConnection();
      }).listen(
        (message) {
          print('message: $message');
          // Received message
          if (message == "ping") {
            setState(() {
              _messages.add({1: "pong"}); // Append received message with key 1
            });
          } else {
            setState(() {
              _messages.add({1: message}); // Append received message with key 1
            });
          }
          _scrollToBottom();
          // Reset the ping timer on message reception
          // _resetPingTimer();
        },
        onDone: () {
          // Connection closed
          _showErrorMessage('Connection closed. Reconnecting...');
          _retryConnection();
        },
        onError: (error) {
          // Handle connection error
          _showErrorMessage('Error: $error. Retrying...');
          _retryConnection();
        },
      );

      // Start the ping/pong mechanism
      // _startPing();
    } catch (e) {
      _showErrorMessage('Error connecting to WebSocket: $e');
    }
  }

  // void _resetPingTimer() {
  //   // Cancel the existing ping timer and restart it
  //   _pingTimer?.cancel();
  //   _startPing();
  // }

  // void _startPing() {
  //   // Send 'ping' message every 30 seconds to maintain the connection
  //   _pingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  //     _sendMessage(msg: "ping");
  //   });
  // }

  void _sendMessage({msg}) {
    print('ms: ${msg}');
    if (msg == null || msg.toString().isEmpty) {
      if (_controller.text.isNotEmpty) {
        setState(() {
          _messages
              .add({0: _controller.text}); // Append sent message with key 0
        });
        try {
          _channel.sink.add(_controller.text); // Send message via WebSocket
        } catch (e) {
          _showErrorMessage('Error sending message: $e');
        }
        _controller.clear(); // Clear the input field
      }
    } else {
      setState(() {
        _messages.add({0: msg}); // Append sent message with key 0
      });
      try {
        _channel.sink.add(msg); // Send message via WebSocket
      } catch (e) {
        _showErrorMessage('Error sending message: $e');
      }
    }
    // _resetPingTimer();
    _scrollToBottom();
  }

  void _retryConnection() {
    // Close the current connection and retry after a short delay
    _channel.sink.close();
    _pingTimer?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      _connectWebSocket();
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectWebSocket();
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    _pingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  bool isUserMessage = msg.keys.first == 0;

                  return Align(
                    alignment: isUserMessage
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUserMessage
                            ? Colors.blue[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg.values.first, // Display the message text
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Form(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Send a message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(onPressed: _sendMessage, icon: Icon(Icons.send)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
