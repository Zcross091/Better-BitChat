import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../transports/simulator_transport.dart';
import '../../core/models/bundle.dart';
import '../theme/app_theme.dart';

class MeshSimulatorScreen extends StatefulWidget {
  final SimulatorTransport simulator;
  final Function(Bundle) onSendSimulatedBundle;

  const MeshSimulatorScreen({
    super.key,
    required this.simulator,
    required this.onSendSimulatedBundle,
  });

  @override
  State<MeshSimulatorScreen> createState() => _MeshSimulatorScreenState();
}

class _MeshSimulatorScreenState extends State<MeshSimulatorScreen> {
  final TextEditingController _msgController = TextEditingController();
  SimNode? _selectedNode;

  @override
  Widget build(BuildContext me) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.network, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Mesh Topology Simulator'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Reset Topology',
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SimNode>>(
        stream: widget.simulator.onNodesChanged,
        initialData: widget.simulator.nodes,
        builder: (context, snapshot) {
          final nodes = snapshot.data ?? [];

          return StreamBuilder<List<SimLink>>(
            stream: widget.simulator.onLinksChanged,
            initialData: const [],
            builder: (context, linkSnapshot) {
              final links = linkSnapshot.data ?? [];

              return Column(
                children: [
                  // Top control info banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppTheme.surface,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.radio, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${nodes.length} Nodes Active | ${links.length} Active Radio Links',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.success),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: AppTheme.success),
                              SizedBox(width: 6),
                              Text('Real-time DTN Sim', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Visual Graph Canvas
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Stack(
                        children: [
                          // Gridlines background
                          CustomPaint(
                            size: Size.infinite,
                            painter: GraphPainter(nodes: nodes, links: links, selectedNodeId: _selectedNode?.id),
                          ),

                          // Render nodes on canvas
                          ...nodes.map((node) {
                            return Positioned(
                              left: node.x - 30,
                              top: node.y - 30,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    node.x += details.delta.dx;
                                    node.y += details.delta.dy;
                                    widget.simulator.updateNodePosition(node.id, node.x, node.y);
                                  });
                                },
                                onTap: () {
                                  setState(() {
                                    _selectedNode = node;
                                  });
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: node.isOnline
                                            ? (node.isGateway ? AppTheme.secondary : AppTheme.surfaceElevated)
                                            : Colors.grey.shade900,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedNode?.id == node.id
                                              ? AppTheme.primary
                                              : (node.isOnline ? AppTheme.primary.withOpacity(0.6) : Colors.red),
                                          width: _selectedNode?.id == node.id ? 3 : 1.5,
                                        ),
                                        boxShadow: [
                                          if (node.isOnline)
                                            BoxShadow(
                                              color: (node.isGateway ? AppTheme.secondary : AppTheme.primary).withOpacity(0.25),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                        ],
                                      ),
                                      child: Icon(
                                        node.isGateway
                                            ? LucideIcons.globe
                                            : (node.id == 'node_a' ? LucideIcons.smartphone : LucideIcons.cpu),
                                        color: node.isOnline ? AppTheme.textPrimary : Colors.grey,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        node.name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: node.isOnline ? AppTheme.textPrimary : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Node Detail & Inject Panel
                  if (_selectedNode != null) _buildNodeDetailPanel(_selectedNode!),

                  // Send message into simulator
                  _buildSimulatedSendBar(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNodeDetailPanel(SimNode node) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(node.isGateway ? LucideIcons.globe : LucideIcons.smartphone, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(
                  'Bundles in Store: ${node.store.count} | Range: ${node.range.toInt()}m',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                widget.simulator.toggleNodeOnline(node.id);
              });
            },
            icon: Icon(
              node.isOnline ? LucideIcons.power : LucideIcons.wifiOff,
              size: 16,
              color: node.isOnline ? AppTheme.error : AppTheme.success,
            ),
            label: Text(node.isOnline ? 'Disconnect Node' : 'Reconnect Node'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedSendBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.surface,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Simulate sending DTN bundle from Alice...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final text = _msgController.text.trim();
                if (text.isEmpty) return;

                final bundle = Bundle(
                  bundleId: Bundle.generateBundleId(
                    senderPubkey: 'pub_alice_ed25519_01',
                    destPubkey: 'pub_eve_ed25519_05',
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    nonce: UniqueKey().toString(),
                  ),
                  senderPubkey: 'pub_alice_ed25519_01',
                  destPubkey: 'pub_eve_ed25519_05',
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  ttlHours: 24,
                  hopCount: 0,
                  priority: BundlePriority.high,
                  payload: text,
                  signature: 'sig_mock_ed25519_alice',
                );

                widget.onSendSimulatedBundle(bundle);
                widget.simulator.injectSimulatedBundle('node_a', bundle);
                _msgController.clear();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bundle injected into Alice! Watch it hop across the mesh...')),
                );
              },
              child: const Row(
                children: [
                  Icon(LucideIcons.send, size: 16),
                  SizedBox(width: 6),
                  Text('Inject'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<SimNode> nodes;
  final List<SimLink> links;
  final String? selectedNodeId;

  GraphPainter({required this.nodes, required this.links, this.selectedNodeId});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Radio Coverage Range circles
    for (final node in nodes) {
      if (!node.isOnline) continue;
      final rangePaint = Paint()
        ..color = (node.id == selectedNodeId ? AppTheme.primary : AppTheme.border).withOpacity(0.08)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = (node.id == selectedNodeId ? AppTheme.primary : AppTheme.border).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(Offset(node.x, node.y), node.range, rangePaint);
      canvas.drawCircle(Offset(node.x, node.y), node.range, borderPaint);
    }

    // 2. Draw Active Radio Links
    for (final link in links) {
      final nodeA = nodes.firstWhere((n) => n.id == link.nodeAId);
      final nodeB = nodes.firstWhere((n) => n.id == link.nodeBId);

      final linkPaint = Paint()
        ..color = AppTheme.primary.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(nodeA.x, nodeA.y), Offset(nodeB.x, nodeB.y), linkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
