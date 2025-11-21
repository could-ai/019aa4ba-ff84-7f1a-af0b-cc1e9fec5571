import 'dart:convert';

class FileParser {
  /// Mencoba menganalisa konten file dan mengekstrak informasi yang terbaca.
  /// Karena .ehi dan .hc seringkali dienkripsi dengan kunci privat proprietari,
  /// fungsi ini akan mencoba membaca bagian plaintext, base64, atau json yang terbuka.
  static Map<String, String> analyzeContent(String fileName, String rawContent) {
    Map<String, String> result = {};
    
    result['File Name'] = fileName;
    result['File Size'] = '${rawContent.length} bytes';
    
    // 1. Coba deteksi Payload (biasanya diawali dengan CONNECT, GET, POST, dll)
    final payloadRegex = RegExp(r'(CONNECT|GET|POST|PUT|HEAD|TRACE|OPTIONS|PATCH|DELETE) [^\s]+ HTTP', caseSensitive: false);
    final payloadMatch = payloadRegex.firstMatch(rawContent);
    if (payloadMatch != null) {
      // Ambil sekitar area payload
      int start = payloadMatch.start;
      int end = rawContent.indexOf('\r\n\r\n', start);
      if (end == -1) end = rawContent.length < start + 500 ? rawContent.length : start + 500;
      result['Detected Payload'] = rawContent.substring(start, end);
    } else {
      result['Detected Payload'] = 'Payload terenkripsi atau tidak ditemukan format standar.';
    }

    // 2. Coba cari Proxy (IP:Port)
    final proxyRegex = RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}\b');
    final proxyMatches = proxyRegex.allMatches(rawContent);
    if (proxyMatches.isNotEmpty) {
      result['Potential Proxies'] = proxyMatches.map((m) => m.group(0)).join(', ');
    }

    // 3. Coba Decode Base64 jika ada string panjang tanpa spasi
    // Ini teknik umum untuk menyembunyikan config
    final base64Regex = RegExp(r'[A-Za-z0-9+/=]{50,}');
    final base64Matches = base64Regex.allMatches(rawContent);
    
    if (base64Matches.isNotEmpty) {
      StringBuffer decodedParts = StringBuffer();
      for (var match in base64Matches) {
        String potentialBase64 = match.group(0)!;
        try {
          // Cek validitas padding
          String normalized = potentialBase64;
          int mod = normalized.length % 4;
          if (mod > 0) {
            normalized += '=' * (4 - mod);
          }
          
          String decoded = utf8.decode(base64.decode(normalized), allowMalformed: true);
          // Filter hasil decode agar hanya menampilkan teks yang bisa dibaca (printable ASCII)
          if (_isPrintable(decoded)) {
            decodedParts.writeln("--- Decoded Segment ---");
            decodedParts.writeln(decoded);
            decodedParts.writeln();
          }
        } catch (e) {
          // Ignore invalid base64
        }
      }
      if (decodedParts.isNotEmpty) {
        result['Decoded Base64 Data'] = decodedParts.toString();
      }
    }

    // 4. Raw Content Preview (jika file tidak binary total)
    // Ambil 1000 karakter pertama untuk preview
    String preview = rawContent.length > 1000 ? rawContent.substring(0, 1000) + '...' : rawContent;
    // Bersihkan karakter non-printable untuk tampilan
    result['Raw Header Preview'] = preview.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '.');

    return result;
  }

  static bool _isPrintable(String text) {
    if (text.isEmpty) return false;
    int printableCount = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // ASCII printable range + newline/tab
      if ((code >= 32 && code <= 126) || code == 10 || code == 13) {
        printableCount++;
      }
    }
    // Jika lebih dari 70% karakter bisa dibaca, anggap teks valid
    return (printableCount / text.length) > 0.7;
  }
}
