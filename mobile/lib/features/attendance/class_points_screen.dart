import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/attendance_repository.dart';
import 'models/session_model.dart';

class ClassPointsScreen extends ConsumerWidget {
  final int classId;

  const ClassPointsScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(classPointsProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peringkat Poin Kelas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classPointsProvider(classId));
          await ref.read(classPointsProvider(classId).future);
        },
        child: pointsAsync.when(
          data: (points) {
            if (points.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Riwayat Poin',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Poin akan dicatat resmi setelah sesi presensi difinalisasi.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: points.length,
              itemBuilder: (context, index) {
                final item = points[index];
                return _PointCard(rank: index + 1, item: item);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 54, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Gagal memuat poin: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(classPointsProvider(classId)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  final int rank;
  final StudentPointItem item;

  const _PointCard({required this.rank, required this.item});

  Widget _buildRankBadge() {
    if (rank == 1) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFFFD700), // Gold
        child: Icon(Icons.emoji_events, size: 20, color: Colors.white),
      );
    } else if (rank == 2) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFC0C0C0), // Silver
        child: Icon(Icons.emoji_events, size: 20, color: Colors.white),
      );
    } else if (rank == 3) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFCD7F32), // Bronze
        child: Icon(Icons.emoji_events, size: 20, color: Colors.white),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.indigo.shade50,
      foregroundColor: Colors.indigo,
      child: Text(
        '$rank',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = item.totalPoints >= 0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: _buildRankBadge(),
        title: Text(
          item.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'NIM: ${item.nim}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Text(
            '${item.totalPoints > 0 ? "+" : ""}${item.totalPoints} Poin',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      ),
    );
  }
}
