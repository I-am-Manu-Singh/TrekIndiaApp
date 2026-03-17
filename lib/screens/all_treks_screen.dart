import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../models/trek.dart';
import '../widgets/trek_card.dart';

class AllTreksScreen extends StatelessWidget {
  final List<Trek> treks;
  final String title;

  const AllTreksScreen({super.key, required this.treks, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: treks.length,
        itemBuilder: (context, index) {
          return FadeInUp(
            delay: Duration(milliseconds: 100 * index),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TrekCard(trek: treks[index]),
            ),
          );
        },
      ),
    );
  }
}
