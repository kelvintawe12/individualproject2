import 'package:flutter/material.dart';
import '../screens/listing_detail_screen.dart';

class ListingCard extends StatefulWidget {
  ListingCard({Key? key, this.isOwner = false, this.listing}) : super(key: key);

  final Map<String, dynamic>? listing;
  final bool isOwner;

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  double _scale = 1.0;

  void _onTapDown(_) {
    setState(() => _scale = 0.98);
  }

  void _onTapUp(_) {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
  final id = widget.listing != null ? widget.listing!['id'] ?? '' : '';
  final title = widget.listing != null ? widget.listing!['title'] ?? 'Untitled' : 'Data Structures & Algorithms';
  final author = widget.listing != null ? widget.listing!['author'] ?? 'Unknown' : 'Themail V Dermon';
    final tag = 'coverHero-$id-$title';
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (details) => _onTapUp(details),
        onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: widget.listing, heroTag: tag, isOwner: widget.isOwner)));
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: tag,
                  child: Container(
                    width: 64,
                    height: 96,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.grey[300]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: (widget.listing != null && widget.listing!['imageUrl'] != null)
                          ? Image.network(widget.listing!['imageUrl'], fit: BoxFit.cover)
                          : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(author, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0B429), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Like New', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          const Text('• 3 days ago', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Swap'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
