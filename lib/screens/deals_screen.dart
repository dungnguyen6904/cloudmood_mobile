import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CloudmoodDealsScreen extends StatelessWidget {
  const CloudmoodDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> deals = [
      {
        'title': 'Ưu đãi bay thu 20%',
        'code': 'CLOUDMOVE20',
        'desc': 'Giảm ngay 20% khi đặt vé máy bay khứ hồi nội địa trên ứng dụng.',
        'expiry': 'Hạn dùng: 31/12/2026',
        'image': 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=500&auto=format&fit=crop&q=80',
        'category': 'VÉ MÁY BAY',
      },
      {
        'title': 'Combo Phú Quốc Trọn Gói',
        'code': 'PHUQUOC3N2D',
        'desc': 'Vé máy bay + Khách sạn 5 sao chỉ từ 3.890.000đ/người.',
        'expiry': 'Hạn dùng: 15/10/2026',
        'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
        'category': 'COMBO TOUR',
      },
      {
        'title': 'Mã giảm ẩm thực Đà Nẵng',
        'code': 'DANANGFOOD',
        'desc': 'Giảm 50.000đ cho hóa đơn từ 300.000đ tại các nhà hàng đối tác.',
        'expiry': 'Hạn dùng: Hết hạn hôm nay',
        'image': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80',
        'category': 'ẨM THỰC',
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ƯU ĐÃI ĐỘC QUYỀN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mã Giảm Giá & Ưu Đãi Chuyến Đi',
                style: AppTheme.screenTitleStyle,
              ),
              const SizedBox(height: 20),
              
              // List of Deals
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deals.length,
                itemBuilder: (context, index) {
                  final deal = deals[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: AppTheme.premiumCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.network(
                            deal['image']!,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(height: 130, color: Colors.grey[200]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deal['category']!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                deal['title']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                deal['desc']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.35,
                                ),
                              ),
                              const Divider(height: 24, thickness: 0.5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPeach,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primary.withAlpha(50)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.confirmation_num_rounded, color: AppTheme.primary, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          deal['code']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    deal['expiry']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
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
        ),
      ),
    );
  }
}
