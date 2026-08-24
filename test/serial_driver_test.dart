import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/hardware/serial_port_driver.dart';
import 'package:mesh_messenger/transports/usb_serial_lora_transport.dart';
import 'package:mesh_messenger/core/models/bundle.dart';

void main() {
  group('SerialPortDriver & USB-OTG LoRa Transport Tests', () {
    late SerialPortDriver driver;
    late UsbSerialLoraTransport transport;

    setUp(() {
      driver = SerialPortDriver();
      transport = UsbSerialLoraTransport(driver: driver);
    });

    test('Opens and closes serial port with baud rate configuration and log tracking', () async {
      expect(driver.isOpen, isFalse);
      await driver.open(newConfig: const SerialPortConfig(baudRate: 115200));

      expect(driver.isOpen, isTrue);
      expect(driver.config.baudRate, equals(115200));
      expect(driver.logHistory.length, equals(1));
      expect(driver.logHistory.first.summary, contains('115200 baud'));

      await driver.close();
      expect(driver.isOpen, isFalse);
      expect(driver.logHistory.length, equals(2));
    });

    test('Transmits DTN bundle across physical UART serial link in Meshtastic framing', () async {
      await transport.initialize();
      expect(transport.isConnected, isTrue);

      final bundle = Bundle(
        bundleId: 'bundle_uart_tx_01',
        senderPubkey: 'pub_alice_01',
        destPubkey: 'all',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: 'HELLO_OVER_USB_OTG_RADIO',
        signature: 'sig',
      );

      final ok = await transport.sendBundle(bundle);
      expect(ok, isTrue);

      // Verify log history recorded the binary UART transmission
      final lastLog = driver.logHistory.last;
      expect(lastLog.isTx, isTrue);
      expect(lastLog.summary, contains('TX MESH'));
      expect(lastLog.data[0], equals(0x94)); // Meshtastic framing START1
      expect(lastLog.data[1], equals(0xC3)); // Meshtastic framing START2
    });

    test('Receives incoming UART byte stream and translates into native DTN bundle stream', () async {
      await transport.initialize();

      final expectation = expectLater(
        transport.incomingBundles,
        emits(predicate<Bundle>((b) => b.payload == 'RX_FROM_HELTEC_LORA_RADIO')),
      );

      final testBundle = Bundle(
        bundleId: 'bundle_rx_test_02',
        senderPubkey: 'pub_remote_heltec',
        destPubkey: 'all',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 24,
        hopCount: 1,
        priority: BundlePriority.high,
        payload: 'RX_FROM_HELTEC_LORA_RADIO',
        signature: 'sig',
      );

      // Simulate binary packet frame coming in over USB-C OTG cable
      await transport.sendBundle(testBundle);
      final txBytes = driver.logHistory.last.data;

      transport.injectRawUartBytes(txBytes);
      await expectation;
    });
  });
}
