import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:couldai_user_app/screens/result_screen.dart';
import 'package:couldai_user_app/utils/file_parser.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ehi', 'hc', 'txt', 'json'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        
        // Simulasi proses decrypt/baca file
        // Catatan: Pada web path mungkin null, kita pakai bytes
        String fileName = file.name;
        String? content;
        
        if (file.bytes != null) {
          // Web atau jika bytes tersedia langsung
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (file.path != null) {
          // Mobile / Desktop
          final ioFile = File(file.path!);
          content = await ioFile.readAsString();
        }

        if (content != null) {
          // Analisa konten
          final parsedData = FileParser.analyzeContent(fileName, content);
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  fileName: fileName,
                  data: parsedData,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Decryptor Tool'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_open_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Decrypt .ehi / .hc Files',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Pilih file konfigurasi untuk menganalisa isi payload, proxy, dan ssh settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('PILIH FILE .EHI / .HC'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
