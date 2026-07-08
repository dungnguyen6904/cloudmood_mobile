import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_style_sheet.dart';
import 'trip_ai_chat_screen.dart';

class TripOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> itinerary;

  const TripOverviewScreen({super.key, required this.itinerary});

  @override
  State<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends State<TripOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _itineraryData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _savedPlaces = [];

  // Overview Tab section names
  final List<String> _sectionNames = [];
  final Map<String, TextEditingController> _searchControllers = {};
  final Map<String, List<Map<String, dynamic>>> _searchResults = {};

  // For inline section title editing
  String? _editingSection;
  final TextEditingController _sectionTitleController = TextEditingController();
  final FocusNode _sectionTitleFocusNode = FocusNode();

  final Map<String, Color> _sectionColors = {};
  final Map<String, IconData> _sectionIcons = {};
  final Map<String, ExpansionTileController> _expansionControllers = {};

  bool _isSelectionMode = false;
  Set<int> _selectedItemIds = {};
  Set<String> _selectedSections = {};
  final List<Color> _availableColors = [
    Colors.green,
    Colors.tealAccent,
    Colors.lightBlue,
    Colors.blue,
    Colors.deepPurple,
    Colors.pinkAccent,
    Colors.orange,
    Colors.orangeAccent,
    const Color(0xFF2E7D32),
    const Color(0xFF00695C),
    const Color(0xFF1565C0),
    const Color(0xFF283593),
    const Color(0xFF6A1B9A),
    const Color(0xFFAD1457),
    Colors.brown,
    const Color(0xFF5D4037),
  ];

  // Expense Tab custom items
  List<Map<String, dynamic>> _customExpenses = [];

  // Map state
  bool _isMapExpanded = false;
  LatLng? _mapCenter;
  bool _isDragging = false;
  double? _dragHeight;

  // AI Dialog state
  bool _isGeneratingAI = false;
  OverlayEntry? _currentNotification;
  int? _editingNoteId;

  @override
  void initState() {
    super.initState();
    _itineraryData = widget.itinerary;
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _currentNotification?.remove();
    _currentNotification = null;
    _tabController.dispose();
    for (var controller in _searchControllers.values) {
      controller.dispose();
    }
    _sectionTitleController.dispose();
    _sectionTitleFocusNode.dispose();
    super.dispose();
  }

  void _saveSectionTitle(String oldTitle, String newTitle) {
    if (newTitle.trim().isEmpty || newTitle == oldTitle) {
      setState(() {
        _editingSection = null;
      });
      return;
    }
    setState(() {
      final index = _sectionNames.indexOf(oldTitle);
      if (index != -1) {
        _sectionNames[index] = newTitle;
        if (_searchControllers.containsKey(oldTitle)) {
          _searchControllers[newTitle] = _searchControllers.remove(oldTitle)!;
        }
        if (_searchResults.containsKey(oldTitle)) {
          _searchResults[newTitle] = _searchResults.remove(oldTitle)!;
        }
        for (var d in _savedPlaces) {
          if (d['section'] == oldTitle) {
            d['section'] = newTitle;
          }
        }
        if (_sectionColors.containsKey(oldTitle)) {
          _sectionColors[newTitle] = _sectionColors.remove(oldTitle)!;
        }
        if (_sectionIcons.containsKey(oldTitle)) {
          _sectionIcons[newTitle] = _sectionIcons.remove(oldTitle)!;
        }
      }
      _editingSection = null;
    });

    // Sync the rename to database (delete old, insert new)
    DatabaseService().deleteItinerarySection(
      _itineraryData['id'] as int,
      oldTitle,
    );
    _syncSectionsToDatabase();
  }

  void _showSectionStyleSheet(
    BuildContext context,
    String sectionName, {
    int initialTabIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SectionStyleSheet(
        initialSection: sectionName,
        sections: _sectionNames,
        savedPlaces: _savedPlaces,
        sectionColors: _sectionColors,
        sectionIcons: _sectionIcons,
        initialTabIndex: initialTabIndex,
        onSaved: (newSections, newPlaces, newColors, newIcons) {
          setState(() {
            _sectionNames.clear();
            _sectionNames.addAll(newSections);
            _savedPlaces = newPlaces;
            _sectionColors.clear();
            _sectionColors.addAll(newColors);
            _sectionIcons.clear();
            _sectionIcons.addAll(newIcons);
          });
          _syncSectionsToDatabase();
        },
      ),
    );
  }

  void _showPremiumNotification({
    required String message,
    required IconData icon,
    required Color color,
    String? title,
  }) {
    if (!mounted) return;

    // Clear existing notification
    _currentNotification?.remove();
    _currentNotification = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, val, child) {
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -20 * (1.0 - val)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null)
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                                fontSize: 13,
                              ),
                            ),
                          Text(
                            message,
                            style: TextStyle(
                              color: title != null
                                  ? AppTheme.subtitleText
                                  : AppTheme.darkText,
                              fontSize: 12,
                              fontWeight: title != null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _currentNotification?.remove();
                        _currentNotification = null;
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.subtitleText,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentNotification = entry;
    overlay.insert(entry);

    // Auto-remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted && _currentNotification == entry) {
        entry.remove();
        if (_currentNotification == entry) {
          _currentNotification = null;
        }
      }
    });
  }

  Future<void> _fetchMapData() async {
    final apiKey = dotenv.env['GEOAPIFY_API_KEY'];
    if (apiKey == null) return;
    final String dest = _itineraryData['destination'] ?? '';
    final url = Uri.parse(
      'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeComponent(dest)}&limit=1&apiKey=$apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final props = data['features'][0]['properties'];
          final double lat = (props['lat'] as num).toDouble();
          final double lon = (props['lon'] as num).toDouble();
          if (mounted) {
            setState(() {
              _mapCenter = LatLng(lat, lon);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching map: $e');
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    // Fetch map data in background
    if (_mapCenter == null) {
      _fetchMapData();
    }
    final itineraryId = _itineraryData['id'] as int;

    // Fetch refreshed itinerary details
    final refreshed = await DatabaseService().fetchItineraryById(itineraryId);
    if (refreshed != null) {
      _itineraryData = refreshed;
      _details = List<Map<String, dynamic>>.from(
        refreshed['ItineraryDetail'] ?? [],
      );
      final rawSaved = List<Map<String, dynamic>>.from(
        refreshed['ItinerarySavedPlace'] ?? [],
      );
      rawSaved.sort((a, b) {
        final int orderA = a['sortOrder'] ?? 0;
        final int orderB = b['sortOrder'] ?? 0;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        final int idA = a['id'] ?? 0;
        final int idB = b['id'] ?? 0;
        return idA.compareTo(idB);
      });
      _savedPlaces = rawSaved;
    }

    // Fetch places near destination for Explore and recommendations (only if not loaded)
    if (_allPlaces.isEmpty) {
      final String dest = _itineraryData['destination'] ?? '';
      final places = await DatabaseService().fetchPlacesByDestination(dest);
      _allPlaces = places;
    }

    // Restore custom section names, colors, and icons from Database
    final savedSections = _itineraryData['ItinerarySection'] as List<dynamic>?;
    _sectionNames.clear();
    if (savedSections != null && savedSections.isNotEmpty) {
      // Sort by sortOrder
      savedSections.sort(
        (a, b) => (a['sortOrder'] as int? ?? 0).compareTo(
          b['sortOrder'] as int? ?? 0,
        ),
      );
      for (var sec in savedSections) {
        final name = sec['name'] as String;
        if (!_sectionNames.contains(name)) {
          _sectionNames.add(name);
          _searchControllers.putIfAbsent(name, () => TextEditingController());
          _searchResults.putIfAbsent(name, () => []);
        }
        _sectionColors[name] = Color(int.parse(sec['colorCode'] as String));
        _sectionIcons[name] = IconData(
          sec['iconCode'] as int,
          fontFamily: 'MaterialIcons',
        );
      }
    }

    // Ensure any section that has saved places is in _sectionNames
    for (var place in _savedPlaces) {
      final section = place['section'] as String?;
      if (section != null && !_sectionNames.contains(section)) {
        _sectionNames.add(section);
        _searchControllers.putIfAbsent(section, () => TextEditingController());
        _searchResults.putIfAbsent(section, () => []);
        _sectionColors.putIfAbsent(
          section,
          () =>
              _availableColors[_sectionNames.length % _availableColors.length],
        );
        _sectionIcons.putIfAbsent(section, () => Icons.folder_rounded);
      }
    }

    // Restore custom expenses
    final prefs = await SharedPreferences.getInstance();
    final savedExpenses = prefs.getString('expenses_${itineraryId}');
    if (savedExpenses != null) {
      try {
        _customExpenses = List<Map<String, dynamic>>.from(
          json.decode(savedExpenses),
        );
      } catch (e) {
        debugPrint('Error loading expenses: $e');
      }
    }

    if (mounted) {
      setState(() {
        if (!silent) {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _syncSectionsToDatabase() async {
    final itineraryId = _itineraryData['id'] as int;
    for (int i = 0; i < _sectionNames.length; i++) {
      final name = _sectionNames[i];
      final color = _sectionColors[name]?.value ?? AppTheme.primary.value;
      final icon =
          _sectionIcons[name]?.codePoint ?? Icons.looks_one_rounded.codePoint;
      await DatabaseService().upsertItinerarySection(
        itineraryId: itineraryId,
        name: name,
        colorCode: color.toString(),
        iconCode: icon,
        sortOrder: i,
      );
    }
  }

  Future<void> _saveExpensesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final itineraryId = _itineraryData['id'] as int;
    await prefs.setString(
      'expenses_${itineraryId}',
      json.encode(_customExpenses),
    );
  }

  // Add place to a section/day
  Future<void> _addPlace(
    Map<String, dynamic> place,
    String sectionOrDay,
  ) async {
    final itineraryId = _itineraryData['id'] as int;
    final placeId = place['id'] as int;
    dynamic result;

    if (sectionOrDay.startsWith('Ngày')) {
      final int day =
          int.tryParse(sectionOrDay.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      result = await DatabaseService().addPlaceToItinerary(
        itineraryId: itineraryId,
        placeId: placeId,
        day: day,
      );
    } else {
      result = await DatabaseService().addPlaceToSaved(
        itineraryId: itineraryId,
        placeId: placeId,
        section: sectionOrDay,
      );
    }

    if (result != null) {
      _showPremiumNotification(
        title: 'Thêm thành công',
        message: 'Đã thêm "${place['name']}" vào $sectionOrDay!',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.green,
      );
      await _loadData(silent: true);
    } else {
      await _loadData();
    }
  }

  // Delete place
  Future<void> _removePlaceDetail(
    int detailId,
    String placeName, {
    bool isSavedPlace = false,
  }) async {
    final success = isSavedPlace
        ? await DatabaseService().deletePlaceFromSaved(detailId)
        : await DatabaseService().deletePlaceFromItinerary(detailId);
    if (success) {
      _showPremiumNotification(
        title: 'Đã xóa',
        message: 'Đã xóa "$placeName" khỏi lịch trình.',
        icon: Icons.delete_sweep_outlined,
        color: Colors.redAccent,
      );
      await _loadData(silent: true);
    } else {
      await _loadData();
    }
  }

  // Local place search within destination
  void _onSearchChanged(String query, String sectionName) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults[sectionName] = [];
      });
      return;
    }

    final filtered = _allPlaces.where((place) {
      final name = (place['name'] as String).toLowerCase();
      final addr = (place['address'] as String).toLowerCase();
      final q = query.toLowerCase();
      return name.contains(q) || addr.contains(q);
    }).toList();

    setState(() {
      _searchResults[sectionName] = filtered;
    });
  }

  // Dialog to prompt user where to add a place
  void _showAddPlaceDialog(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Thêm "${place['name']}" vào chuyến đi',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DANH SÁCH TỔNG QUAN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              ..._sectionNames.map((sec) {
                return ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text(sec),
                  onTap: () {
                    Navigator.pop(context);
                    _addPlace(place, sec);
                  },
                );
              }),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'HÀNH TRÌNH THEO NGÀY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: (_itineraryData['days'] as num?)?.toInt() ?? 1,
                  itemBuilder: (context, idx) {
                    final dayLabel = 'Ngày ${idx + 1}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPeach,
                          foregroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _addPlace(place, dayLabel);
                        },
                        child: Text(
                          dayLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Create new section
  void _deleteSelectedItems() async {
    if (_selectedItemIds.isEmpty) return;

    final idsToDelete = _selectedItemIds.toList();
    final success = await DatabaseService().deleteMultipleSavedPlaces(
      idsToDelete,
    );
    if (success) {
      setState(() {
        _isSelectionMode = false;
        _selectedItemIds.clear();
        _selectedSections.clear();
      });
      _loadData(silent: true);
    }
  }

  void _showSelectSectionBottomSheet({required bool isCopy}) {
    if (_selectedItemIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCopy ? 'Sao chép đến...' : 'Di chuyển đến...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ..._sectionNames.map((section) {
                return ListTile(
                  leading: Icon(
                    _sectionIcons[section] ?? Icons.looks_one_rounded,
                    color: _sectionColors[section] ?? AppTheme.primary,
                  ),
                  title: Text(section),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ids = _selectedItemIds.toList();
                    bool success = false;
                    if (isCopy) {
                      success = await DatabaseService().copySavedPlaces(
                        ids,
                        section,
                      );
                    } else {
                      success = await DatabaseService().moveSavedPlaces(
                        ids,
                        section,
                      );
                    }
                    if (success) {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedItemIds.clear();
                        _selectedSections.clear();
                      });
                      _loadData(silent: true);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _createNewSection() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Tạo danh sách mới',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: AppTheme.inputDecoration(
              hintText: 'Nhập tên tiêu đề (vd: Ăn uống, Khách sạn)',
              prefixIcon: Icons.edit_rounded,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final exists = _sectionNames.any(
                    (sec) => sec.toLowerCase() == name.toLowerCase(),
                  );
                  if (exists) {
                    _showPremiumNotification(
                      title: 'Cảnh báo',
                      message: 'Tiêu đề này đã tồn tại. Vui lòng đặt tên khác!',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    );
                    return;
                  }
                  setState(() {
                    _sectionNames.add(name);
                    _searchControllers[name] = TextEditingController();
                    _searchResults[name] = [];

                    final usedColors = _sectionColors.values.toSet();
                    Color? newColor;
                    for (var c in _availableColors) {
                      if (!usedColors.contains(c)) {
                        newColor = c;
                        break;
                      }
                    }
                    if (newColor == null) {
                      final idx =
                          _sectionNames.length % _availableColors.length;
                      newColor = _availableColors[idx];
                    }
                    _sectionColors[name] = newColor;
                    _sectionIcons[name] = Icons.looks_one_rounded;
                  });
                  _syncSectionsToDatabase();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Tạo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Custom Expense Adder Dialog
  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Thêm chi tiêu mới',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: AppTheme.inputDecoration(
                  hintText: 'Tên khoản chi (vd: Vé máy bay)',
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration(
                  hintText: 'Số tiền (VNĐ)',
                  prefixIcon: Icons.attach_money_rounded,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final title = titleController.text.trim();
                final amt = int.tryParse(amountController.text.trim()) ?? 0;
                if (title.isNotEmpty && amt > 0) {
                  setState(() {
                    _customExpenses.add({
                      'title': title,
                      'amount': amt,
                      'date': DateTime.now().toIso8601String().substring(0, 10),
                    });
                  });
                  _saveExpensesToPrefs();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Thêm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // AI Itinerary Planner Generator simulating API
  void _runAIPlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripAIChatScreen(
          destination: _itineraryData['destination'] ?? 'Điểm đến',
        ),
      ),
    );
  }

  void _showMapOverview() {
    setState(() {
      _isMapExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _itineraryData['destination'] ?? 'Điểm đến';
    final PreferredSizeWidget appBarBottom = PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.subtitleText,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Hành trình'),
            Tab(text: 'Khám phá'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.attach_money_rounded, size: 16)],
              ),
            ),
          ],
        ),
      ),
    );

    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight =
        topPadding + 56.0 + 48.0; // 56 for AppBar + 48 for TabBar
    final screenHeight = MediaQuery.of(context).size.height;
    final double targetSheetHeight = !_isMapExpanded
        ? (screenHeight - headerHeight)
        : 75.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 1. Background Map
          Positioned.fill(
            child: _mapCenter != null
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: _mapCenter!,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-bright-smooth/{z}/{x}/{y}.png?apiKey={api_key}',
                        additionalOptions: {
                          'api_key': dotenv.env['GEOAPIFY_API_KEY'] ?? '',
                        },
                      ),
                      MarkerLayer(
                        markers: _savedPlaces.map((savedPlace) {
                          final p = savedPlace['Place'] as Map<String, dynamic>?;
                          if (p == null || p['latitude'] == null || p['longitude'] == null) {
                            return null;
                          }
                          final lat = (p['latitude'] as num).toDouble();
                          final lon = (p['longitude'] as num).toDouble();
                          final sectionName = savedPlace['section'] as String?;
                          
                          final color = _sectionColors[sectionName] ?? AppTheme.primary;
                          final icon = _sectionIcons[sectionName] ?? Icons.location_on;
                          
                          return Marker(
                            point: LatLng(lat, lon),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: Colors.white, size: 20),
                            ),
                          );
                        }).whereType<Marker>().toList(),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
          ),

          // 2. Map Action Buttons (Hidden when full screen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topPadding + 80,
            right: !_isMapExpanded ? -60 : 16,
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppTheme.darkText,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppTheme.darkText,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: AppTheme.darkText,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.layers_outlined,
                      color: AppTheme.darkText,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          // 3. Dynamic Custom Header
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            color: !_isMapExpanded ? Colors.white : Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Bar
                  SizedBox(
                    height: 56,
                    child: _isSelectionMode
                        ? Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(left: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF44336),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_selectedItemIds.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.black87,
                                ),
                                onPressed: _deleteSelectedItems,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.black87,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedItemIds.clear();
                                    _selectedSections.clear();
                                  });
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.only(left: 16),
                                decoration: BoxDecoration(
                                  color: !_isMapExpanded
                                      ? Colors.transparent
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: !_isMapExpanded
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: AppTheme.darkText,
                                  ),
                                  onPressed: () {
                                    if (_isMapExpanded) {
                                      setState(() => _isMapExpanded = false);
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ),
                              const Spacer(),
                              if (!_isMapExpanded)
                                Text(
                                  'Chuyến đi đến $destination',
                                  style: const TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const Spacer(),
                              if (!_isMapExpanded) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    color: AppTheme.subtitleText,
                                  ),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: AppTheme.subtitleText,
                                  ),
                                  onPressed: () {},
                                ),
                              ] else
                                const SizedBox(
                                  width: 48,
                                ), // Balance for back button when expanded
                            ],
                          ),
                  ),

                  // Tab Bar (Only visible when full screen)
                  if (!_isMapExpanded) appBarBottom,
                ],
              ),
            ),
          ),

          // 4. Main Content Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: _dragHeight ?? targetSheetHeight,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: !_isMapExpanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  if (_isMapExpanded || _isDragging)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: !_isMapExpanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                child: Column(
                  children: [
                    // Drag handle
                    GestureDetector(
                      onVerticalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                          _dragHeight = targetSheetHeight;
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _dragHeight =
                              (_dragHeight ?? targetSheetHeight) -
                              details.primaryDelta!;
                          // Clamp the height
                          final max = screenHeight - headerHeight;
                          final min = 75.0; // Allow dragging down to bottom
                          if (_dragHeight! > max) _dragHeight = max;
                          if (_dragHeight! < min) _dragHeight = min;
                        });
                      },
                      onVerticalDragEnd: (details) {
                        final max = screenHeight - headerHeight;
                        final min = 75.0;
                        final mid = (max + min) / 2;

                        setState(() {
                          _isDragging = false;
                          if (details.primaryVelocity != null &&
                              details.primaryVelocity!.abs() > 300) {
                            _isMapExpanded = details.primaryVelocity! > 0;
                          } else {
                            _isMapExpanded =
                                (_dragHeight ?? targetSheetHeight) < mid;
                          }
                          _dragHeight = null;
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom: _isMapExpanded ? 4 : 0,
                        ),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Show TabBar inside the sheet when expanded so we can still switch tabs
                    if (_isMapExpanded)
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: AppTheme.subtitleText,
                          indicatorColor: AppTheme.primary,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          tabs: const [
                            Tab(text: 'Tổng quan'),
                            Tab(text: 'Hành trình'),
                            Tab(text: 'Khám phá'),
                            Tab(
                              icon: Icon(Icons.attach_money_rounded, size: 16),
                            ),
                          ],
                        ),
                      ),

                    // The Tab Views
                    Expanded(
                      child: Stack(
                        children: [
                          _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxHeight < 100) {
                                      return const SizedBox.shrink();
                                    }
                                    return TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildOverviewTab(),
                                        _buildItineraryTab(),
                                        _buildExploreTab(),
                                        _buildExpensesTab(),
                                      ],
                                    );
                                  },
                                ),

                          // FABs
                          if (!_isMapExpanded)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primary,
                                          Color(0xFF7C3AED),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: FloatingActionButton(
                                      heroTag: 'ai_btn',
                                      onPressed: _runAIPlanner,
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      mini: true,
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton(
                                    heroTag: 'map_btn',
                                    onPressed: _showMapOverview,
                                    backgroundColor: AppTheme.darkText,
                                    mini: true,
                                    child: const Icon(
                                      Icons.map_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton(
                                    heroTag: 'add_btn',
                                    onPressed: () {
                                      if (_tabController.index == 3) {
                                        _showAddExpenseDialog();
                                      } else if (_tabController.index == 2) {
                                        _showPremiumNotification(
                                          title: 'Hướng dẫn',
                                          message:
                                              'Vui lòng chọn địa điểm bên dưới để thêm!',
                                          icon: Icons.info_outline_rounded,
                                          color: AppTheme.primary,
                                        );
                                      } else {
                                        _createNewSection();
                                      }
                                    },
                                    backgroundColor: AppTheme.primary,
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNoteInline(String section) async {
    final itineraryId = _itineraryData['id'] as int;
    final sectionDetails = _savedPlaces
        .where((d) => d['section'] == section)
        .toList();
    int maxOrder = 0;
    for (var d in sectionDetails) {
      final ord = d['sortOrder'] ?? 0;
      if (ord > maxOrder) maxOrder = ord;
    }

    final result = await DatabaseService().addPlaceToSaved(
      itineraryId: itineraryId,
      section: section,
      noteText: 'Thêm ghi chú tại đây',
      sortOrder: maxOrder + 1,
    );

    if (result != null) {
      setState(() {
        _editingNoteId = result['id'] as int?;
      });
      await _loadData(silent: true);
    }
  }

  Future<void> _addChecklistInline(String section) async {
    final itineraryId = _itineraryData['id'] as int;
    final sectionDetails = _savedPlaces
        .where((d) => d['section'] == section)
        .toList();
    int maxOrder = 0;
    for (var d in sectionDetails) {
      final ord = d['sortOrder'] ?? d['sortorder'] ?? 0;
      if (ord > maxOrder) maxOrder = ord;
    }

    final result = await DatabaseService().addPlaceToSaved(
      itineraryId: itineraryId,
      section: section,
      noteText: '[TODO] Danh sách công việc',
      sortOrder: maxOrder + 1,
    );

    if (result != null) {
      setState(() {
        _editingNoteId = result['id'] as int?;
      });
      await _loadData(silent: true);
    }
  }

  void _showTemplateBottomSheet(int checklistId, List<dynamic> currentItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ChecklistTemplateSheet(
          checklistId: checklistId,
          currentItems: currentItems,
          onAddItems: (newItems) async {
            final List<Map<String, dynamic>> updated =
                List<Map<String, dynamic>>.from(
                  currentItems
                      .map((it) => Map<String, dynamic>.from(it as Map))
                      .toList(),
                );
            for (var itemText in newItems) {
              if (!updated.any((it) => it['text'] == itemText)) {
                updated.add({'text': itemText, 'done': false});
              }
            }
            final success = await DatabaseService().updateSavedItemTodoItems(
              checklistId,
              updated,
            );
            if (success && mounted) {
              _loadData(silent: true);
            }
          },
        );
      },
    );
  }

  Widget _buildSavedNoteCard(
    Map<String, dynamic> detail,
    int index,
    int listIdx,
    List<Map<String, dynamic>> sectionDetails,
  ) {
    final String text = detail['noteText'] ?? detail['notetext'] ?? '';
    final bool isCollapsed =
        detail['isCollapsed'] == true || detail['iscollapsed'] == true;
    final int id = detail['id'] as int;
    final bool isEditing = id == _editingNoteId;

    final bool isTodo = text.startsWith('[TODO]');
    final String displayTitle = isTodo
        ? text.replaceFirst('[TODO]', '').trim()
        : text;

    TextEditingController? editController;
    if (isEditing) {
      editController = TextEditingController(
        text: isTodo
            ? displayTitle
            : (text == 'Thêm ghi chú tại đây' ? '' : text),
      );
      editController.selection = TextSelection.fromPosition(
        TextPosition(offset: editController.text.length),
      );
    }

    List<dynamic> reactions = [];
    if (detail['reactions'] != null) {
      if (detail['reactions'] is List) {
        reactions = detail['reactions'] as List;
      } else if (detail['reactions'] is String) {
        try {
          reactions = json.decode(detail['reactions']) as List;
        } catch (_) {}
      }
    }

    List<dynamic> todoList = [];
    final rawTodo = detail['todoItems'] ?? detail['todoitems'];
    if (rawTodo != null) {
      if (rawTodo is List) {
        todoList = rawTodo;
      } else if (rawTodo is String) {
        try {
          todoList = json.decode(rawTodo) as List;
        } catch (_) {}
      }
    }

    final bool allDone =
        todoList.isNotEmpty && todoList.every((item) => item['done'] == true);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedItemIds.contains(id)) {
              _selectedItemIds.remove(id);
            } else {
              _selectedItemIds.add(id);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: icon + title + collapse/check toggle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTodo
                        ? Icons.fact_check_outlined
                        : Icons.description_outlined,
                    color: AppTheme.subtitleText,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: isEditing
                        ? TextField(
                            controller: editController,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: isTodo
                                  ? 'Tên danh sách...'
                                  : 'Nhập ghi chú...',
                              hintStyle: const TextStyle(
                                color: Colors.black26,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (val) async {
                              final cleanVal = val.trim();
                              String finalVal = cleanVal.isEmpty
                                  ? (isTodo
                                        ? 'Danh sách công việc'
                                        : 'Ghi chú mới')
                                  : cleanVal;
                              if (isTodo) finalVal = '[TODO] $finalVal';
                              await DatabaseService().updateSavedItemText(
                                id,
                                finalVal,
                              );
                              setState(() => _editingNoteId = null);
                              await _loadData(silent: true);
                            },
                          )
                        : GestureDetector(
                            onTap: () => setState(() => _editingNoteId = id),
                            child: Text(
                              isTodo
                                  ? (displayTitle.isEmpty
                                        ? 'Danh sách công việc'
                                        : displayTitle)
                                  : (text.isEmpty
                                        ? 'Thêm ghi chú tại đây'
                                        : text),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right-side button: save / all-done / collapse-toggle
                if (isEditing)
                  GestureDetector(
                    onTap: () async {
                      final cleanVal = editController?.text.trim() ?? '';
                      String finalVal = cleanVal.isEmpty
                          ? (isTodo ? 'Danh sách công việc' : 'Ghi chú mới')
                          : cleanVal;
                      if (isTodo) finalVal = '[TODO] $finalVal';
                      await DatabaseService().updateSavedItemText(id, finalVal);
                      setState(() => _editingNoteId = null);
                      await _loadData(silent: true);
                    },
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.green,
                      size: 22,
                    ),
                  )
                else if (isTodo)
                  GestureDetector(
                    onTap: () {
                      final newDone = !allDone;
                      final updated = todoList
                          .map((item) => {...item as Map, 'done': newDone})
                          .toList();
                      DatabaseService()
                          .updateSavedItemTodoItems(id, updated)
                          .then((_) => _loadData(silent: true));
                    },
                    child: Icon(
                      allDone ? Icons.check_box : Icons.check_box_outline_blank,
                      color: allDone ? AppTheme.primary : AppTheme.subtitleText,
                      size: 20,
                    ),
                  )
                else if (isCollapsed)
                  GestureDetector(
                    onTap: () => DatabaseService()
                        .updateSavedItemCollapse(id, false)
                        .then((_) => _loadData(silent: true)),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.subtitleText,
                      size: 20,
                    ),
                  ),
                if (_isSelectionMode)
                  IgnorePointer(
                    child: Checkbox(
                      value: _selectedItemIds.contains(id),
                      onChanged: (_) {},
                      activeColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Todo items list (when not collapsed)
            if (isTodo && todoList.isNotEmpty && !isCollapsed) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  children: todoList.map((item) {
                    final String itemText = item['text'] ?? '';
                    final bool done = item['done'] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final updated = todoList.map((it) {
                                if (it['text'] == itemText) {
                                  return {...it as Map, 'done': !done};
                                }
                                return it;
                              }).toList();
                              DatabaseService()
                                  .updateSavedItemTodoItems(id, updated)
                                  .then((_) => _loadData(silent: true));
                            },
                            child: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done
                                  ? AppTheme.primary
                                  : AppTheme.subtitleText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itemText,
                              style: TextStyle(
                                fontSize: 13,
                                color: done
                                    ? AppTheme.subtitleText
                                    : AppTheme.darkText,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final updated = List.from(todoList)
                                ..removeWhere((it) => it['text'] == itemText);
                              DatabaseService()
                                  .updateSavedItemTodoItems(id, updated)
                                  .then((_) => _loadData(silent: true));
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ── Add todo item input (when not collapsed)
            if (isTodo && !isCollapsed) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      color: AppTheme.subtitleText,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Thêm một số mục',
                          hintStyle: TextStyle(
                            color: AppTheme.subtitleText,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onSubmitted: (val) {
                          final cleanVal = val.trim();
                          if (cleanVal.isNotEmpty &&
                              !todoList.any((it) => it['text'] == cleanVal)) {
                            final updated = List.from(todoList)
                              ..add({'text': cleanVal, 'done': false});
                            DatabaseService()
                                .updateSavedItemTodoItems(id, updated)
                                .then((_) => _loadData(silent: true));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Collapsed emoji display for notes
            if (!isTodo && isCollapsed && reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: reactions.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      final updated = List.from(reactions)..remove(emoji);
                      DatabaseService()
                          .updateSavedItemReactions(id, updated)
                          .then((_) => _loadData(silent: true));
                    },
                    child: _emojiChip(emoji as String),
                  );
                }).toList(),
              ),
            ],

            // ── Toolbar (shown when expanded OR always for todo)
            if (!isCollapsed || isTodo) ...[
              const SizedBox(height: 8),
              const Divider(color: AppTheme.border, height: 1, thickness: 0.5),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: isTodo
                        // Todo left side: "Danh sách làm sẵn" button
                        ? GestureDetector(
                            onTap: () => _showTemplateBottomSheet(id, todoList),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.card_travel_outlined,
                                  color: AppTheme.subtitleText,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Danh sách làm sẵn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.darkText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        // Note left side: emoji chips + picker button
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...reactions.map((emoji) {
                                return GestureDetector(
                                  onTap: () {
                                    final updated = List.from(reactions)
                                      ..remove(emoji);
                                    DatabaseService()
                                        .updateSavedItemReactions(id, updated)
                                        .then((_) => _loadData(silent: true));
                                  },
                                  child: _emojiChip(emoji as String),
                                );
                              }),
                              // Emoji picker button
                              GestureDetector(
                                onTap: () =>
                                    _showEmojiPickerSheet(id, reactions),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: const Icon(
                                    Icons.sentiment_satisfied_alt_outlined,
                                    color: AppTheme.subtitleText,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Right: delete, drag, collapse
                  GestureDetector(
                    onTap: () =>
                        _removePlaceDetail(id, text, isSavedPlace: true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.subtitleText,
                        size: 18,
                      ),
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: listIdx,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppTheme.subtitleText,
                        size: 18,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => DatabaseService()
                        .updateSavedItemCollapse(id, !isCollapsed)
                        .then((_) => _loadData(silent: true)),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 2),
                      child: Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: AppTheme.subtitleText,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emojiChip(String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 3),
          const Text(
            '1',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPickerSheet(int noteId, List<dynamic> currentReactions) {
    // Full emoji list organized by categories
    const Map<String, List<String>> emojiCategories = {
      'Mặt cười & cảm xúc': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '🤣',
        '😂',
        '🙂',
        '😊',
        '😇',
        '🥰',
        '😍',
        '🤩',
        '😘',
        '😗',
        '😚',
        '😙',
        '🥲',
        '😋',
        '😛',
        '😜',
        '🤪',
        '😝',
        '🤑',
        '🤗',
        '🤭',
        '🫢',
        '🫣',
        '🤫',
        '🤔',
        '🫡',
        '🤐',
        '🤨',
        '😐',
        '😑',
        '😶',
        '😏',
        '😒',
        '🙄',
        '😬',
        '🤥',
        '😌',
        '😔',
        '😪',
        '🤤',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🤢',
        '🤮',
        '🤧',
        '🥵',
        '🥶',
        '🥴',
        '😵',
        '🤯',
        '🤠',
        '🥸',
        '😎',
        '🤓',
        '🧐',
        '😕',
        '😟',
        '🙁',
        '☹️',
        '😮',
        '😯',
        '😲',
        '😳',
        '🥺',
        '😦',
        '😧',
        '😨',
        '😰',
        '😥',
        '😢',
        '😭',
        '😱',
        '😖',
        '😣',
        '😞',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈',
        '👿',
        '💀',
        '☠️',
        '💩',
        '🤡',
        '👹',
        '👺',
        '👻',
        '👽',
        '👾',
        '🤖',
      ],
      'Con người & cơ thể': [
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '🫱',
        '🫲',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🫰',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝️',
        '🫵',
        '👍',
        '👎',
        '✊',
        '👊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '🫶',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👂',
        '🦻',
        '👃',
        '🫀',
        '🫁',
        '🧠',
        '🦷',
        '🦴',
        '👀',
        '👁️',
        '👅',
        '👄',
        '🫦',
      ],
      'Du lịch & địa điểm': [
        '✈️',
        '🚀',
        '🛸',
        '🚁',
        '🛺',
        '🚂',
        '🚆',
        '🚇',
        '🚊',
        '🚝',
        '🚞',
        '🚋',
        '🚌',
        '🚍',
        '🚎',
        '🏎️',
        '🚑',
        '🚒',
        '🚓',
        '🚐',
        '🛻',
        '🚚',
        '🚛',
        '🚜',
        '🏍️',
        '🛵',
        '🛺',
        '🚲',
        '🛴',
        '🛹',
        '🛼',
        '🛷',
        '🚏',
        '🛣️',
        '🛤️',
        '🌍',
        '🌎',
        '🌏',
        '🗺️',
        '🧭',
        '🏔️',
        '⛰️',
        '🌋',
        '🗻',
        '🏕️',
        '🏖️',
        '🏜️',
        '🏝️',
        '🏞️',
        '🏟️',
        '🏛️',
        '🏗️',
        '🏘️',
        '🏠',
        '🏡',
        '🏢',
        '🏣',
        '🏤',
        '🏥',
        '🏦',
        '🏨',
        '🏩',
        '🏪',
        '🏫',
        '🏬',
        '🏭',
        '🏯',
        '🏰',
        '🗼',
        '🗽',
        '🗾',
        '🎌',
        '🏳️',
        '🏴',
        '🚩',
      ],
      'Ăn uống': [
        '🍏',
        '🍎',
        '🍊',
        '🍋',
        '🍌',
        '🍍',
        '🥭',
        '🍇',
        '🍓',
        '🫐',
        '🍈',
        '🍒',
        '🍑',
        '🥝',
        '🍅',
        '🫒',
        '🥥',
        '🥑',
        '🍆',
        '🥔',
        '🥕',
        '🌽',
        '🌶️',
        '🫑',
        '🥒',
        '🥬',
        '🥦',
        '🧄',
        '🧅',
        '🥜',
        '🫘',
        '🍞',
        '🥐',
        '🥖',
        '🫓',
        '🥨',
        '🥯',
        '🧀',
        '🥚',
        '🍳',
        '🧈',
        '🥞',
        '🧇',
        '🥓',
        '🥩',
        '🍗',
        '🍖',
        '🦴',
        '🌭',
        '🍔',
        '🍟',
        '🍕',
        '🫓',
        '🌮',
        '🌯',
        '🫔',
        '🥙',
        '🧆',
        '🥚',
        '🍱',
        '🍘',
        '🍙',
        '🍚',
        '🍛',
        '🍜',
        '🍝',
        '🍠',
        '🍢',
        '🍣',
        '🍤',
        '🍥',
        '🥮',
        '🍡',
        '🥟',
        '🥠',
        '🥡',
        '🦀',
        '🦞',
        '🦐',
        '🦑',
        '🦪',
        '🍦',
        '🍧',
        '🍨',
        '🍩',
        '🍪',
        '🎂',
        '🍰',
        '🧁',
        '🥧',
        '🍫',
        '🍬',
        '🍭',
        '🍮',
        '🍯',
        '☕',
        '🍵',
        '🧃',
        '🥤',
        '🧋',
        '🍶',
        '🍾',
        '🍷',
        '🍸',
        '🍹',
        '🍺',
        '🍻',
        '🥂',
        '🥃',
        '🫗',
      ],
      'Hoạt động': [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🥎',
        '🎾',
        '🏐',
        '🏉',
        '🥏',
        '🎱',
        '🪀',
        '🏓',
        '🏸',
        '🏒',
        '🥍',
        '🏏',
        '🪃',
        '🥅',
        '⛳',
        '🪁',
        '🤿',
        '🎣',
        '🤸',
        '🤼',
        '🤺',
        '🤾',
        '⛷️',
        '🏂',
        '🏋️',
        '🚵',
        '🚴',
        '🏊',
        '🤽',
        '🧗',
        '🏇',
        '🏆',
        '🥇',
        '🥈',
        '🥉',
        '🎖️',
        '🎗️',
        '🏅',
        '🎫',
        '🎟️',
        '🎪',
        '🎭',
        '🎨',
        '🖼️',
        '🎰',
        '🎲',
        '🧩',
        '🎮',
        '🕹️',
        '🎯',
        '🎳',
      ],
      'Ký hiệu & khác': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❤️‍🔥',
        '❤️‍🩹',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '☮️',
        '✝️',
        '☪️',
        '🕉️',
        '✡️',
        '🔯',
        '🕎',
        '☯️',
        '☦️',
        '🛐',
        '⛎',
        '♈',
        '♉',
        '♊',
        '♋',
        '♌',
        '♍',
        '♎',
        '♏',
        '♐',
        '♑',
        '♒',
        '♓',
        '🆔',
        '⚛️',
        '🉑',
        '☢️',
        '☣️',
        '📵',
        '🚫',
        '⛔',
        '🔞',
        '📛',
        '🔰',
        '⭕',
        '✅',
        '☑️',
        '✔️',
        '❎',
        '🔱',
        '🔲',
        '🔳',
        '⬛',
        '⬜',
        '◼️',
        '◻️',
        '◾',
        '◽',
        '▪️',
        '▫️',
        '🔺',
        '🔻',
        '💠',
        '🔘',
        '🔵',
        '🟣',
        '⚫',
        '🟤',
        '🔴',
        '🟠',
        '🟡',
        '🟢',
        '🔶',
        '🔷',
        '🔸',
        '🔹',
        '🔊',
        '🔔',
        '🔕',
        '🎵',
        '🎶',
        '💡',
        '🔦',
        '🕯️',
        '💰',
        '💵',
        '💴',
        '💶',
        '💷',
        '💸',
        '💳',
        '🪙',
        '💹',
        '✉️',
        '📧',
        '📨',
        '📩',
        '📤',
        '📥',
        '📦',
        '📫',
        '📪',
        '📬',
        '📭',
        '📮',
        '🗳️',
        '✏️',
        '✒️',
        '🖊️',
        '🖋️',
        '📝',
        '📁',
        '📂',
        '🗂️',
        '📅',
        '📆',
        '🗒️',
        '🗓️',
        '📇',
        '📈',
        '📉',
        '📊',
        '📋',
        '📌',
        '📍',
        '🗺️',
        '📎',
        '🖇️',
        '✂️',
        '🗃️',
        '🗄️',
        '🗑️',
        '🔒',
        '🔓',
        '🔏',
        '🔐',
        '🔑',
        '🗝️',
        '🔨',
        '🪓',
        '⛏️',
        '⚒️',
        '🛠️',
        '🗡️',
        '⚔️',
        '🛡️',
        '🪃',
        '🔧',
        '🪛',
        '🔩',
        '⚙️',
        '🗜️',
        '⚖️',
        '🪝',
        '🔗',
        '⛓️',
        '🪤',
        '🧲',
        '🔋',
        '🪫',
        '🔌',
        '💻',
        '🖥️',
        '🖨️',
        '⌨️',
        '🖱️',
        '🖲️',
        '💾',
        '💿',
        '📀',
        '🧮',
        '🎥',
        '🎞️',
        '📽️',
        '🎬',
        '📺',
        '📷',
        '📸',
        '📹',
        '📼',
        '🔍',
        '🔎',
        '🕯️',
        '💡',
        '🔦',
        '🏮',
        '🪔',
        '📡',
        '🔭',
        '🔬',
        '🩺',
        '🩻',
        '🩹',
        '💊',
        '🩸',
        '🧬',
        '🦠',
        '🧫',
        '🧪',
        '⚗️',
        '🛁',
        '🚿',
        '🪥',
        '🧴',
        '🧷',
        '🧹',
        '🧺',
        '🧻',
        '🪣',
        '🧼',
        '🫧',
        '🪒',
        '🧽',
        '🪜',
        '🛒',
        '🚪',
        '🪞',
        '🪟',
        '🛏️',
        '🛋️',
        '🚽',
        '🪠',
        '🚰',
      ],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String? selectedCategory = emojiCategories.keys.first;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: StatefulBuilder(
                builder: (ctx, setInner) {
                  selectedCategory ??= emojiCategories.keys.first;
                  final emojis = emojiCategories[selectedCategory]!;
                  return Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 22,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      // Category tabs
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: emojiCategories.keys.map((cat) {
                            final icons = const {
                              'Mặt cười & cảm xúc':
                                  Icons.sentiment_satisfied_alt,
                              'Con người & cơ thể': Icons.accessibility_new,
                              'Du lịch & địa điểm': Icons.flight,
                              'Ăn uống': Icons.restaurant,
                              'Hoạt động': Icons.sports_soccer,
                              'Ký hiệu & khác': Icons.flag,
                            };
                            final bool active = selectedCategory == cat;
                            return GestureDetector(
                              onTap: () =>
                                  setInner(() => selectedCategory = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  icons[cat] ?? Icons.emoji_emotions,
                                  size: 22,
                                  color: active ? Colors.white : Colors.black54,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1),
                      // Category label
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedCategory!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      // Emoji grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                                childAspectRatio: 1,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                          itemCount: emojis.length,
                          itemBuilder: (_, i) {
                            final emoji = emojis[i];
                            final alreadySelected = currentReactions.contains(
                              emoji,
                            );
                            return GestureDetector(
                              onTap: () {
                                List<dynamic> updated;
                                if (alreadySelected) {
                                  updated = List.from(currentReactions)
                                    ..remove(emoji);
                                } else {
                                  updated = List.from(currentReactions)
                                    ..add(emoji);
                                }
                                DatabaseService()
                                    .updateSavedItemReactions(noteId, updated)
                                    .then((_) {
                                      _loadData(silent: true);
                                      Navigator.pop(ctx);
                                    });
                              },
                              child: Container(
                                decoration: alreadySelected
                                    ? BoxDecoration(
                                        color: AppTheme.primary.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.primary.withAlpha(80),
                                        ),
                                      )
                                    : null,
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedPlaceCard(Map<String, dynamic> detail, int index) {
    final place = detail['Place'] ?? {};
    final categoryName = place['Category']?['name'] ?? 'Điểm tham quan';
    final String name = place['name'] ?? 'Địa điểm';
    final String image = place['image'] ?? '';

    String? extraInfo;
    if (name.toLowerCase().contains('ueno') ||
        name.toLowerCase().contains('sở thú ueno')) {
      extraInfo = 'Đóng cửa T2';
    } else if (place['openTime'] != null && place['closeTime'] != null) {
      final open = (place['openTime'] as String).substring(0, 5);
      final close = (place['closeTime'] as String).substring(0, 5);
      extraInfo = 'Mở cửa: $open - $close';
    }

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode && detail['id'] != null) {
          setState(() {
            final id = detail['id'] as int;
            if (_selectedItemIds.contains(id)) {
              _selectedItemIds.remove(id);
            } else {
              _selectedItemIds.add(id);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          _sectionColors[detail['section']] ??
                          const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        (_sectionIcons[detail['section']] == null ||
                            _sectionIcons[detail['section']] ==
                                Icons.looks_one_rounded)
                        ? Text(
                            '$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : Icon(
                            _sectionIcons[detail['section']],
                            color: Colors.white,
                            size: 14,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.darkText,
                          ),
                        ),
                        if (extraInfo != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppTheme.subtitleText,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                extraInfo,
                                style: const TextStyle(
                                  color: AppTheme.subtitleText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, size: 80),
                  ),
                ),
                _isSelectionMode
                    ? IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _selectedItemIds.contains(detail['id']),
                            onChanged: (_) {},
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _removePlaceDetail(
                          detail['id'],
                          name,
                          isSavedPlace: true,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: TỔNG QUAN =================
  Widget _buildOverviewTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _sectionNames.length,
            itemBuilder: (context, index) {
              final section = _sectionNames[index];
              final searchController = _searchControllers[section]!;
              final searchResultsList = _searchResults[section] ?? [];

              // Filter details belonging to this section
              final sectionDetails = _savedPlaces
                  .where((d) => d['section'] == section)
                  .toList();

              // Get list of place IDs already saved in this section
              final savedPlaceIds = sectionDetails
                  .map((d) => d['placeId'] as int?)
                  .whereType<int>()
                  .toSet();

              // Filter recommended places: only show if not already saved in this section
              final availableRecommendations = _allPlaces
                  .where((place) => !savedPlaceIds.contains(place['id']))
                  .toList();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: AppTheme.premiumCardDecoration(radius: 16),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    controller: _expansionControllers.putIfAbsent(
                      section,
                      () => ExpansionTileController(),
                    ),
                    initiallyExpanded: index == 0,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    iconColor: AppTheme.darkText,
                    collapsedIconColor: AppTheme.subtitleText,
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: _selectedSections.contains(section),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedSections.add(section);
                                  for (var place in _savedPlaces) {
                                    if (place['section'] == section &&
                                        place['id'] != null) {
                                      _selectedItemIds.add(place['id'] as int);
                                    }
                                  }
                                } else {
                                  _selectedSections.remove(section);
                                  for (var place in _savedPlaces) {
                                    if (place['section'] == section &&
                                        place['id'] != null) {
                                      _selectedItemIds.remove(
                                        place['id'] as int,
                                      );
                                    }
                                  }
                                }
                              });
                            },
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.darkText,
                          ),
                    trailing: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppTheme.subtitleText,
                        ),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        elevation: 4,
                        onSelected: (value) {
                          if (value == 'edit') {
                            setState(() {
                              _editingSection = section;
                              _sectionTitleController.text = section;
                            });
                            _sectionTitleFocusNode.requestFocus();
                          } else if (value == 'color') {
                            _showSectionStyleSheet(context, section);
                          } else if (value == 'reorder') {
                            _showSectionStyleSheet(
                              context,
                              section,
                              initialTabIndex: 1,
                            );
                          } else if (value == 'collapse') {
                            for (var controller
                                in _expansionControllers.values) {
                              if (controller.isExpanded) {
                                controller.collapse();
                              }
                            }
                          } else if (value == 'delete') {
                            setState(() {
                              _sectionNames.remove(section);
                              _sectionColors.remove(section);
                              _sectionIcons.remove(section);
                              _savedPlaces.removeWhere(
                                (place) => place['section'] == section,
                              );
                              _expansionControllers.remove(section);
                            });
                            final itId = _itineraryData['id'] as int;
                            DatabaseService().deleteItinerarySection(
                              itId,
                              section,
                            );
                            DatabaseService().deleteSavedPlacesBySection(
                              itId,
                              section,
                            );
                            _syncSectionsToDatabase();
                          } else if (value == 'select_all') {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedSections.add(section);
                              for (var place in _savedPlaces) {
                                if (place['section'] == section &&
                                    place['id'] != null) {
                                  _selectedItemIds.add(place['id'] as int);
                                }
                              }
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tính năng đang phát triển ($value)',
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Chỉnh sửa tiêu đề',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'color',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.palette_rounded,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Thay đổi màu sắc hoặc biểu tượng',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'select_all',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_box_outlined,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Chọn tất cả',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'collapse',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.close_fullscreen_rounded,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Thu gọn tất cả các phần',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Xóa phần',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'reorder',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.menu_rounded,
                                  size: 20,
                                  color: AppTheme.darkText,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Sắp xếp lại các phần',
                                  style: TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: _editingSection == section
                        ? TextField(
                            controller: _sectionTitleController,
                            focusNode: _sectionTitleFocusNode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: index == 0
                                  ? AppTheme.darkText
                                  : AppTheme.subtitleText,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (newValue) =>
                                _saveSectionTitle(section, newValue),
                            onTapOutside: (_) => _saveSectionTitle(
                              section,
                              _sectionTitleController.text,
                            ),
                          )
                        : Text(
                            section,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: index == 0
                                  ? AppTheme.darkText
                                  : AppTheme.subtitleText,
                            ),
                          ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Saved places list inside this section at the top
                            if (sectionDetails.isNotEmpty) ...[
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sectionDetails.length,
                                buildDefaultDragHandles: false,
                                onReorder: (oldIndex, newIndex) async {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  if (oldIndex == newIndex) return;

                                  // Optimistic local UI update
                                  final items = List<Map<String, dynamic>>.from(
                                    sectionDetails,
                                  );
                                  final movedItem = items.removeAt(oldIndex);
                                  items.insert(newIndex, movedItem);

                                  setState(() {
                                    _savedPlaces = _savedPlaces.map((sp) {
                                      final updatedIdx = items.indexWhere(
                                        (it) => it['id'] == sp['id'],
                                      );
                                      if (updatedIdx != -1) {
                                        return {...sp, 'sortOrder': updatedIdx};
                                      }
                                      return sp;
                                    }).toList();
                                  });

                                  // DB update
                                  for (int i = 0; i < items.length; i++) {
                                    await DatabaseService()
                                        .updateSavedItemOrder(
                                          items[i]['id'] as int,
                                          i,
                                        );
                                  }
                                  await _loadData(silent: true);
                                },
                                itemBuilder: (context, sIdx) {
                                  final detail = sectionDetails[sIdx];
                                  final key = ValueKey(detail['id']);
                                  if (detail['noteText'] != null) {
                                    return Container(
                                      key: key,
                                      child: _buildSavedNoteCard(
                                        detail,
                                        sIdx + 1,
                                        sIdx,
                                        sectionDetails,
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      key: key,
                                      child: _buildSavedPlaceCard(
                                        detail,
                                        sIdx + 1,
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Search field & custom icon buttons
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: searchController,
                                      onChanged: (val) =>
                                          _onSearchChanged(val, section),
                                      decoration: const InputDecoration(
                                        hintText: 'Thêm địa điểm',
                                        hintStyle: TextStyle(
                                          color: AppTheme.hintText,
                                          fontSize: 13,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_on_outlined,
                                          color: AppTheme.subtitleText,
                                          size: 20,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _addNoteInline(section),
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
                                      color: AppTheme.darkText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _addChecklistInline(section),
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.checklist_rounded,
                                      color: AppTheme.darkText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Display Local Search results inline
                            if (searchResultsList.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 150,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: searchResultsList.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, sIdx) {
                                    final p = searchResultsList[sIdx];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.location_on,
                                        color: AppTheme.primary,
                                      ),
                                      title: Text(
                                        p['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        p['address'] ?? '',
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                      ),
                                      onTap: () {
                                        searchController.clear();
                                        setState(() {
                                          _searchResults[section] = [];
                                        });
                                        _addPlace(p, section);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            const Text(
                              'Địa điểm được đề xuất',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Recommendations Horizontal List
                            SizedBox(
                              height: 70,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: availableRecommendations.length + 1,
                                itemBuilder: (context, rIdx) {
                                  if (rIdx == availableRecommendations.length) {
                                    // "Khám phá" card at the end
                                    return GestureDetector(
                                      onTap: () => _tabController.animateTo(2),
                                      child: Container(
                                        width: 120,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.redAccent,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Khám phá',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: AppTheme.darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final place = availableRecommendations[rIdx];
                                  return GestureDetector(
                                    onTap: () => _addPlace(place, section),
                                    child: Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              place['image'] ?? '',
                                              width: 42,
                                              height: 42,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  place['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.primaryPeach,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 12,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Saved places list moved to the top of accordion content
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom New List button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Danh sách mới',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _createNewSection,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: HÀNH TRÌNH =================
  Widget _buildAddPlaceToDayButton(String dayLabel) {
    // Get all places added in the Overview sections (not days)
    final overviewDetails = _savedPlaces;

    if (overviewDetails.isEmpty) {
      return TextButton.icon(
        icon: const Icon(Icons.add, size: 16, color: AppTheme.subtitleText),
        label: const Text(
          'Chưa có địa điểm đã lưu',
          style: TextStyle(color: AppTheme.subtitleText, fontSize: 12),
        ),
        onPressed: () {
          _showPremiumNotification(
            title: 'Lưu ý',
            message: 'Vui lòng thêm địa điểm ở Tab Tổng quan trước!',
            icon: Icons.info_outline_rounded,
            color: AppTheme.primary,
          );
        },
      );
    }

    // Map details to unique places
    final Map<int, Map<String, dynamic>> uniquePlacesMap = {};
    for (var d in overviewDetails) {
      final p = d['Place'];
      if (p != null && p['id'] != null) {
        uniquePlacesMap[p['id'] as int] = Map<String, dynamic>.from(p);
      }
    }
    final List<Map<String, dynamic>> savedPlaces = uniquePlacesMap.values
        .toList();

    return PopupMenuButton<Map<String, dynamic>>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryPeach,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withAlpha(50)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Thêm địa điểm đã lưu',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      tooltip: 'Thêm địa điểm đã lưu từ Tổng quan',
      onSelected: (place) {
        _addPlace(place, dayLabel);
      },
      itemBuilder: (context) {
        return savedPlaces.map((place) {
          return PopupMenuItem<Map<String, dynamic>>(
            value: place,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    place['image'] ?? '',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, size: 32),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        place['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        place['address'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.subtitleText,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildEmptyDayView(String dayLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có hoạt động nào trong $dayLabel',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy chọn "+ Thêm địa điểm đã lưu" ở trên hoặc sang Tab "Tổng quan" để lưu địa điểm bạn thích.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPeach,
                foregroundColor: AppTheme.primary,
                elevation: 0,
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text(
                'Đi khám phá địa điểm mới',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _tabController.animateTo(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayListView(List<Map<String, dynamic>> dayDetails) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayDetails.length,
      itemBuilder: (context, idx) {
        final detail = dayDetails[idx];
        final place = detail['Place'] ?? {};
        final arrival =
            (detail['arrivalTime'] as String?)?.substring(0, 5) ?? '09:00';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline side line indicator
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    arrival,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 90,
                  color: idx == dayDetails.length - 1
                      ? Colors.transparent
                      : AppTheme.border,
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Place card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.premiumCardDecoration(radius: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        place['image'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            place['address'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.subtitleText,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${place['rating'] ?? 0.0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () =>
                          _removePlaceDetail(detail['id'], place['name'] ?? ''),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItineraryTab() {
    final int totalDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;

    return DefaultTabController(
      length: totalDays,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.subtitleText,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: List.generate(
                totalDays,
                (index) => Tab(text: 'Ngày ${index + 1}'),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: List.generate(totalDays, (dayIndex) {
                final dayLabel = 'Ngày ${dayIndex + 1}';
                final dayDetails = _details
                    .where((d) => d['day'] == (dayIndex + 1))
                    .toList();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hoạt động ($dayLabel)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.darkText,
                            ),
                          ),
                          _buildAddPlaceToDayButton(dayLabel),
                        ],
                      ),
                    ),
                    Expanded(
                      child: dayDetails.isEmpty
                          ? _buildEmptyDayView(dayLabel)
                          : _buildDayListView(dayDetails),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: KHÁM PHÁ =================
  Widget _buildExploreTab() {
    if (_allPlaces.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy địa điểm nào tại điểm đến này.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _allPlaces.length,
      itemBuilder: (context, index) {
        final place = _allPlaces[index];
        final price = place['price'] ?? 'N/A';
        final double rating = (place['rating'] as num?)?.toDouble() ?? 0.0;

        return Container(
          decoration: AppTheme.premiumCardDecoration(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          place['image'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place['address'] ?? '',
                      style: const TextStyle(
                        color: AppTheme.subtitleText,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          price == 'Miễn phí' ? 'Miễn phí' : 'Giá rẻ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: price == 'Miễn phí'
                                ? AppTheme.green
                                : AppTheme.primary,
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(40, 24),
                          ),
                          onPressed: () => _showAddPlaceDialog(place),
                          child: const Text(
                            'Thêm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
    );
  }

  // ================= TAB 4: CHI PHÍ ($) =================
  Widget _buildExpensesTab() {
    // Determine target budget
    final budgetLimit = (_itineraryData['budget'] as num?)?.toInt() ?? 3000000;

    // Calculate sum of place costs if they have prices (mocked/parsed)
    int placeCosts = 0;
    for (var detail in _details) {
      final p = detail['Place'] ?? {};
      final priceStr = p['price']?.toString() ?? '';
      if (priceStr.contains('Miễn phí') || priceStr.isEmpty) {
        placeCosts += 0;
      } else {
        placeCosts += 50000; // Mock admission fee if not free
      }
    }

    int customSpent = 0;
    for (var exp in _customExpenses) {
      customSpent += (exp['amount'] as num).toInt();
    }

    final totalSpent = placeCosts + customSpent;
    final progress = totalSpent / budgetLimit;
    final percent = (progress * 100).clamp(0.0, 100.0).toStringAsFixed(0);

    String formatDong(int amount) {
      if (amount >= 1000000) {
        double m = amount / 1000000.0;
        return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)} Tr';
      }
      return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng chi tiêu',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ngân sách: ${formatDong(budgetLimit)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatDong(totalSpent),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: progress > 1.0
                              ? Colors.redAccent
                              : AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress > 1.0
                          ? 'Vượt quá ngân sách!'
                          : 'Đã sử dụng $percent% ngân sách',
                      style: TextStyle(
                        color: progress > 1.0
                            ? Colors.redAccent
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Còn lại: ${formatDong((budgetLimit - totalSpent).clamp(0, 999999999))}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chi tiết chi tiêu',
                style: AppTheme.sectionTitleStyle,
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                label: const Text(
                  'Thêm chi phí',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _showAddExpenseDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Places cost section
          if (placeCosts > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'VÉ THAM QUAN / DỊCH VỤ ĐỊA ĐIỂM',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.subtitleText,
                ),
              ),
            ),
            ..._details
                .where((d) {
                  final p = d['Place'] ?? {};
                  final priceStr = p['price']?.toString() ?? '';
                  return !priceStr.contains('Miễn phí') && priceStr.isNotEmpty;
                })
                .map((d) {
                  final p = d['Place'] ?? {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: AppTheme.premiumCardDecoration(radius: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p['name'] ?? 'Vé tham quan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatDong(50000),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            const SizedBox(height: 16),
          ],

          // Custom Expenses Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'CHI PHÍ TỰ THÊM',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: AppTheme.subtitleText,
              ),
            ),
          ),
          if (_customExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              alignment: Alignment.center,
              child: const Text(
                'Chưa có chi tiêu tự thêm nào. Hãy nhấn "+ Thêm chi phí"!',
                style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
              ),
            )
          else
            ...List.generate(_customExpenses.length, (idx) {
              final item = _customExpenses[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: AppTheme.premiumCardDecoration(radius: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['date'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.subtitleText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatDong(item['amount']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _customExpenses.removeAt(idx);
                        });
                        _saveExpensesToPrefs();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Bottom sheet widget for picking from pre-made checklist templates
class _ChecklistTemplateSheet extends StatefulWidget {
  final int checklistId;
  final List<dynamic> currentItems;
  final void Function(List<String> newItems) onAddItems;

  const _ChecklistTemplateSheet({
    required this.checklistId,
    required this.currentItems,
    required this.onAddItems,
  });

  @override
  State<_ChecklistTemplateSheet> createState() =>
      _ChecklistTemplateSheetState();
}

class _ChecklistTemplateSheetState extends State<_ChecklistTemplateSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _templates = [];
  // Selected category ids
  Set<int> _selectedCategories = {};
  // Expanded category ids
  Set<int> _expandedCategories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final data = await DatabaseService().fetchChecklistTemplates();
    if (mounted) {
      setState(() {
        _templates = data;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getForTab(String tabType) {
    return _templates
        .where((t) => t['tabType'] == tabType || t['tabtype'] == tabType)
        .toList();
  }

  void _addSelected() {
    final List<String> newItems = [];
    for (final cat in _templates) {
      final catId = cat['id'] as int;
      if (_selectedCategories.contains(catId)) {
        final items = cat['items'] as List? ?? [];
        for (final item in items) {
          newItems.add(item['name'] as String);
        }
      }
    }
    widget.onAddItems(newItems);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Thêm từ một mẫu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: _addSelected,
                  child: Text(
                    'Thêm',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Chọn các mục để thêm vào danh sách kiểm tra của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Danh sách đóng gói'),
                Tab(text: 'Nhiệm vụ trước'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryList('packing'),
                      _buildCategoryList('todo'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String tabType) {
    final cats = _getForTab(tabType);
    if (cats.isEmpty) {
      return const Center(
        child: Text('Không có mẫu nào', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cats.length,
      itemBuilder: (context, idx) {
        final cat = cats[idx];
        final catId = cat['id'] as int;
        final catName = cat['name'] as String;
        final items = cat['items'] as List? ?? [];
        final isSelected = _selectedCategories.contains(catId);
        final isExpanded = _expandedCategories.contains(catId);

        return Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCategories.remove(catId);
                  } else {
                    _expandedCategories.add(catId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        catName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(catId);
                          } else {
                            _selectedCategories.add(catId);
                          }
                        });
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : Colors.grey,
                            width: isSelected ? 0 : 1.5,
                          ),
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...items.map((item) {
                final itemName = item['name'] as String;
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 48,
                    right: 20,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 1, indent: 20, endIndent: 20),
          ],
        );
      },
    );
  }
}
