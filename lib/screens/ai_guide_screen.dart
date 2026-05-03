import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/database_service.dart';
import '../models/trip.dart';
import 'user_support_screen.dart';

class AIGuideScreen extends StatefulWidget {
  const AIGuideScreen({super.key});

  @override
  State<AIGuideScreen> createState() => _AIGuideScreenState();
}

class _AIGuideScreenState extends State<AIGuideScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _showSupportOption = false;

  late GenerativeModel _model;
  late ChatSession _chat;
  final DatabaseService _dbService = DatabaseService();
  List<Trip> _allTrips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
    // Initialize the AI Model (Needs API key from Gemini/Google AI Studio)
    _model = GenerativeModel(
      model: 'gemini-1.5-pro-latest',
      apiKey: 'YOUR_GEMINI_API_KEY', // Setup with real API later
    );
    _chat = _model.startChat();
    _messages.add(
      Message(text: "Namaste! I am your AI Trip Guide. Ask me anything about trips in India, weather, gear, or itineraries!", isUser: false),
    );
  }

  Future<void> _loadTrips() async {
    final trips = await _dbService.fetchTrips();
    setState(() => _allTrips = trips);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();

    try {
      final msg = text.toLowerCase();
      String replyText = "";
      
      // Check if user is asking for support
      if (msg.contains('support') || msg.contains('help') || msg.contains('human') || msg.contains('person')) {
        replyText = "I can escalate this to our human support team. Just hit the SUPPORT button below!";
        setState(() => _showSupportOption = true);
      } else {
        // Improved Trip Matching Logic
        Trip? matchedTrip;
        for (var t in _allTrips) {
          if (msg.contains(t.title.toLowerCase())) { matchedTrip = t; break; }
        }

        if (matchedTrip != null) {
          if (msg.contains('price') || msg.contains('cost')) {
            replyText = "The ${matchedTrip.title} starts at ₹${matchedTrip.basePrice.toInt()}.";
          } else if (msg.contains('altitude') || msg.contains('height')) {
            replyText = "The ${matchedTrip.title} reaches ${matchedTrip.altitude}.";
          } else {
            replyText = "${matchedTrip.title} is a ${matchedTrip.difficulty} trip in ${matchedTrip.location}. It takes ${matchedTrip.duration}. Should I help you with the booking process?";
          }
        } else {
          replyText = "I'm your AI guide for trips in India. You can ask about itinerary, gear, or pricing. If you need dedicated help, just type 'support'.";
        }
      }

      await Future.delayed(const Duration(milliseconds: 600));
      
      setState(() {
        _messages.add(Message(text: replyText, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(Message(text: "Communication glitch. I'm rebooting...", isUser: false));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Trip Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return FadeInUp(
                  child: Align(
                    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: message.isUser ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(20),
                          bottomLeft: !message.isUser ? const Radius.circular(0) : const Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.isUser ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showSupportOption)
            FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Not getting the right answers? Connect with our team.",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: _escalateToSupport,
                      child: const Text("SUPPORT", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about a trip...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _escalateToSupport() async {
    final lastUserMsg = _messages.lastWhere((m) => m.isUser).text;
    final contextCount = _messages.length > 5 ? 5 : _messages.length;
    final chatContext = _messages.sublist(_messages.length - contextCount).map((m) => "${m.isUser ? 'User' : 'AI'}: ${m.text}").join("\n");
    
    final subjectRaw = "AI Escalation: $lastUserMsg";
    final subject = subjectRaw.length > 50 ? subjectRaw.substring(0, 50) : subjectRaw;

    await _dbService.createSupportInquiry(
      subject: subject,
      message: "User requested human help after AI chat.",
      aiContext: chatContext,
    );

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => const UserSupportScreen()));
      setState(() {
        _messages.add(Message(text: "I've transmitted your frequency to our customer support team. They will respond shortly in your Support Inbox.", isUser: false));
        _showSupportOption = false;
      });
    }
  }
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}
