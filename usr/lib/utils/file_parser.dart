import 'dart:convert';

class FileParser {
  /// Mencoba menganalisa konten file dan mengekstrak informasi yang terbaca.
  static Map<String, String> analyzeContent(String fileName, String rawContent) {
    Map<String, String> result = {};
    
    result['File Name'] = fileName;
    result['File Size'] = '${rawContent.length} characters (decoded)';
    
    try {
      // 1. Coba deteksi Payload HTTP (CONNECT, GET, POST, dll)
      // Regex diperluas untuk menangkap variasi payload injeksi
      final payloadRegex = RegExp(
        r'((?:CONNECT|GET|POST|PUT|HEAD|TRACE|OPTIONS|PATCH|DELETE) [^\s]+ HTTP/[0-9\.]+[\s\S]*?\r\n\r\n)', 
        caseSensitive: false,
        multiLine: true
      );
      
      final payloadMatch = payloadRegex.firstMatch(rawContent);
      if (payloadMatch != null) {
        String payload = payloadMatch.group(1) ?? "";
        // Batasi panjang payload agar tidak memenuhi layar jika salah deteksi
        if (payload.length > 2000) payload = payload.substring(0, 2000) + "... (truncated)";
        result['Detected Payload'] = payload;
      } else {
        // Coba cari pola payload non-standar (misal [host_port])
        final customPayloadRegex = RegExp(r'\[.*\]');
        if (customPayloadRegex.hasMatch(rawContent)) {
           // Ambil baris yang mengandung kurung siku banyak
           final lines = LineSplitter.split(rawContent).where((l) => l.contains('[') && l.contains(']')).take(5).join('\n');
           if (lines.isNotEmpty) {
             result['Potential Custom Payload'] = lines;
           }
        }
      }

      // 2. Coba cari Proxy (IP:Port)
      // Regex diperbaiki untuk menghindari match tanggal/versi
      final proxyRegex = RegExp(r'\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):(80|8080|3128|8000|443|22|1080|[0-9]{2,5})\b');
      final proxyMatches = proxyRegex.allMatches(rawContent);
      if (proxyMatches.isNotEmpty) {
        // Hapus duplikat
        final uniqueProxies = proxyMatches.map((m) => m.group(0)).toSet().join(', ');
        result['Potential Proxies'] = uniqueProxies;
      }

      // 3. Coba cari SSH Info (Host, User, Pass)
      // Pola umum: "ssh_host":"..." atau "host=..."
      final hostRegex = RegExp(r'(?:ssh_host|host|server_ip)["\s:=]+([a-zA-Z0-9\.\-]+)', caseSensitive: false);
      final userRegex = RegExp(r'(?:ssh_user|username|user)["\s:=]+([a-zA-Z0-9\.\-\_]+)', caseSensitive: false);
      final passRegex = RegExp(r'(?:ssh_pass|password|pass)["\s:=]+([a-zA-Z0-9\.\-\_@!#]+)', caseSensitive: false);

      final hostMatch = hostRegex.firstMatch(rawContent);
      if (hostMatch != null) result['SSH Host'] = hostMatch.group(1)!;

      final userMatch = userRegex.firstMatch(rawContent);
      if (userMatch != null) result['SSH Username'] = userMatch.group(1)!;
      
      final passMatch = passRegex.firstMatch(rawContent);
      if (passMatch != null) result['SSH Password'] = passMatch.group(1)!;

      // 4. Coba Decode Base64 (Deep Scan)
      _scanForBase64(rawContent, result);

      // 5. SNI / Host Spoofing
      final sniRegex = RegExp(r'(?:sni|host_spoof)["\s:=]+([a-zA-Z0-9\.\-]+)', caseSensitive: false);
      final sniMatch = sniRegex.firstMatch(rawContent);
      if (sniMatch != null) result['SNI / Host'] = sniMatch.group(1)!;

    } catch (e) {
      result['Error Analysis'] = 'Terjadi kesalahan saat menganalisa: $e';
    }

    // Jika tidak ada hasil spesifik, tampilkan raw preview
    if (result.length <= 2) {
       String preview = rawContent.length > 1000 ? rawContent.substring(0, 1000) + '...' : rawContent;
       result['Raw Content Preview'] = preview.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '.');
    }

    return result;
  }

  static void _scanForBase64(String content, Map<String, String> result) {
    // Cari string yang terlihat seperti Base64 panjang
    final base64Regex = RegExp(r'[A-Za-z0-9+/=]{40,}');
    final matches = base64Regex.allMatches(content);
    
    StringBuffer decodedBuffer = StringBuffer();
    int count = 0;

    for (var match in matches) {
      if (count > 5) break; // Batasi max 5 segmen untuk performa
      String segment = match.group(0)!;
      try {
        // Fix padding
        String normalized = segment;
        int mod = normalized.length % 4;
        if (mod > 0) normalized += '=' * (4 - mod);

        List<int> bytes = base64.decode(normalized);
        // Cek apakah hasil decode readable text
        String decoded = utf8.decode(bytes, allowMalformed: true);
        
        if (_isPrintable(decoded) && decoded.length > 5) {
          decodedBuffer.writeln("--- Segment ${count + 1} ---");
          decodedBuffer.writeln(decoded);
          decodedBuffer.writeln();
          count++;
        }
      } catch (e) {
        // Ignore
      }
    }

    if (decodedBuffer.isNotEmpty) {
      result['Decoded Base64 Segments'] = decodedBuffer.toString();
    }
  }

  static bool _isPrintable(String text) {
    if (text.isEmpty) return false;
    int printableCount = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 32 && code <= 126) || code == 10 || code == 13) {
        printableCount++;
      }
    }
    // Ambang batas validitas teks (70% printable)
    return (printableCount / text.length) > 0.7;
  }
}
