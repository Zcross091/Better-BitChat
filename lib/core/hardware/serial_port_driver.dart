import 'dart:async';
import 'dart:typed_data';

enum SerialPortType { usbOtg, bluetoothSpp, virtualMock }

class SerialPortConfig {
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final String parity; // 'none', 'even', 'odd'

  const SerialPortConfig({
    this.baudRate = 115200,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 'none',
  });
}

class SerialLogEntry {
  final DateTime timestamp;
  final bool isTx; // true = transmitted, false = received
  final Uint8List data;
  final String summary;

  SerialLogEntry({
    required this.timestamp,
    required this.isTx,
    required this.data,
    required this.summary,
  });

  String get hexDump => data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
}

/// Abstract UART Serial Port Driver supporting USB-OTG (CDC-ACM/CH340/CP2102) & Bluetooth SPP
class SerialPortDriver {
  final SerialPortType type;
  final String deviceName;
  SerialPortConfig config;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  final StreamController<Uint8List> _rxStreamController = StreamController<Uint8List>.broadcast();
  final StreamController<SerialLogEntry> _logStreamController = StreamController<SerialLogEntry>.broadcast();
  final List<SerialLogEntry> _logHistory = [];

  Stream<Uint8List> get rxStream => _rxStreamController.stream;
  Stream<SerialLogEntry> get logStream => _logStreamController.stream;
  List<SerialLogEntry> get logHistory => List.unmodifiable(_logHistory);

  SerialPortDriver({
    this.type = SerialPortType.usbOtg,
    this.deviceName = 'ESP32 LoRa V3 (CP2102 UART)',
    this.config = const SerialPortConfig(baudRate: 115200),
  });

  Future<bool> open({SerialPortConfig? newConfig}) async {
    if (newConfig != null) config = newConfig;
    _isOpen = true;
    _addLog(true, Uint8List.fromList([]), 'PORT OPENED @ ${config.baudRate} baud (8N1)');
    return true;
  }

  Future<void> close() async {
    _isOpen = false;
    _addLog(false, Uint8List.fromList([]), 'PORT CLOSED');
  }

  Future<bool> write(Uint8List bytes, {String? summary}) async {
    if (!_isOpen) return false;

    _addLog(true, bytes, summary ?? 'TX: ${bytes.length} bytes');
    return true;
  }

  /// Ingests incoming raw bytes from hardware receiver interrupt
  void injectIncomingBytes(Uint8List bytes, {String? summary}) {
    if (!_isOpen) return;

    _addLog(false, bytes, summary ?? 'RX: ${bytes.length} bytes');
    _rxStreamController.add(bytes);
  }

  void _addLog(bool isTx, Uint8List data, String summary) {
    final entry = SerialLogEntry(
      timestamp: DateTime.now(),
      isTx: isTx,
      data: data,
      summary: summary,
    );
    _logHistory.add(entry);
    if (_logHistory.length > 500) {
      _logHistory.removeAt(0); // Bounded in-memory log buffer
    }
    _logStreamController.add(entry);
  }

  void clearLogs() {
    _logHistory.clear();
  }

  Future<void> dispose() async {
    await close();
    await _rxStreamController.close();
    await _logStreamController.close();
  }
}
