import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NetworkDiscovery {
  static const int discoveryPort = 41234;

  static Future<String?> discoverServer() async {
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      socket.broadcastEnabled = true;

      // Send broadcast discovery message
      socket.send(
        utf8.encode('DISCOVER_SERVER'),
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );

      print('📡 Discovery request sent');

      final completer = Completer<String?>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();

          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            final jsonData = jsonDecode(message);

            final ip = jsonData['ip'];
            final port = jsonData['port'];

            completer.complete('http://$ip:$port/api');
          }
        }
      });

      return completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ Discovery timeout');
          return null;
        },
      );
    } catch (e) {
      print('❌ Discovery error: $e');
      return null;
    } finally {
      Future.delayed(
        const Duration(seconds: 4),
            () => socket?.close(),
      );
    }
  }
}