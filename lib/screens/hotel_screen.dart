import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class CloudmoodHotelScreen extends StatelessWidget {
  const CloudmoodHotelScreen({super.key});

  void _showWriteReviewDialog(BuildContext context, int placeId, String placeName) {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi đánh giá!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Đánh giá $placeName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn số sao:', style: TextStyle(fontSize: 14, color: AppTheme.subtitleText)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      final isSelected = starVal <= selectedRating;
                      return IconButton(
                        icon: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                          color: AppTheme.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = starVal.toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Bình luận của bạn:', style: TextStyle(fontSize: 14, color: AppTheme.subtitleText)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Chia sẻ cảm nhận của bạn...',
                      prefixIcon: Icons.rate_review_rounded,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy', style: TextStyle(color: AppTheme.subtitleText)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final comment = commentController.text.trim();
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập bình luận!')),
                      );
                      return;
                    }

                    final result = await DatabaseService().createPlaceReview(
                      userId: user.id,
                      placeId: placeId,
                      rating: selectedRating,
                      comment: comment,
                      authorName: user.fullName,
                      authorAvatar: user.avatar ?? '',
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (result != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi đánh giá thành công!'),
                            backgroundColor: AppTheme.green,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Gửi đánh giá'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService().fetchPlaces(categoryName: 'Khách sạn'),
          builder: (context, snapshot) {
            final List<Map<String, dynamic>> hotels = snapshot.data ?? [];
            final bool isLoading = snapshot.connectionState == ConnectionState.waiting && hotels.isEmpty;

            final displayList = hotels.isNotEmpty ? hotels : [
              {
                'id': 1,
                'name': 'The Slate Phuket',
                'address': 'Phuket, Thái Lan',
                'rating': 4.9,
                'price': '3.200.000đ',
                'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=80',
                'priceLevel': r'$$$$',
              },
              {
                'id': 2,
                'name': 'Hanging Gardens of Bali',
                'address': 'Ubud, Bali',
                'rating': 4.8,
                'price': '5.800.000đ',
                'image': 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=500&auto=format&fit=crop&q=80',
                'priceLevel': r'$$$$$',
              },
              {
                'id': 3,
                'name': 'Marina Bay Sands',
                'address': 'Bayfront Avenue, Singapore',
                'rating': 4.7,
                'price': '9.100.000đ',
                'image': 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=500&auto=format&fit=crop&q=80',
                'priceLevel': r'$$$$$',
              },
            ];

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NƠI LƯU TRÚ LÝ TƯỞNG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Khách sạn & Khu nghỉ dưỡng',
                    style: AppTheme.screenTitleStyle,
                  ),
                  const SizedBox(height: 16),
                  
                  // Custom Search Bar for Hotels
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: AppTheme.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.black38, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tìm khách sạn, homestay...',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ))
                  else
                    // List of Hotels
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final hotel = displayList[index];
                        final placeId = hotel['id'] as int? ?? 1;
                        final addressText = hotel['address'] ?? hotel['location'] ?? '';
                        final priceText = hotel['price'] ?? 'Liên hệ';
                        final ratingText = (hotel['rating'] as num?)?.toStringAsFixed(1) ?? '5.0';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: AppTheme.premiumCardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: Image.network(
                                      hotel['image'] ?? '',
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(height: 160, color: Colors.grey[200]),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        hotel['priceLevel'] ?? hotel['tag'] ?? 'Hot',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            hotel['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.darkText,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: AppTheme.amber, size: 18),
                                            const SizedBox(width: 2),
                                            Text(
                                              ratingText,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, color: AppTheme.subtitleText, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            addressText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.subtitleText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24, thickness: 0.5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Giá từ',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                            Text(
                                              priceText,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.primary,
                                                side: const BorderSide(color: AppTheme.primary),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              onPressed: () => _showWriteReviewDialog(
                                                context,
                                                placeId,
                                                hotel['name'] ?? 'Khách sạn',
                                              ),
                                              child: const Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Đang kết nối để đặt phòng tại ${hotel['name']}...')),
                                                );
                                              },
                                              child: const Text('Đặt phòng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
