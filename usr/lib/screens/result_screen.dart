import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultScreen extends StatelessWidget {
  final String fileName;
  final Map<String, String> data;

  const ResultScreen({
    super.key,
    required this.fileName,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // Copy all data to clipboard
              String allText = data.entries.map((e) => "${e.key}:\n${e.value}").join("\n\n");
              Clipboard.setData(ClipboardData(text: allText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua data disalin ke clipboard')),
              );
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          String key = data.keys.elementAt(index);
          String value = data.values.elementAt(index);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$key disalin')),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 8),
                  SelectableText(
                    value,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
