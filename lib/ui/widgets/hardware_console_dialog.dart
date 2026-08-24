import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/hardware/meshtastic_interop.dart';
import '../../core/hardware/serial_port_driver.dart';
import '../../transports/usb_serial_lora_transport.dart';
import '../theme/app_theme.dart';

class HardwareConsoleDialog extends StatefulWidget {
  final UsbSerialLoraTransport transport;

  const HardwareConsoleDialog({
    super.key,
    required this.transport,
  });

  @override
  State<HardwareConsoleDialog> createState() => _HardwareConsoleDialogState();
}

class _HardwareConsoleDialogState extends State<HardwareConsoleDialog> {
  final TextEditingController _testTxController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedBaud = 115200;

  @override
  Widget build(BuildContext context) {
    final driver = widget.transport.serialDriver;
    final logs = driver.logHistory;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Row(
        children: [
          const Icon(LucideIcons.terminal, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Hardware Serial Console (UART)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: driver.isOpen ? AppTheme.success.withOpacity(0.15) : AppTheme.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              driver.isOpen ? 'CONNECTED' : 'OFFLINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: driver.isOpen ? AppTheme.success : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 480,
        child: Column(
          children: [
            // Controls Bar (Baud rate & Port State)
            Row(
              children: [
                const Text('Baud:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedBaud,
                  dropdownColor: AppTheme.surfaceElevated,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'FiraCode'),
                  items: const [
                    DropdownMenuItem(value: 9600, child: Text('9600')),
                    DropdownMenuItem(value: 57600, child: Text('57600')),
                    DropdownMenuItem(value: 115200, child: Text('115200 (Default)')),
                    DropdownMenuItem(value: 921600, child: Text('921600 (High-Speed)')),
                  ],
                  onChanged: (baud) {
                    if (baud != null) {
                      setState(() {
                        _selectedBaud = baud;
                        driver.open(newConfig: SerialPortConfig(baudRate: baud));
                      });
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  tooltip: 'Clear Terminal Logs',
                  onPressed: () {
                    setState(() {
                      driver.clearLogs();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Serial Terminal Log Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No UART traffic yet. Send a packet or connect hardware.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final entry = logs[index];
                          final timeStr = "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}";

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '[$timeStr] ',
                                      style: const TextStyle(fontFamily: 'FiraCode', fontSize: 10, color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      entry.isTx ? '➔ [TX] ' : '⬅ [RX] ',
                                      style: TextStyle(
                                        fontFamily: 'FiraCode',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: entry.isTx ? AppTheme.primary : AppTheme.secondary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.summary,
                                        style: const TextStyle(fontFamily: 'FiraCode', fontSize: 11, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                if (entry.data.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 14, top: 2),
                                    child: Text(
                                      entry.hexDump,
                                      style: TextStyle(
                                        fontFamily: 'FiraCode',
                                        fontSize: 9,
                                        color: entry.isTx ? AppTheme.primary.withOpacity(0.7) : AppTheme.secondary.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Simulated Hardware Packet Injection Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testTxController,
                    style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode', color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type raw payload or Meshtastic text...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      filled: true,
                      fillColor: AppTheme.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(LucideIcons.send, size: 14),
                  label: const Text('Send UART'),
                  onPressed: () {
                    final text = _testTxController.text.trim();
                    if (text.isEmpty) return;

                    final testPacket = MeshtasticPacket(
                      fromNode: 0x1A2B3C4D,
                      toNode: 0xFFFFFFFF,
                      id: DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF,
                      portNum: MeshtasticPortNum.textMessageApp,
                      payload: Uint8List.fromList(utf8.encode(text)),
                    );

                    final bytes = testPacket.toFramedBytes();
                    driver.write(bytes, summary: 'Manual TX: "$text"');
                    _testTxController.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
