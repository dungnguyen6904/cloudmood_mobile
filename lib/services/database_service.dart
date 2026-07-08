import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final ValueNotifier<int> refreshTrigger = ValueNotifier<int>(0);
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  final _supabase = Supabase.instance.client;
  SupabaseClient? _serviceRoleClient;

  SupabaseClient get _adminClient {
    _serviceRoleClient ??= SupabaseClient(
      'https://mrulzaiktzljosdgfivt.supabase.co',
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '',
    );
    return _serviceRoleClient!;
  }

  /// Checks if categories and places are empty in the database, and if so, seeds them with default data
  Future<void> checkAndSeedData() async {
    try {
      // Create a temporary SupabaseClient with the service_role key to bypass RLS policies during seeding
      final seedClient = SupabaseClient(
        'https://mrulzaiktzljosdgfivt.supabase.co',
        dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '',
      );

      final categoryCheck = await seedClient.from('Category').select('id').limit(1);
      if (categoryCheck.isEmpty) {
        debugPrint('Seeding categories...');
        
        // 1. Seed Categories
        final categories = [
          {'name': 'Khách sạn'},
          {'name': 'Điểm đến'},
          {'name': 'Gợi ý'},
          {'name': 'Cẩm nang'},
        ];
        
        final categoryInsert = await seedClient.from('Category').insert(categories).select();
        debugPrint('Categories seeded: $categoryInsert');

        // Extract IDs based on name
        int getCategoryId(String name) {
          final matched = categoryInsert.firstWhere((cat) => cat['name'] == name, orElse: () => {'id': 1});
          return matched['id'] as int;
        }

        final hotelCatId = getCategoryId('Khách sạn');
        final destinationCatId = getCategoryId('Điểm đến');
        final guidesCatId = getCategoryId('Cẩm nang');

        // 2. Seed Places
        debugPrint('Seeding default places...');
        final places = [
          // Hotels
          {
            'name': 'The Slate Phuket',
            'description': 'Khu nghỉ dưỡng nghệ thuật bên bờ biển Indigo, Phuket.',
            'latitude': 8.0858,
            'longitude': 98.3009,
            'address': 'Phuket, Thái Lan',
            'price': '3.200.000đ',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': hotelCatId,
            'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=80',
            'rating': 4.9,
            'userRatingCount': 120,
            'phone': '+66 76 327 006',
            'website': 'https://theslatephuket.com',
            'priceLevel': r'$$$$',
            'amenities': ['Bể bơi', 'Spa', 'Wifi miễn phí', 'Nhà hàng', 'Gym'],
          },
          {
            'name': 'Hanging Gardens of Bali',
            'description': 'Khu nghỉ dưỡng sang trọng giữa thung lũng rừng nhiệt đới Ubud.',
            'latitude': -8.4116,
            'longitude': 115.2818,
            'address': 'Ubud, Bali',
            'price': '5.800.000đ',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': hotelCatId,
            'image': 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=500&auto=format&fit=crop&q=80',
            'rating': 4.8,
            'userRatingCount': 98,
            'phone': '+62 361 982700',
            'website': 'https://hanginggardenssofbali.com',
            'priceLevel': r'$$$$$',
            'amenities': ['Bể bơi vô cực', 'Spa', 'Wifi miễn phí', 'Bar', 'Đưa đón'],
          },
          {
            'name': 'Marina Bay Sands',
            'description': 'Biểu tượng sang trọng và đẳng cấp của Singapore với bể bơi vô cực trên tầng thượng.',
            'latitude': 1.2847,
            'longitude': 103.8610,
            'address': 'Bayfront Avenue, Singapore',
            'price': '9.100.000đ',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': hotelCatId,
            'image': 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=500&auto=format&fit=crop&q=80',
            'rating': 4.7,
            'userRatingCount': 560,
            'phone': '+65 6688 8868',
            'website': 'https://marinabaysands.com',
            'priceLevel': r'$$$$$',
            'amenities': ['Bể bơi sân thượng', 'Casino', 'Wifi miễn phí', 'Shopping Mall', 'Gym'],
          },
          
          // Destinations
          {
            'name': 'Đà Nẵng',
            'description': 'Thành phố của những cây cầu, bãi biển Mỹ Khê cát trắng và bán đảo Sơn Trà.',
            'latitude': 16.0544,
            'longitude': 108.2022,
            'address': 'Đà Nẵng, Việt Nam',
            'price': 'Miễn phí',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': destinationCatId,
            'image': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&auto=format&fit=crop&q=80',
            'rating': 4.8,
            'userRatingCount': 1200,
            'phone': '1800-1000',
            'website': 'https://danangtourism.gov.vn',
            'priceLevel': r'$$',
            'amenities': ['Bãi biển', 'Chụp ảnh', 'Leo núi', 'Ẩm thực', 'Chợ đêm'],
          },
          {
            'name': 'Hội An',
            'description': 'Phố cổ đèn lồng cổ kính ven sông Thu Bồn, di sản văn hóa thế giới.',
            'latitude': 15.8801,
            'longitude': 108.3380,
            'address': 'Quảng Nam, Việt Nam',
            'price': '120.000đ',
            'openTime': '07:30:00+07:00',
            'closeTime': '22:00:00+07:00',
            'categoryId': destinationCatId,
            'image': 'https://images.unsplash.com/photo-1528127269322-539801943592?w=400&auto=format&fit=crop&q=80',
            'rating': 4.7,
            'userRatingCount': 940,
            'phone': 'N/A',
            'website': 'https://hoiantourism.info',
            'priceLevel': r'$',
            'amenities': ['Phố đi bộ', 'Thuyền đăng', 'Chụp ảnh', 'Lớp nấu ăn', 'Cafe cổ'],
          },
          {
            'name': 'Nha Trang',
            'description': 'Vịnh biển xanh mát lành, thiên đường vui chơi giải trí VinWonders và hải sản tươi sống.',
            'latitude': 12.2388,
            'longitude': 109.1967,
            'address': 'Khánh Hòa, Việt Nam',
            'price': 'Miễn phí',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': destinationCatId,
            'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&auto=format&fit=crop&q=80',
            'rating': 4.6,
            'userRatingCount': 680,
            'phone': 'N/A',
            'website': 'N/A',
            'priceLevel': r'$$',
            'amenities': ['Bãi biển', 'Lặn ngắm san hô', 'Tắm bùn', 'Hải sản', 'Cáp treo'],
          },
          {
            'name': 'Đà Lạt',
            'description': 'Thành phố ngàn hoa mù sương, khí hậu ôn đới quanh năm dễ chịu và các quán cafe lãng mạn.',
            'latitude': 11.9404,
            'longitude': 108.4583,
            'address': 'Lâm Đồng, Việt Nam',
            'price': 'Miễn phí',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': destinationCatId,
            'image': 'https://images.unsplash.com/photo-1583244532610-2a234e7c3eca?w=400&auto=format&fit=crop&q=80',
            'rating': 4.8,
            'userRatingCount': 1050,
            'phone': 'N/A',
            'website': 'N/A',
            'priceLevel': r'$$',
            'amenities': ['Khí hậu lạnh', 'Đồi thông', 'Cafe mây', 'Chợ đêm', 'Vườn dâu'],
          },
          
          // Featured Guide / Travel tips
          {
            'name': 'Bali Hidden Paradise',
            'description': 'Hướng dẫn chi tiết càn quét Bali từ những góc chụp ảnh siêu đẹp đến ẩm thực bản địa độc đáo.',
            'latitude': -8.4095,
            'longitude': 115.1889,
            'address': 'Bali, Indonesia',
            'price': 'Miễn phí',
            'openTime': '00:00:00+00:00',
            'closeTime': '23:59:59+00:00',
            'categoryId': guidesCatId,
            'image': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600&auto=format&fit=crop&q=80',
            'rating': 4.9,
            'userRatingCount': 76,
            'phone': 'N/A',
            'website': 'N/A',
            'priceLevel': r'$',
            'amenities': ['Chụp ảnh', 'Xe máy', 'Ngắm hoàng hôn', 'Beach club'],
          }
        ];
        
        await seedClient.from('Place').insert(places);
        debugPrint('Places seeded successfully.');
      }
    } catch (e) {
      debugPrint('Error seeding data: $e');
    }
  }

  /// Fetches places based on category name
  Future<List<Map<String, dynamic>>> fetchPlaces({String? categoryName}) async {
    try {
      if (categoryName != null) {
        // First get category ID
        final categoryResponse = await _supabase
            .from('Category')
            .select('id')
            .eq('name', categoryName)
            .maybeSingle();
            
        if (categoryResponse != null) {
          final catId = categoryResponse['id'] as int;
          final response = await _supabase
              .from('Place')
              .select('*, Category(*)')
              .eq('categoryId', catId);
          return List<Map<String, dynamic>>.from(response);
        }
      }
      
      final response = await _supabase.from('Place').select('*, Category(*)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching places: $e');
      return [];
    }
  }

  /// Fetches all itineraries created by the user
  Future<List<Map<String, dynamic>>> fetchUserItineraries(int userId) async {
    try {
      final response = await _adminClient
          .from('Itinerary')
          .select('*, ItinerarySection(*), ItineraryDetail(*, Place(*, Category(*))), ItinerarySavedPlace(*, Place(*, Category(*)))')
          .eq('userId', userId)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user itineraries: $e');
      return [];
    }
  }

  /// Creates a new user itinerary in the database
  Future<Map<String, dynamic>?> createUserItinerary({
    required int userId,
    required String title,
    required String destination,
    required DateTime startDate,
    required int days,
    required int budget,
    required String companion,
    required String pace,
    required List<String> categories,
    required List<String> amenities,
  }) async {
    try {
      final data = {
        'title': title,
        'destination': destination,
        'startDate': startDate.toIso8601String().substring(0, 10),
        'days': days,
        'budget': budget,
        'companion': companion,
        'pace': pace,
        'categories': categories,
        'amenities': amenities,
        'userId': userId,
      };
      
      final response = await _supabase
          .from('Itinerary')
          .insert(data)
          .select()
          .single();
          
      // Insert default section "Địa điểm tham quan" for the new itinerary
      await _adminClient.from('ItinerarySection').insert({
        'itineraryId': response['id'],
        'name': 'Địa điểm tham quan',
        'colorCode': '4282057462', // Default blue color
        'iconCode': Icons.looks_one_rounded.codePoint,
        'sortOrder': 0,
      });
          
      refreshTrigger.value++; // Trigger reactive update
      return response;
    } catch (e) {
      debugPrint('Error creating user itinerary: $e');
      return null;
    }
  }

  /// Fetches reviews submitted by the user
  Future<List<Map<String, dynamic>>> fetchUserReviews(int userId) async {
    try {
      final response = await _supabase
          .from('Review')
          .select('*, Place(*)')
          .eq('userId', userId)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user reviews: $e');
      return [];
    }
  }

  /// Creates a review for a specific place
  Future<Map<String, dynamic>?> createPlaceReview({
    required int userId,
    required int placeId,
    required double rating,
    required String comment,
    required String authorName,
    required String authorAvatar,
  }) async {
    try {
      final data = {
        'rating': rating,
        'comment': comment,
        'userId': userId,
        'placeId': placeId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'publishedDate': DateTime.now().toIso8601String().substring(0, 10),
        'source': 'LOCAL',
      };
      
      final response = await _supabase
          .from('Review')
          .insert(data)
          .select()
          .single();
          
      refreshTrigger.value++; // Trigger reactive update
      return response;
    } catch (e) {
      debugPrint('Error creating place review: $e');
      return null;
    }
  }

  /// Checks if a destination city is supported (i.e. has places in the database matching it)
  Future<bool> isDestinationSupported(String cityName) async {
    try {
      // Search for places where address contains cityName (case-insensitive)
      final response = await _supabase
          .from('Place')
          .select('id')
          .ilike('address', '%$cityName%')
          .limit(1);
          
      if (response.isNotEmpty) {
        return true;
      }
      
      // Try to check name as fallback
      final responseName = await _supabase
          .from('Place')
          .select('id')
          .ilike('name', '%$cityName%')
          .limit(1);
          
      return responseName.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking destination support: $e');
      return false;
    }
  }

  /// Fetches a single itinerary with its details and places by ID
  Future<Map<String, dynamic>?> fetchItineraryById(int itineraryId) async {
    try {
      final response = await _adminClient
          .from('Itinerary')
          .select('*, ItinerarySection(*), ItineraryDetail(*, Place(*, Category(*))), ItinerarySavedPlace(*, Place(*, Category(*)))')
          .eq('id', itineraryId)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error fetching itinerary by id: $e');
      return null;
    }
  }

  /// Adds a place to an itinerary's day details
  Future<Map<String, dynamic>?> addPlaceToItinerary({
    required int itineraryId,
    required int placeId,
    required int day,
    String arrivalTime = '09:00:00+07',
    String leaveTime = '11:00:00+07',
    int sortOrder = 0,
  }) async {
    try {
      final data = {
        'itineraryId': itineraryId,
        'placeId': placeId,
        'day': day,
        'arrivalTime': arrivalTime,
        'leaveTime': leaveTime,
        'sortOrder': sortOrder,
      };
      final response = await _adminClient
          .from('ItineraryDetail')
          .insert(data)
          .select('*, Place(*, Category(*))')
          .single();
      refreshTrigger.value++; // Trigger reactive update
      return response;
    } catch (e) {
      debugPrint('Error adding place to itinerary: $e');
      return null;
    }
  }

  /// Deletes a place from an itinerary's details
  Future<bool> deletePlaceFromItinerary(int detailId) async {
    try {
      await _adminClient
          .from('ItineraryDetail')
          .delete()
          .eq('id', detailId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error deleting place from itinerary: $e');
      return false;
    }
  }

  /// Upserts a section for an itinerary (inserts if not exists, otherwise updates)
  Future<bool> upsertItinerarySection({
    required int itineraryId,
    required String name,
    required String colorCode,
    required int iconCode,
    int sortOrder = 0,
  }) async {
    try {
      // First, try to find if it exists
      final existing = await _adminClient
          .from('ItinerarySection')
          .select('id')
          .eq('itineraryId', itineraryId)
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        // Update
        await _adminClient
            .from('ItinerarySection')
            .update({
              'colorCode': colorCode,
              'iconCode': iconCode,
              'sortOrder': sortOrder,
            })
            .eq('id', existing['id']);
      } else {
        // Insert
        await _adminClient
            .from('ItinerarySection')
            .insert({
              'itineraryId': itineraryId,
              'name': name,
              'colorCode': colorCode,
              'iconCode': iconCode,
              'sortOrder': sortOrder,
            });
      }
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint('Error upserting itinerary section: $e');
      return false;
    }
  }

  /// Deletes an itinerary section by name
  Future<bool> deleteItinerarySection(int itineraryId, String name) async {
    try {
      await _adminClient
          .from('ItinerarySection')
          .delete()
          .eq('itineraryId', itineraryId)
          .eq('name', name);
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint('Error deleting itinerary section: $e');
      return false;
    }
  }

  /// Adds a place or note to an itinerary's saved places (Overview)
  Future<Map<String, dynamic>?> addPlaceToSaved({
    required int itineraryId,
    int? placeId,
    required String section,
    String? noteText,
    int? sortOrder,
  }) async {
    try {
      int finalSortOrder = sortOrder ?? 0;
      if (sortOrder == null) {
        final response = await _adminClient
            .from('ItinerarySavedPlace')
            .select('sortOrder')
            .eq('itineraryId', itineraryId)
            .eq('section', section)
            .order('sortOrder', ascending: false)
            .limit(1);
        if (response != null && (response as List).isNotEmpty) {
          finalSortOrder = ((response as List)[0]['sortOrder'] ?? 0) + 1;
        }
      }

      final data = {
        'itineraryId': itineraryId,
        if (placeId != null) 'placeId': placeId,
        'section': section,
        if (noteText != null) 'noteText': noteText,
        'sortOrder': finalSortOrder,
      };
      final response = await _adminClient
          .from('ItinerarySavedPlace')
          .insert(data)
          .select('*, Place(*, Category(*))')
          .single();
      refreshTrigger.value++; // Trigger reactive update
      return response;
    } catch (e) {
      debugPrint('Error adding to saved list: $e');
      return null;
    }
  }

  /// Deletes all saved places or notes in a specific section
  Future<bool> deleteSavedPlacesBySection(int itineraryId, String section) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .delete()
          .eq('itineraryId', itineraryId)
          .eq('section', section);
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint('Error deleting saved places by section: $e');
      return false;
    }
  }

  /// Deletes a place or note from saved places
  Future<bool> deletePlaceFromSaved(int savedId) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .delete()
          .eq('id', savedId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error deleting from saved list: $e');
      return false;
    }
  }

  /// Deletes multiple saved places
  Future<bool> deleteMultipleSavedPlaces(List<int> itemIds) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .delete()
          .inFilter('id', itemIds);
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint('Error deleting multiple saved places: $e');
      return false;
    }
  }

  /// Moves multiple saved places to a new section
  Future<bool> moveSavedPlaces(List<int> itemIds, String targetSection) async {
    try {
      final itemsToMove = await _adminClient
          .from('ItinerarySavedPlace')
          .select('id, itineraryId, placeId, noteText')
          .inFilter('id', itemIds);
          
      if (itemsToMove.isEmpty) return true;

      final itId = itemsToMove.first['itineraryId'] as int;

      final existingItems = await _adminClient
          .from('ItinerarySavedPlace')
          .select('placeId')
          .eq('itineraryId', itId)
          .eq('section', targetSection)
          .not('placeId', 'is', null);

      final existingPlaceIds = existingItems
          .map((item) => item['placeId'] as int)
          .toSet();

      final idsToMove = <int>[];
      final idsToDelete = <int>[]; // to simulate move if it's already there
      final newPlaceIdsInTarget = <int>{};

      for (var item in itemsToMove) {
        final isNote = item['placeId'] == null;
        final placeId = item['placeId'] as int?;
        
        if (!isNote && placeId != null) {
          if (existingPlaceIds.contains(placeId) || newPlaceIdsInTarget.contains(placeId)) {
            idsToDelete.add(item['id'] as int);
            continue;
          }
          newPlaceIdsInTarget.add(placeId);
        }
        idsToMove.add(item['id'] as int);
      }

      if (idsToMove.isNotEmpty) {
        await _adminClient
            .from('ItinerarySavedPlace')
            .update({'section': targetSection})
            .inFilter('id', idsToMove);
      }
      if (idsToDelete.isNotEmpty) {
        await _adminClient
            .from('ItinerarySavedPlace')
            .delete()
            .inFilter('id', idsToDelete);
      }
      
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint('Error moving saved places: $e');
      return false;
    }
  }

  /// Copies multiple saved places to a new section
  Future<bool> copySavedPlaces(List<int> itemIds, String targetSection) async {
    try {
      // First, fetch the items to duplicate
      final itemsToCopy = await _adminClient
          .from('ItinerarySavedPlace')
          .select()
          .inFilter('id', itemIds);
          
      if (itemsToCopy.isEmpty) return true;

      final itId = itemsToCopy.first['itineraryId'] as int;

      final existingItems = await _adminClient
          .from('ItinerarySavedPlace')
          .select('placeId')
          .eq('itineraryId', itId)
          .eq('section', targetSection)
          .not('placeId', 'is', null);

      final existingPlaceIds = existingItems
          .map((item) => item['placeId'] as int)
          .toSet();

      final newPlaceIdsInTarget = <int>{};
      
      // Modify them for insertion
      final List<Map<String, dynamic>> newItems = [];
      for (var item in itemsToCopy) {
        final isNote = item['placeId'] == null;
        final placeId = item['placeId'] as int?;

        if (!isNote && placeId != null) {
          if (existingPlaceIds.contains(placeId) || newPlaceIdsInTarget.contains(placeId)) {
            continue; // Skip copying duplicate places
          }
          newPlaceIdsInTarget.add(placeId);
        }

        final Map<String, dynamic> newItem = Map<String, dynamic>.from(item as Map);
        newItem.remove('id'); // Remove id to let DB auto-generate
        newItem.remove('createdAt');
        newItem['section'] = targetSection;
        newItems.add(newItem);
      }

      if (newItems.isNotEmpty) {
        await _adminClient.from('ItinerarySavedPlace').insert(newItems);
      }
      refreshTrigger.value++;
      
      return true;
    } catch (e) {
      debugPrint('Error copying saved places: $e');
      return false;
    }
  }

  /// Updates the sort order of a saved place or note
  Future<bool> updateSavedItemOrder(int itemId, int newSortOrder) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .update({'sortOrder': newSortOrder})
          .eq('id', itemId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error updating saved item order: $e');
      return false;
    }
  }

  /// Updates the reactions list of a saved note
  Future<bool> updateSavedItemReactions(int itemId, List<dynamic> reactions) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .update({'reactions': reactions})
          .eq('id', itemId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error updating saved item reactions: $e');
      return false;
    }
  }

  /// Updates the collapse state of a saved note
  Future<bool> updateSavedItemCollapse(int itemId, bool isCollapsed) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .update({'isCollapsed': isCollapsed})
          .eq('id', itemId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error updating saved item collapse: $e');
      return false;
    }
  }
  /// Updates the text of a saved note
  Future<bool> updateSavedItemText(int itemId, String text) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .update({'noteText': text})
          .eq('id', itemId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error updating saved item text: $e');
      return false;
    }
  }

  /// Fetches checklist templates with categories and items
  Future<List<Map<String, dynamic>>> fetchChecklistTemplates() async {
    try {
      final cats = await _supabase.from('ChecklistTemplateCategory').select('*');
      final items = await _supabase.from('ChecklistTemplateItem').select('*');
      
      final List<Map<String, dynamic>> result = [];
      for (var cat in cats) {
        final catId = cat['id'];
        final catItems = items.where((it) => it['categoryId'] == catId || it['categoryid'] == catId).toList();
        result.add({
          ...cat,
          'items': catItems,
        });
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching checklist templates: $e');
      return [];
    }
  }

  /// Updates the todoItems jsonb array of a saved checklist
  Future<bool> updateSavedItemTodoItems(int itemId, List<dynamic> todoItems) async {
    try {
      await _adminClient
          .from('ItinerarySavedPlace')
          .update({'todoItems': todoItems})
          .eq('id', itemId);
      refreshTrigger.value++; // Trigger reactive update
      return true;
    } catch (e) {
      debugPrint('Error updating saved item todo items: $e');
      return false;
    }
  }

  /// Fetches places located in/near a specific destination city
  Future<List<Map<String, dynamic>>> fetchPlacesByDestination(String cityName) async {
    try {
      final response = await _supabase
          .from('Place')
          .select('*, Category(*)')
          .or('address.ilike.%$cityName%,name.ilike.%$cityName%')
          .order('rating', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching places by destination: $e');
      return [];
    }
  }
}

